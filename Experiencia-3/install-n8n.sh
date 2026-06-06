#!/usr/bin/env bash
#
# ============================================================================
#  install-n8n.sh  ·  Instalador automático de n8n para Ubuntu 24.04 LTS
# ============================================================================
#
#  Objetivo: Desplegar n8n en producción con HTTPS automático (Let's Encrypt),
#            base de datos PostgreSQL y reinicio automático, pidiendo al usuario
#            únicamente su dominio.
#
#  Stack desplegado:
#    - Docker + Docker Compose (motor de contenedores)
#    - n8n            (orquestador de flujos)
#    - PostgreSQL 16  (base de datos persistente de n8n)
#    - Caddy 2        (reverse proxy que pide y renueva el certificado TLS solo)
#
#  Uso:
#    sudo bash install-n8n.sh
#  o pasando el dominio sin que lo pregunte:
#    DOMAIN=mi.dominio.com sudo -E bash install-n8n.sh
#
#  Recomendado (para que no se interrumpa si se cae la sesión SSH):
#    Ejecutar dentro de 'screen' o 'tmux', o con:
#    sudo nohup bash install-n8n.sh > /var/log/install-n8n.log 2>&1 &
#
#  REQUISITO PREVIO IMPRESCINDIBLE:
#    El dominio DEBE apuntar por registro A a la IP pública de ESTA instancia
#    ANTES de ejecutar el script. Puede ser CUALQUIER dominio que tengas
#    registrado y apuntando a la instancia: un dominio propio (ejemplo.com,
#    n8n.miempresa.cl) o uno de DNS dinámico gratuito (ej: *.duckdns.org).
#    Si el DNS no resuelve a esta IP, Let's Encrypt no emitirá el certificado.
# ============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Colores y helpers de salida
# ---------------------------------------------------------------------------
C_RESET='\033[0m'; C_INFO='\033[1;34m'; C_OK='\033[1;32m'
C_WARN='\033[1;33m'; C_ERR='\033[1;31m'; C_DIM='\033[2m'

info()  { echo -e "${C_INFO}[*]${C_RESET} $*"; }
ok()    { echo -e "${C_OK}[✓]${C_RESET} $*"; }
warn()  { echo -e "${C_WARN}[!]${C_RESET} $*"; }
err()   { echo -e "${C_ERR}[x]${C_RESET} $*" >&2; }
die()   { err "$*"; exit 1; }

# Atrapar cualquier error y avisar en qué línea ocurrió
trap 'err "Falló el comando en la línea $LINENO. Revisa el mensaje anterior."' ERR

INSTALL_DIR="/opt/n8n"
LOCK_FILE="/var/lock/install-n8n.lock"

# Liberar el lock al salir (por error, Ctrl+C o término normal)
cleanup() { rm -f "${LOCK_FILE}" 2>/dev/null || true; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Lock: evita que dos ejecuciones corran a la vez (ej: se relanzó el script
# sin que la anterior terminara). Si el lock quedó huérfano de una corrida
# muerta, se detecta y se reutiliza.
# ---------------------------------------------------------------------------
acquire_lock() {
  if [[ -e "${LOCK_FILE}" ]]; then
    local old_pid; old_pid="$(cat "${LOCK_FILE}" 2>/dev/null || echo '')"
    if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
      die "Ya hay otra instalación en curso (PID ${old_pid}). Espera a que termine o mátala antes de reintentar."
    fi
    warn "Se encontró un lock huérfano de una ejecución anterior interrumpida. Reutilizando."
  fi
  echo "$$" > "${LOCK_FILE}"
}

banner() {
  echo -e "${C_INFO}"
  echo "============================================================"
  echo "   Instalador de n8n + HTTPS automático   ·   Ubuntu 24.04"
  echo "============================================================"
  echo -e "${C_RESET}"
}

# ---------------------------------------------------------------------------
# 1. Verificaciones previas
# ---------------------------------------------------------------------------
preflight() {
  # 1.1 Debe ejecutarse como root (o con sudo)
  if [[ "${EUID}" -ne 0 ]]; then
    die "Este script debe ejecutarse como root. Usa: sudo bash $0"
  fi

  # 1.2 Verificar que es Ubuntu 24.04
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
      warn "Este script está pensado para Ubuntu. Detectado: ${ID:-desconocido}. Continuando bajo tu responsabilidad."
    elif [[ "${VERSION_ID:-}" != "24.04" ]]; then
      warn "Probado en Ubuntu 24.04. Detectado: ${VERSION_ID:-?}. Continuando de todas formas."
    fi
  fi

  # 1.3 Necesitamos salida a internet
  if ! curl -fsSL --max-time 10 https://get.docker.com >/dev/null 2>&1; then
    die "No hay acceso a internet o get.docker.com no responde. Revisa la red de la instancia."
  fi
}

# ---------------------------------------------------------------------------
# 1b. Detección de instalación previa (idempotencia / recuperación)
# ---------------------------------------------------------------------------
# Si ya existe /opt/n8n (de una corrida anterior, completa o interrumpida),
# preguntamos qué hacer en vez de chocar o duplicar:
#   - Reanudar:   conserva datos y .env, vuelve a aplicar config y relevanta.
#   - Reinstalar: borra TODO (incluidos datos y volúmenes) y parte de cero.
#   - Cancelar:   no toca nada.
# RESUME es una variable global que usan otras funciones.
RESUME="false"
HEALTH_OK="false"   # lo fija health_report: "true" si la instalación está sana

# ---------------------------------------------------------------------------
# Diagnóstico de salud de una instalación existente.
# Informa: dominio configurado, estado de los contenedores y si n8n responde
# realmente por HTTPS. Sirve para decidir con datos si reanudar o reinstalar.
# ---------------------------------------------------------------------------
health_report() {
  local existing_domain="(desconocido)"
  if [[ -r "${INSTALL_DIR}/.env" ]]; then
    existing_domain="$(grep -E '^DOMAIN=' "${INSTALL_DIR}/.env" | cut -d= -f2- || true)"
    [[ -n "${existing_domain}" ]] || existing_domain="(no definido en .env)"
  fi

  echo
  echo -e "  ${C_INFO}Diagnóstico de la instalación existente${C_RESET}"
  echo -e "  ----------------------------------------"
  echo -e "  Dominio configurado : ${C_INFO}${existing_domain}${C_RESET}"

  # Estado de los contenedores (si docker y el compose están disponibles)
  local running_count="?" services_ok="false"
  if command -v docker >/dev/null 2>&1 && [[ -f "${INSTALL_DIR}/docker-compose.yml" ]]; then
    local ps_out
    ps_out="$( cd "${INSTALL_DIR}" && docker compose ps --status running --services 2>/dev/null || true )"
    if [[ -n "${ps_out}" ]]; then
      running_count="$(echo "${ps_out}" | grep -c . || true)"
      echo -e "  Contenedores activos: ${running_count} (${ps_out//$'\n'/, })"
      # Esperamos los tres servicios: postgres, n8n, caddy
      if echo "${ps_out}" | grep -q '^n8n$' && echo "${ps_out}" | grep -q '^caddy$'; then
        services_ok="true"
      fi
    else
      echo -e "  Contenedores activos: ${C_WARN}ninguno en ejecución${C_RESET}"
    fi
  else
    echo -e "  Contenedores activos: ${C_WARN}Docker no disponible o sin compose${C_RESET}"
  fi

  # Prueba real de respuesta HTTPS contra el dominio configurado
  local https_ok="false"
  if [[ "${existing_domain}" =~ \. ]]; then
    if curl -fsSL --max-time 8 "https://${existing_domain}/healthz" >/dev/null 2>&1; then
      https_ok="true"
      echo -e "  Respuesta HTTPS     : ${C_OK}OK — n8n responde en https://${existing_domain}${C_RESET}"
    else
      echo -e "  Respuesta HTTPS     : ${C_WARN}sin respuesta (servicio caído, certificado pendiente o DNS/puertos mal)${C_RESET}"
    fi
  fi

  # Veredicto resumido
  if [[ "${services_ok}" == "true" && "${https_ok}" == "true" ]]; then
    HEALTH_OK="true"
    echo -e "  Estado general      : ${C_OK}La instalación parece sana y operativa.${C_RESET}"
  elif [[ "${services_ok}" == "true" ]]; then
    echo -e "  Estado general      : ${C_WARN}Contenedores arriba pero n8n no responde aún por HTTPS.${C_RESET}"
  else
    echo -e "  Estado general      : ${C_WARN}Instalación incompleta o detenida.${C_RESET}"
  fi
  echo -e "  ----------------------------------------"
}

detect_existing() {
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    return
  fi

  warn "Se detectó una instalación previa en ${INSTALL_DIR}."
  health_report

  # Si viene una elección por variable de entorno, respetarla (no interactivo)
  local choice="${EXISTING_ACTION:-}"
  if [[ -z "${choice}" ]]; then
    echo
    if [[ "${HEALTH_OK}" == "true" ]]; then
      echo -e "  ${C_OK}Tu n8n ya está funcionando. Si no quieres cambiar nada, elige Cancelar (3).${C_RESET}"
    fi
    echo "  ¿Qué deseas hacer?"
    echo "    1) Reanudar  - conserva tus flujos y datos, reaplica configuración y relevanta"
    echo "    2) Reinstalar - BORRA todo (flujos, credenciales y base de datos) y parte de cero"
    echo "    3) Cancelar  - no toca nada y termina"
    read -rp "Opción [1/2/3]: " choice || true
  fi

  case "${choice}" in
    1|reanudar|resume)
      RESUME="true"
      ok "Modo reanudar: se conservarán los datos existentes."
      # Reutilizar el dominio guardado si no se entregó uno nuevo
      if [[ -z "${DOMAIN:-}" && -r "${INSTALL_DIR}/.env" ]]; then
        DOMAIN="$(grep -E '^DOMAIN=' "${INSTALL_DIR}/.env" | cut -d= -f2- || true)"
        [[ -n "${DOMAIN}" ]] && info "Dominio recuperado de la instalación previa: ${DOMAIN}"
      fi
      ;;
    2|reinstalar|reinstall)
      warn "Modo reinstalar: se eliminará TODO el stack y sus datos."
      local confirm="${FORCE:-}"
      if [[ -z "${confirm}" ]]; then
        read -rp "Escribe BORRAR para confirmar la eliminación total: " confirm || true
      fi
      if [[ "${confirm}" == "BORRAR" || "${confirm}" == "true" ]]; then
        if [[ -f "${INSTALL_DIR}/docker-compose.yml" ]] && command -v docker >/dev/null 2>&1; then
          info "Deteniendo y eliminando contenedores y volúmenes previos..."
          ( cd "${INSTALL_DIR}" && docker compose down -v >/dev/null 2>&1 ) || true
        fi
        rm -rf "${INSTALL_DIR}"
        ok "Instalación previa eliminada. Se instalará desde cero."
      else
        die "Confirmación incorrecta. Instalación cancelada para proteger tus datos."
      fi
      ;;
    *)
      die "Instalación cancelada. No se modificó nada."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 2. Lectura del dominio (interactiva o por variable de entorno)
# ---------------------------------------------------------------------------
ask_domain() {
  # Permite también: DOMAIN=mi.duckdns.org sudo -E bash install-n8n.sh
  if [[ -n "${DOMAIN:-}" ]]; then
    info "Usando dominio entregado por variable de entorno: ${DOMAIN}"
  else
    echo
    echo -e "${C_INFO}Ingresa el dominio que apunta a esta instancia${C_RESET}"
    echo -e "${C_DIM}Ejemplo: mi-anexo.duckdns.org  (sin https://, sin barra final)${C_RESET}"
    read -rp "Dominio: " DOMAIN
  fi

  # Limpieza básica: quitar esquema y barras
  DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN%/}"
  DOMAIN="$(echo -n "${DOMAIN}" | tr -d '[:space:]')"

  [[ -n "${DOMAIN}" ]] || die "El dominio no puede estar vacío."

  # Validación de formato de dominio
  if ! [[ "${DOMAIN}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    die "El dominio '${DOMAIN}' no tiene un formato válido."
  fi

  # Email para Let's Encrypt (opcional pero recomendado para avisos de expiración)
  if [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; then
    read -rp "Correo para avisos de Let's Encrypt (Enter para omitir): " LETSENCRYPT_EMAIL || true
  fi
}

# ---------------------------------------------------------------------------
# 3. Validación de DNS: el dominio debe resolver a la IP pública de esta VM
# ---------------------------------------------------------------------------
check_dns() {
  info "Verificando que ${DOMAIN} apunte a esta instancia..."

  local public_ip resolved_ip
  public_ip="$(curl -fsSL --max-time 10 https://api.ipify.org || true)"
  [[ -n "${public_ip}" ]] || warn "No pude detectar la IP pública automáticamente."

  # Resolver el dominio (getent usa el resolver del sistema)
  resolved_ip="$(getent hosts "${DOMAIN}" | awk '{print $1}' | head -n1 || true)"

  if [[ -z "${resolved_ip}" ]]; then
    warn "El dominio ${DOMAIN} aún no resuelve a ninguna IP."
    warn "Asegúrate de haber creado el registro A en DuckDNS apuntando a: ${public_ip:-<IP de la VM>}"
    confirm_continue
  elif [[ -n "${public_ip}" && "${resolved_ip}" != "${public_ip}" ]]; then
    warn "El dominio resuelve a ${resolved_ip}, pero la IP pública de esta VM es ${public_ip}."
    warn "Si no coinciden, Let's Encrypt fallará al emitir el certificado."
    confirm_continue
  else
    ok "DNS correcto: ${DOMAIN} -> ${resolved_ip}"
  fi
}

confirm_continue() {
  local ans
  read -rp "¿Deseas continuar de todas formas? (s/N): " ans || true
  case "${ans:-}" in
    s|S|y|Y) warn "Continuando. Si el certificado falla, corrige el DNS y vuelve a ejecutar.";;
    *) die "Instalación cancelada. Corrige el DNS y vuelve a ejecutar el script.";;
  esac
}

# ---------------------------------------------------------------------------
# 4. Instalación de Docker (si no está presente)
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker y Docker Compose ya están instalados."
    return
  fi
  info "Instalando Docker Engine + Compose (script oficial de Docker)..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh >/dev/null
  rm -f /tmp/get-docker.sh
  systemctl enable --now docker >/dev/null 2>&1 || true
  ok "Docker instalado."
}

# ---------------------------------------------------------------------------
# 4b. Swap de respaldo en instancias con poca RAM (ej: t3.small = 2 GB)
# ---------------------------------------------------------------------------
# n8n (Node) + PostgreSQL + Caddy en 2 GB queda muy justo. Un archivo de swap
# evita que un contenedor muera por OOM durante picos o al descargar imágenes.
setup_swap() {
  # RAM total en MB
  local mem_mb; mem_mb="$(free -m | awk '/^Mem:/ {print $2}')"

  if (( mem_mb >= 3500 )); then
    ok "RAM suficiente (${mem_mb} MB). No se crea swap."
    return
  fi

  if swapon --show 2>/dev/null | grep -q '/'; then
    ok "Ya existe swap activo. No se crea uno nuevo."
    return
  fi

  info "RAM baja (${mem_mb} MB). Creando 2 GB de swap para estabilidad..."
  if fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none; then
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    # Persistir el swap entre reinicios
    if ! grep -q '^/swapfile' /etc/fstab; then
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    # Reducir la "agresividad" del swap (mejor rendimiento en server)
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    grep -q '^vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
    ok "Swap de 2 GB activo y persistente."
  else
    warn "No se pudo crear el archivo de swap. Continuando sin swap."
  fi
}

# ---------------------------------------------------------------------------
# 5. Apertura de puertos (UFW) si el firewall está activo
# ---------------------------------------------------------------------------
configure_firewall() {
  if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    info "Abriendo puertos 80 y 443 en UFW..."
    ufw allow 80/tcp  >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    ok "Puertos HTTP/HTTPS abiertos en UFW."
  else
    warn "UFW inactivo o ausente. RECUERDA abrir los puertos 80 y 443 en el Security Group de AWS."
  fi
}

# ---------------------------------------------------------------------------
# 6. Generación de la configuración (docker-compose.yml + Caddyfile + .env)
# ---------------------------------------------------------------------------
generate_config() {
  info "Generando configuración en ${INSTALL_DIR}..."
  mkdir -p "${INSTALL_DIR}"

  # Detectar zona horaria del host (cae a UTC si no se puede)
  local tz; tz="$(cat /etc/timezone 2>/dev/null || echo 'UTC')"

  local pg_pass enc_key
  if [[ "${RESUME}" == "true" && -r "${INSTALL_DIR}/.env" ]]; then
    # Reanudando: conservar los secretos existentes. Cambiarlos rompería el
    # acceso a la base de datos y descifrado de credenciales ya guardadas.
    pg_pass="$(grep -E '^POSTGRES_PASSWORD=' "${INSTALL_DIR}/.env" | cut -d= -f2- || true)"
    enc_key="$(grep -E '^N8N_ENCRYPTION_KEY=' "${INSTALL_DIR}/.env" | cut -d= -f2- || true)"
    [[ -n "${pg_pass}" ]] || pg_pass="$(openssl rand -hex 24)"
    [[ -n "${enc_key}" ]] || enc_key="$(openssl rand -hex 24)"
    info "Reutilizando credenciales de la instalación previa."
  else
    # Instalación nueva: generar credenciales aleatorias.
    # La encryption key cifra las credenciales guardadas en n8n: NO debe perderse.
    pg_pass="$(openssl rand -hex 24)"
    enc_key="$(openssl rand -hex 24)"
  fi

  # --- archivo .env (secretos, fuera del compose) ---
  # Se escribe primero a un temporal y luego se mueve (escritura atómica):
  # si la conexión se cae a mitad, no queda un .env corrupto a medio escribir.
  cat > "${INSTALL_DIR}/.env.tmp" <<EOF
# Generado automáticamente por install-n8n.sh el $(date -Iseconds)
# NO compartas este archivo: contiene secretos.
DOMAIN=${DOMAIN}
GENERIC_TIMEZONE=${tz}
POSTGRES_USER=n8n
POSTGRES_PASSWORD=${pg_pass}
POSTGRES_DB=n8n
N8N_ENCRYPTION_KEY=${enc_key}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-}
EOF
  chmod 600 "${INSTALL_DIR}/.env.tmp"
  mv -f "${INSTALL_DIR}/.env.tmp" "${INSTALL_DIR}/.env"

  # --- docker-compose.yml ---
  cat > "${INSTALL_DIR}/docker-compose.yml" <<'EOF'
services:
  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      # --- Base de datos ---
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      # --- Identidad / URLs públicas (clave para webhooks) ---
      N8N_HOST: ${DOMAIN}
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://${DOMAIN}/
      N8N_EDITOR_BASE_URL: https://${DOMAIN}/
      # --- Seguridad ---
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      N8N_PROXY_HOPS: 1
      GENERIC_TIMEZONE: ${GENERIC_TIMEZONE}
      N8N_RUNNERS_ENABLED: "true"
    volumes:
      - n8n_data:/home/node/.n8n
    expose:
      - "5678"

  caddy:
    image: caddy:2-alpine
    restart: always
    depends_on:
      - n8n
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    environment:
      DOMAIN: ${DOMAIN}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}

volumes:
  postgres_data:
  n8n_data:
  caddy_data:
  caddy_config:
EOF

  # --- Caddyfile ---
  # Caddy pide y renueva el certificado Let's Encrypt automáticamente con solo
  # poner el dominio. reverse_proxy n8n:5678 envía el tráfico al contenedor.
  if [[ -n "${LETSENCRYPT_EMAIL:-}" ]]; then
    cat > "${INSTALL_DIR}/Caddyfile" <<EOF
{
    email ${LETSENCRYPT_EMAIL}
}

${DOMAIN} {
    reverse_proxy n8n:5678
    encode gzip
}
EOF
  else
    cat > "${INSTALL_DIR}/Caddyfile" <<EOF
${DOMAIN} {
    reverse_proxy n8n:5678
    encode gzip
}
EOF
  fi

  ok "Configuración generada."
}

# ---------------------------------------------------------------------------
# 7. Levantar los contenedores
# ---------------------------------------------------------------------------
start_stack() {
  info "Descargando imágenes y levantando los servicios (puede tardar 1-2 min)..."
  ( cd "${INSTALL_DIR}" && docker compose pull -q && docker compose up -d --remove-orphans )
  ok "Contenedores en ejecución."
}

# ---------------------------------------------------------------------------
# 8. Esperar a que el certificado TLS se emita y n8n responda
# ---------------------------------------------------------------------------
wait_for_https() {
  info "Esperando la emisión del certificado y el arranque de n8n..."
  local tries=0 max=30
  while (( tries < max )); do
    if curl -fsSL --max-time 8 "https://${DOMAIN}/healthz" >/dev/null 2>&1; then
      ok "n8n responde por HTTPS correctamente."
      return 0
    fi
    tries=$((tries + 1))
    sleep 6
  done
  warn "Aún no obtengo respuesta HTTPS tras esperar ~3 minutos."
  warn "Revisa los logs de Caddy: cd ${INSTALL_DIR} && docker compose logs caddy"
}

# ---------------------------------------------------------------------------
# 9. Resumen final
# ---------------------------------------------------------------------------
summary() {
  echo
  echo -e "${C_OK}============================================================${C_RESET}"
  echo -e "${C_OK}  Instalación finalizada${C_RESET}"
  echo -e "${C_OK}============================================================${C_RESET}"
  echo
  echo -e "  URL de n8n      : ${C_INFO}https://${DOMAIN}${C_RESET}"
  echo -e "  Webhooks (prod) : https://${DOMAIN}/webhook/<path>"
  echo -e "  Webhooks (test) : https://${DOMAIN}/webhook-test/<path>"
  echo
  echo -e "  Carpeta         : ${INSTALL_DIR}"
  echo -e "  Configuración   : ${INSTALL_DIR}/docker-compose.yml  ·  Caddyfile  ·  .env"
  echo
  echo -e "  ${C_WARN}Importante:${C_RESET} el archivo ${INSTALL_DIR}/.env contiene la clave de"
  echo -e "  cifrado de n8n y la contraseña de Postgres. Haz respaldo y no lo compartas."
  echo
  echo -e "  Comandos útiles:"
  echo -e "    ${C_DIM}cd ${INSTALL_DIR}${C_RESET}"
  echo -e "    ${C_DIM}docker compose logs -f n8n     # ver logs de n8n${C_RESET}"
  echo -e "    ${C_DIM}docker compose logs -f caddy   # ver emisión del certificado${C_RESET}"
  echo -e "    ${C_DIM}docker compose restart         # reiniciar${C_RESET}"
  echo -e "    ${C_DIM}docker compose pull && docker compose up -d   # actualizar n8n${C_RESET}"
  echo
  echo -e "  ${C_INFO}Primer paso:${C_RESET} abre la URL en tu navegador y crea la cuenta de propietario."
  echo
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  banner
  preflight
  acquire_lock
  detect_existing
  ask_domain
  check_dns
  install_docker
  setup_swap
  configure_firewall
  generate_config
  start_stack
  wait_for_https
  summary
}

main "$@"
