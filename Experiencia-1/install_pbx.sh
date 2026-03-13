#!/bin/bash
# =============================================================================
#  install_pbx.sh
#  Instalador automático de Asterisk 22 + FreePBX 17
#  Compatible con Ubuntu 22.04 LTS y Ubuntu 24.04 LTS
#
#  Autor:   CUY5132 — Comunicaciones Unificadas y VoIP — DUOC UC
#  Versión: 2.0
#  Uso:     sudo bash install_pbx.sh
# =============================================================================

set -euo pipefail

# ─── Colores ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Configuración ──────────────────────────────────────────────────────────
LOG_FILE="/var/log/install_pbx.log"
ASTERISK_VERSION="22"
FREEPBX_VERSION="17.0"
FREEPBX_URL="http://mirror.freepbx.org/modules/packages/freepbx/freepbx-${FREEPBX_VERSION}-latest.tgz"
ASTERISK_URL="https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}-current.tar.gz"
PHP_TARGET="8.2"

# ─── Funciones de logging ────────────────────────────────────────────────────
log()     { echo -e "${NC}$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
ok()      { echo -e "${GREEN}  ✔  $*${NC}" | tee -a "$LOG_FILE"; }
info()    { echo -e "${CYAN}  →  $*${NC}" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}  ⚠  $*${NC}" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}  ✘  $*${NC}" | tee -a "$LOG_FILE"; }
step()    { echo -e "\n${BOLD}${BLUE}━━━  $*  ━━━${NC}\n" | tee -a "$LOG_FILE"; }
banner()  {
  echo -e "${BOLD}${BLUE}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║        Instalador PBX — Asterisk 22 + FreePBX 17            ║"
  echo "║        CUY5132 — DUOC UC  |  Ubuntu 22.04 / 24.04           ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ─── Verificaciones previas ──────────────────────────────────────────────────
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root: sudo bash install_pbx.sh"
    exit 1
  fi
}

detect_ubuntu() {
  if [[ ! -f /etc/os-release ]]; then
    error "No se puede detectar el sistema operativo."
    exit 1
  fi
  source /etc/os-release
  if [[ "$ID" != "ubuntu" ]]; then
    error "Este script solo es compatible con Ubuntu. SO detectado: $ID"
    exit 1
  fi
  UBUNTU_VERSION="$VERSION_ID"
  if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    warn "Versión de Ubuntu no verificada oficialmente: $UBUNTU_VERSION"
    warn "El script fue diseñado para 22.04 y 24.04. Continuando de todos modos..."
  fi

  # Determinar qué versión de PHP deshabilitar
  case "$UBUNTU_VERSION" in
    "22.04") PHP_DEFAULT="8.1" ;;
    "24.04") PHP_DEFAULT="8.3" ;;
    *)       PHP_DEFAULT="8.1" ;;  # fallback
  esac

  ok "Sistema detectado: Ubuntu $UBUNTU_VERSION"
  info "PHP por defecto del sistema: $PHP_DEFAULT → Se instalará PHP $PHP_TARGET"
}

check_internet() {
  info "Verificando conexión a internet..."
  if ! curl -s --max-time 5 https://downloads.asterisk.org > /dev/null; then
    error "Sin conexión a internet. Verifique la red antes de continuar."
    exit 1
  fi
  ok "Conexión a internet disponible."
}

# ─── Paso 1: Dependencias ────────────────────────────────────────────────────
install_dependencies() {
  step "PASO 1 — Instalando dependencias del sistema"
  apt-get update -y >> "$LOG_FILE" 2>&1
  apt-get install -y \
    sox pkg-config libedit-dev unzip git gnupg2 curl \
    libnewt-dev libssl-dev libncurses5-dev subversion \
    libsqlite3-dev build-essential libjansson-dev libxml2-dev \
    uuid-dev software-properties-common wget >> "$LOG_FILE" 2>&1
  ok "Dependencias instaladas correctamente."
}

# ─── Paso 2: Instalar Asterisk ───────────────────────────────────────────────
install_asterisk() {
  step "PASO 2 — Descargando e instalando Asterisk $ASTERISK_VERSION"

  cd /usr/src

  info "Descargando Asterisk ${ASTERISK_VERSION}..."
  wget -q --show-progress "$ASTERISK_URL" -O "asterisk-${ASTERISK_VERSION}-current.tar.gz"

  info "Extrayendo archivo..."
  tar -xzf "asterisk-${ASTERISK_VERSION}-current.tar.gz"

  ASTERISK_DIR=$(find /usr/src -maxdepth 1 -type d -name "asterisk-${ASTERISK_VERSION}.*" | head -1)
  if [[ -z "$ASTERISK_DIR" ]]; then
    error "No se encontró el directorio de Asterisk extraído."
    exit 1
  fi

  cd "$ASTERISK_DIR"

  info "Descargando fuentes MP3..."
  contrib/scripts/get_mp3_source.sh >> "$LOG_FILE" 2>&1 || warn "get_mp3_source.sh tuvo advertencias (no crítico)."

  info "Instalando prerequisitos de Asterisk..."
  contrib/scripts/install_prereq install >> "$LOG_FILE" 2>&1

  info "Ejecutando ./configure..."
  ./configure >> "$LOG_FILE" 2>&1

  # Selección de módulos sin interfaz interactiva
  info "Configurando módulos (menuselect automático)..."
  make menuselect.makeopts >> "$LOG_FILE" 2>&1

  menuselect/menuselect \
    --enable format_mp3 \
    --enable res_config_mysql \
    --enable chan_ooh323 \
    --enable CORE-SOUNDS-EN-WAV \
    --enable CORE-SOUNDS-EN-ULAW \
    --enable CORE-SOUNDS-EN-ALAW \
    --enable CORE-SOUNDS-EN-GSM \
    --enable CORE-SOUNDS-EN-G729 \
    --enable MOH-OPSOUND-WAV \
    --enable MOH-OPSOUND-ULAW \
    --enable MOH-OPSOUND-ALAW \
    --enable MOH-OPSOUND-GSM \
    --enable EXTRA-SOUNDS-EN-WAV \
    --enable EXTRA-SOUNDS-EN-ULAW \
    --enable EXTRA-SOUNDS-EN-ALAW \
    --enable EXTRA-SOUNDS-EN-GSM \
    menuselect.makeopts >> "$LOG_FILE" 2>&1

  info "Compilando Asterisk (esto puede tardar varios minutos)..."
  make -j"$(nproc)" >> "$LOG_FILE" 2>&1

  info "Instalando Asterisk..."
  make install >> "$LOG_FILE" 2>&1
  make samples >> "$LOG_FILE" 2>&1
  make config  >> "$LOG_FILE" 2>&1
  ldconfig     >> "$LOG_FILE" 2>&1

  ok "Asterisk $ASTERISK_VERSION instalado correctamente."
}

# ─── Paso 3: Configurar Asterisk ─────────────────────────────────────────────
configure_asterisk() {
  step "PASO 3 — Configurando Asterisk"

  info "Creando usuario y grupo 'asterisk'..."
  getent group asterisk  > /dev/null 2>&1 || groupadd asterisk
  id asterisk            > /dev/null 2>&1 || useradd -r -d /var/lib/asterisk -g asterisk asterisk
  usermod -aG audio,dialout asterisk

  info "Aplicando permisos de directorios..."
  chown -R asterisk:asterisk /etc/asterisk
  chown -R asterisk:asterisk /var/{lib,log,spool}/asterisk
  chown -R asterisk:asterisk /usr/lib/asterisk

  info "Configurando usuario en /etc/default/asterisk..."
  sed -i 's/^#*\s*AST_USER=.*/AST_USER="asterisk"/'  /etc/default/asterisk  2>/dev/null || \
    echo 'AST_USER="asterisk"' >> /etc/default/asterisk
  sed -i 's/^#*\s*AST_GROUP=.*/AST_GROUP="asterisk"/' /etc/default/asterisk 2>/dev/null || \
    echo 'AST_GROUP="asterisk"' >> /etc/default/asterisk

  info "Configurando runuser/rungroup en asterisk.conf..."
  sed -i 's/^;*\s*runuser\s*=.*/runuser = asterisk/'   /etc/asterisk/asterisk.conf
  sed -i 's/^;*\s*rungroup\s*=.*/rungroup = asterisk/' /etc/asterisk/asterisk.conf

  info "Corrigiendo error de radiusclient (si aplica)..."
  sed -i 's|;;\[radius\]|;\[radius\]|g' /etc/asterisk/cdr.conf 2>/dev/null || true
  sed -i 's|;radiuscfg => /usr/local/etc/radiusclient-ng/radiusclient.conf|radiuscfg => /etc/radcli/radiusclient.conf|g' \
    /etc/asterisk/cdr.conf 2>/dev/null || true
  sed -i 's|;radiuscfg => /usr/local/etc/radiusclient-ng/radiusclient.conf|radiuscfg => /etc/radcli/radiusclient.conf|g' \
    /etc/asterisk/cel.conf 2>/dev/null || true

  info "Habilitando e iniciando servicio Asterisk..."
  systemctl enable asterisk >> "$LOG_FILE" 2>&1
  systemctl restart asterisk >> "$LOG_FILE" 2>&1

  sleep 3
  if systemctl is-active --quiet asterisk; then
    ok "Asterisk está corriendo correctamente."
  else
    warn "Asterisk no levantó correctamente. Revise: journalctl -u asterisk"
  fi
}

# ─── Paso 4: PHP 8.2 ─────────────────────────────────────────────────────────
install_php82() {
  step "PASO 4 — Instalando PHP $PHP_TARGET (requerido por FreePBX 17)"

  info "Agregando repositorio PPA de Ondrej..."
  add-apt-repository ppa:ondrej/php -y >> "$LOG_FILE" 2>&1
  apt-get update -y >> "$LOG_FILE" 2>&1

  info "Instalando PHP $PHP_TARGET y extensiones..."
  apt-get install -y \
    php${PHP_TARGET} \
    libapache2-mod-php${PHP_TARGET} \
    php${PHP_TARGET}-intl \
    php${PHP_TARGET}-mysql \
    php${PHP_TARGET}-curl \
    php${PHP_TARGET}-cli \
    php${PHP_TARGET}-zip \
    php${PHP_TARGET}-xml \
    php${PHP_TARGET}-gd \
    php${PHP_TARGET}-common \
    php${PHP_TARGET}-mbstring \
    php${PHP_TARGET}-xmlrpc \
    php${PHP_TARGET}-bcmath \
    php${PHP_TARGET}-sqlite3 \
    php${PHP_TARGET}-soap \
    php${PHP_TARGET}-ldap \
    php${PHP_TARGET}-imap >> "$LOG_FILE" 2>&1

  # Solo deshabilitar si el módulo está activo
  info "Configurando Apache para usar PHP $PHP_TARGET..."
  a2dismod "php${PHP_DEFAULT}" >> "$LOG_FILE" 2>&1 || warn "php${PHP_DEFAULT} no estaba activo en Apache (normal)."
  a2enmod  "php${PHP_TARGET}"  >> "$LOG_FILE" 2>&1
  systemctl restart apache2    >> "$LOG_FILE" 2>&1

  info "Estableciendo PHP $PHP_TARGET como versión por defecto del sistema..."
  update-alternatives --set php      /usr/bin/php${PHP_TARGET}      >> "$LOG_FILE" 2>&1 || true
  update-alternatives --set phar     /usr/bin/phar${PHP_TARGET}     >> "$LOG_FILE" 2>&1 || true
  update-alternatives --set phar.phar /usr/bin/phar.phar${PHP_TARGET} >> "$LOG_FILE" 2>&1 || true

  ACTIVE_PHP=$(php -v 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1,2)
  if [[ "$ACTIVE_PHP" == "$PHP_TARGET" ]]; then
    ok "PHP $PHP_TARGET activo correctamente. (php -v → $ACTIVE_PHP)"
  else
    warn "La versión activa de PHP es $ACTIVE_PHP. Verifique manualmente con 'php -v'."
  fi
}

# ─── Paso 5: FreePBX ─────────────────────────────────────────────────────────
install_freepbx() {
  step "PASO 5 — Instalando FreePBX $FREEPBX_VERSION"

  info "Instalando stack LAMP (Apache, MariaDB, PHP $PHP_TARGET)..."
  apt-get install -y \
    mariadb-server apache2 \
    php${PHP_TARGET} libapache2-mod-php${PHP_TARGET} \
    php${PHP_TARGET}-intl php${PHP_TARGET}-mysql php${PHP_TARGET}-curl \
    php${PHP_TARGET}-cli php${PHP_TARGET}-zip php${PHP_TARGET}-xml \
    php${PHP_TARGET}-gd php${PHP_TARGET}-common php${PHP_TARGET}-mbstring \
    php${PHP_TARGET}-xmlrpc php${PHP_TARGET}-bcmath php${PHP_TARGET}-sqlite3 \
    php${PHP_TARGET}-soap php${PHP_TARGET}-ldap php${PHP_TARGET}-imap \
    nodejs npm >> "$LOG_FILE" 2>&1

  systemctl enable mariadb >> "$LOG_FILE" 2>&1
  systemctl start  mariadb >> "$LOG_FILE" 2>&1

  info "Descargando FreePBX $FREEPBX_VERSION..."
  cd /usr/src
  wget -q --show-progress "$FREEPBX_URL" -O "freepbx-${FREEPBX_VERSION}-latest.tgz"

  info "Extrayendo FreePBX..."
  tar -xzf "freepbx-${FREEPBX_VERSION}-latest.tgz"
  cd freepbx

  info "Configurando Apache (usuario asterisk + AllowOverride)..."
  sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
  sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

  info "Configurando upload_max_filesize en php.ini para PHP $PHP_TARGET..."
  for ini_file in /etc/php/${PHP_TARGET}/apache2/php.ini /etc/php/${PHP_TARGET}/cli/php.ini; do
    [[ -f "$ini_file" ]] && sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 20M/' "$ini_file"
  done

  info "Habilitando mod_rewrite y reiniciando Apache..."
  a2enmod rewrite >> "$LOG_FILE" 2>&1
  systemctl restart apache2 >> "$LOG_FILE" 2>&1

  info "Ejecutando instalador de FreePBX (puede tardar varios minutos)..."
  ./install -n >> "$LOG_FILE" 2>&1

  info "Instalando módulo pm2..."
  fwconsole ma install pm2 >> "$LOG_FILE" 2>&1 || warn "pm2 no pudo instalarse automáticamente. Ejecute manualmente: fwconsole ma install pm2"

  info "Aplicando configuración inicial de FreePBX..."
  fwconsole chown  >> "$LOG_FILE" 2>&1 || true
  fwconsole reload >> "$LOG_FILE" 2>&1 || true

  ok "FreePBX $FREEPBX_VERSION instalado correctamente."
}

# ─── Paso 6: Firewall ────────────────────────────────────────────────────────
configure_firewall() {
  step "PASO 6 — Configurando Firewall (UFW)"

  apt-get install -y ufw >> "$LOG_FILE" 2>&1

  info "Configurando reglas de firewall para VoIP..."
  ufw --force reset  >> "$LOG_FILE" 2>&1
  ufw default deny incoming >> "$LOG_FILE" 2>&1
  ufw default allow outgoing >> "$LOG_FILE" 2>&1

  ufw allow 22/tcp    comment 'SSH'      >> "$LOG_FILE" 2>&1
  ufw allow 80/tcp    comment 'HTTP'     >> "$LOG_FILE" 2>&1
  ufw allow 443/tcp   comment 'HTTPS'    >> "$LOG_FILE" 2>&1
  ufw allow 5060/udp  comment 'SIP'      >> "$LOG_FILE" 2>&1
  ufw allow 5061/tcp  comment 'SIP TLS'  >> "$LOG_FILE" 2>&1
  ufw allow 10000:20000/udp comment 'RTP Audio' >> "$LOG_FILE" 2>&1

  ufw --force enable >> "$LOG_FILE" 2>&1
  ok "Firewall UFW activo con reglas VoIP."
}

# ─── Resumen final ───────────────────────────────────────────────────────────
show_summary() {
  SERVER_IP=$(hostname -I | awk '{print $1}')

  echo -e "\n${BOLD}${GREEN}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                  ✔  INSTALACIÓN COMPLETA                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "${BOLD}  Resumen del sistema instalado:${NC}"
  echo -e "  Ubuntu:    ${CYAN}$UBUNTU_VERSION${NC}"
  echo -e "  Asterisk:  ${CYAN}$ASTERISK_VERSION${NC}"
  echo -e "  FreePBX:   ${CYAN}$FREEPBX_VERSION${NC}"
  echo -e "  PHP:       ${CYAN}$PHP_TARGET${NC}  (default del sistema era $PHP_DEFAULT)"
  echo ""
  echo -e "${BOLD}  Acceso a FreePBX:${NC}"
  echo -e "  URL:       ${CYAN}http://$SERVER_IP/admin${NC}"
  echo -e "  Usuario:   ${CYAN}asterisk${NC}  (o el que configure en el primer acceso)"
  echo ""
  echo -e "${BOLD}  Log completo:${NC}  ${CYAN}$LOG_FILE${NC}"
  echo -e "${BOLD}  CLI Asterisk:${NC}  ${CYAN}asterisk -rvv${NC}"
  echo ""
  echo -e "${YELLOW}  PRÓXIMO PASO: Abra el navegador en http://$SERVER_IP/admin${NC}"
  echo -e "${YELLOW}  y complete la configuración inicial del administrador.${NC}\n"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  mkdir -p "$(dirname "$LOG_FILE")"
  : > "$LOG_FILE"   # limpiar log anterior

  banner
  log "Inicio de instalación: $(date)"

  check_root
  detect_ubuntu
  check_internet

  echo -e "\n${BOLD}Se instalarán los siguientes componentes:${NC}"
  echo -e "  • Dependencias del sistema"
  echo -e "  • Asterisk $ASTERISK_VERSION (compilado desde fuente)"
  echo -e "  • PHP $PHP_TARGET (desde PPA Ondrej, reemplazando PHP $PHP_DEFAULT)"
  echo -e "  • FreePBX $FREEPBX_VERSION"
  echo -e "  • Firewall UFW con reglas VoIP\n"

  echo -e "${YELLOW}¿Desea continuar? [s/N]: ${NC}"
  read -r -t 15 CONFIRM || CONFIRM="s"   # si no responde en 15s, continúa
  [[ "$CONFIRM" =~ ^[sS]$ ]] || { echo "Instalación cancelada."; exit 0; }

  install_dependencies
  install_asterisk
  configure_asterisk
  install_php82
  install_freepbx
  configure_firewall
  show_summary

  log "Instalación completada: $(date)"
}

main "$@"
