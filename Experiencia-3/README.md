# Instalador automático de n8n

Despliega **n8n** en producción sobre **Ubuntu 24.04 LTS** con un solo comando.
El script pide únicamente tu **dominio** y se encarga del resto: instala Docker,
levanta n8n con PostgreSQL y obtiene el **certificado HTTPS automáticamente**
(Let's Encrypt vía Caddy).

## ✅ Requisito previo (imprescindible)

Antes de ejecutar el script, tu dominio **debe apuntar a la IP pública de la
instancia** mediante un registro **A**. Puede ser **cualquier dominio** que
tengas registrado y apuntando a la instancia:

- un dominio propio (`ejemplo.com`, `n8n.miempresa.cl`, un subdominio tuyo), o
- un servicio de **DNS dinámico gratuito** como DuckDNS (`mi-nombre.duckdns.org`),
  útil cuando no tienes un dominio propio.

> Los ejemplos usan DuckDNS por ser gratuito y sin configuración, pero no es
> obligatorio: sirve igual cualquier dominio cuyo registro A apunte a la IP de
> tu instancia. Si el dominio no resuelve a esa IP, Let's Encrypt **no podrá
> emitir el certificado**.

Para conocer la IP pública de tu instancia:

```bash
curl https://api.ipify.org
```

Si usas un firewall en la nube (AWS Security Group, GCP, etc.), abre los puertos
**80** y **443** (TCP).

## 🚀 Instalación

Opción A — descargar y ejecutar:

```bash
wget https://raw.githubusercontent.com/nicsanchezr/NEW-CUY5132-DUOC/main/Experiencia-3/install-n8n.sh
sudo bash install-n8n.sh
```

Opción B — pasando el dominio sin que lo pregunte:

```bash
DOMAIN=mi.dominio.com sudo -E bash install-n8n.sh
```

Opción C — directo desde GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/nicsanchezr/NEW-CUY5132-DUOC/main/Experiencia-3/install-n8n.sh | sudo bash
```

> Buena práctica de seguridad: antes de ejecutar un script con `curl | bash`,
> conviene descargarlo y revisarlo (Opción A).

### Para que no se corte si se cae la sesión SSH

Si la conexión SSH se interrumpe a mitad de la instalación, el proceso podría
morir. Para evitarlo, ejecútalo de forma que sobreviva a la desconexión:

```bash
# con tmux o screen (recomendado):
tmux new -s n8n
sudo bash install-n8n.sh
# (si te desconectas, vuelves con: tmux attach -t n8n)

# o en segundo plano con log:
sudo nohup bash install-n8n.sh > /var/log/install-n8n.log 2>&1 &
tail -f /var/log/install-n8n.log
```

## 🔁 Si lo ejecutas de nuevo (recuperación / idempotencia)

El script es seguro de relanzar. Si detecta una instalación previa en `/opt/n8n`
(por ejemplo, porque una corrida anterior se interrumpió), te ofrece:

1. **Reanudar** — conserva tus flujos, credenciales y base de datos; reaplica la
   configuración y vuelve a levantar los contenedores. Reutiliza los mismos
   secretos (no los regenera, para no perder acceso a los datos).
2. **Reinstalar** — borra **todo** (incluida la base de datos y los volúmenes) y
   parte de cero. Pide confirmación escribiendo `BORRAR`.
3. **Cancelar** — no toca nada.

También evita que dos ejecuciones corran a la vez (lock), y si encuentra un lock
huérfano de una corrida muerta, lo reutiliza automáticamente.

Modo no interactivo (útil para automatización):

```bash
# reanudar sin preguntar:
EXISTING_ACTION=1 DOMAIN=mi.dominio.com sudo -E bash install-n8n.sh
# reinstalar sin preguntar (¡borra datos!):
EXISTING_ACTION=2 FORCE=true DOMAIN=mi.dominio.com sudo -E bash install-n8n.sh
```

## 🧩 Qué instala

| Componente   | Rol                                                        |
|--------------|------------------------------------------------------------|
| Docker + Compose | Motor de contenedores                                  |
| n8n          | Orquestador de flujos (interfaz web)                       |
| PostgreSQL 16 | Base de datos persistente de n8n                          |
| Caddy 2      | Reverse proxy que pide y **renueva el certificado TLS solo** |

Todo queda en `/opt/n8n` con persistencia en volúmenes de Docker. En instancias
con poca RAM (≤ ~3,5 GB) crea automáticamente 2 GB de swap para mayor estabilidad.

## 🔑 Después de instalar

1. Abre `https://tu-dominio` en el navegador.
2. Crea la cuenta de propietario de n8n.
3. Tus webhooks quedarán disponibles en:
   - Producción: `https://tu-dominio/webhook/<path>`
   - Pruebas:    `https://tu-dominio/webhook-test/<path>`

> ⚠️ El archivo `/opt/n8n/.env` contiene la **clave de cifrado de n8n** y la
> contraseña de PostgreSQL. Haz respaldo y **no lo compartas ni lo subas a Git**.
> Si pierdes la clave de cifrado, n8n no podrá descifrar las credenciales guardadas.

## 🛠️ Comandos útiles

```bash
cd /opt/n8n
docker compose logs -f n8n      # logs de n8n
docker compose logs -f caddy    # ver la emisión del certificado
docker compose restart          # reiniciar
docker compose down             # detener
docker compose pull && docker compose up -d   # actualizar n8n a la última versión
```

## ❓ Problemas frecuentes

- **El certificado no se emite / la web no carga por HTTPS**
  Revisa `docker compose logs -f caddy`. Casi siempre es porque el dominio no
  apunta a la IP correcta o los puertos 80/443 están cerrados en el firewall.

- **`error 429` de Let's Encrypt**
  Demasiados intentos seguidos con DNS mal configurado. Let's Encrypt limita los
  reintentos. Corrige el DNS y espera un rato antes de reintentar.

- **Cambié la IP de la instancia**
  Actualiza el registro A de tu dominio con la nueva IP. Caddy revalidará solo.
