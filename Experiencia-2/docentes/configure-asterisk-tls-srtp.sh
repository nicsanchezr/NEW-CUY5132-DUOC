#!/bin/bash
#
# Script de Configuración - Lab 2.3: Asterisk TLS/SRTP
# Para DOCENTES - Demostración
# Curso: CUY5132 - Comunicaciones Unificadas
# Versión: 2.0
#
# Este script agrega TLS/SRTP a Asterisk
# REQUIERE: Asterisk instalado (script estudiantes)
#

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║ $1${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ ERROR: $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Verificar root
if [[ $EUID -ne 0 ]]; then
   print_error "Ejecutar como root: sudo bash $0"
   exit 1
fi

clear
print_header "LAB 2.3: CONFIGURACIÓN ASTERISK TLS/SRTP"
echo ""
echo "Este script configura TLS y SRTP en Asterisk."
echo ""
echo "Componentes:"
echo "  ✓ Transport TLS en puerto 5061"
echo "  ✓ Certificados autofirmados"
echo "  ✓ SRTP para cifrado de medios"
echo ""
echo "⚠️  REQUISITO: Asterisk instalado previamente"
echo ""
echo "Tiempo estimado: ~5 minutos"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Verificar Asterisk
if ! command -v asterisk &>/dev/null; then
    print_error "Asterisk no está instalado"
    exit 1
fi

# Obtener IPs
print_info "Detectando IPs..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me || echo "No disponible")

echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  └─ IP Pública: $PUBLIC_IP"
echo ""

systemctl stop asterisk

print_header "Paso 1: Generar certificados TLS"

# Crear directorio
mkdir -p /etc/asterisk/keys
cd /etc/asterisk/keys

# Generar certificado
print_info "Generando certificado autofirmado..."
openssl req -new -x509 -nodes \
    -out asterisk-cert.pem \
    -keyout asterisk-key.pem \
    -days 365 \
    -subj "/C=CL/ST=Region/L=Ciudad/O=DUOC/OU=Lab/CN=$PRIVATE_IP" \
    2>/dev/null

chmod 600 asterisk-key.pem
chown asterisk:asterisk asterisk-*.pem

print_success "Certificados generados"
print_info "Cert: /etc/asterisk/keys/asterisk-cert.pem"
print_info "Key: /etc/asterisk/keys/asterisk-key.pem"

print_header "Paso 2: Configurar pjsip.conf con TLS/SRTP"

# Backup
BACKUP_FILE="/etc/asterisk/pjsip.conf.pre-lab2.3"
cp /etc/asterisk/pjsip.conf $BACKUP_FILE
print_success "Backup: $BACKUP_FILE"

cat > /etc/asterisk/pjsip.conf << 'EOF'
;
; Configuración PJSIP - Lab 2.3
; Con TLS y SRTP
;

[global]
type=global
max_forwards=70
default_realm=voip.local

;==============================================
; TRANSPORTS
;==============================================

; Transport UDP (opcional - mantener para compatibilidad)
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=EXTERNAL_IP
external_signaling_address=EXTERNAL_IP
local_net=10.0.0.0/8

; Transport TLS (Lab 2.3)
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk-cert.pem
priv_key_file=/etc/asterisk/keys/asterisk-key.pem
method=tlsv1_2
verify_server=no
verify_client=no
external_media_address=EXTERNAL_IP
external_signaling_address=EXTERNAL_IP
local_net=10.0.0.0/8

;==============================================
; TEMPLATES
;==============================================

[endpoint_template](!)
type=endpoint
context=internal
disallow=all
allow=ulaw
allow=alaw
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes

[auth_template](!)
type=auth
auth_type=userpass

[aor_template](!)
type=aor
max_contacts=1
remove_existing=yes

;==============================================
; EXTENSIONES CON TLS/SRTP
;==============================================

; Extensión 1001
[1001]
type=endpoint
transport=transport-tls
context=internal
disallow=all
allow=ulaw
allow=alaw
auth=auth1001
aors=1001
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
media_encryption=sdes
media_encryption_optimistic=no

[auth1001](auth_template)
username=1001
password=pass1001

[1001](aor_template)

; Extensión 1002
[1002]
type=endpoint
transport=transport-tls
context=internal
disallow=all
allow=ulaw
allow=alaw
auth=auth1002
aors=1002
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
media_encryption=sdes
media_encryption_optimistic=no

[auth1002](auth_template)
username=1002
password=pass1002

[1002](aor_template)

; Extensión 1003
[1003]
type=endpoint
transport=transport-tls
context=internal
disallow=all
allow=ulaw
allow=alaw
auth=auth1003
aors=1003
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
media_encryption=sdes
media_encryption_optimistic=no

[auth1003](auth_template)
username=1003
password=pass1003

[1003](aor_template)

EOF

# Actualizar IPs
if [ "$PUBLIC_IP" != "No disponible" ]; then
    sed -i "s/EXTERNAL_IP/$PUBLIC_IP/g" /etc/asterisk/pjsip.conf
else
    sed -i "s/EXTERNAL_IP/$PRIVATE_IP/g" /etc/asterisk/pjsip.conf
    print_warning "Usando IP privada como external (no hay IP pública)"
fi

print_success "pjsip.conf actualizado con TLS/SRTP"

print_header "Paso 3: Configurar rtp.conf"

cat > /etc/asterisk/rtp.conf << 'EOF'
[general]
rtpstart=10000
rtpend=20000
strictrtp=yes
icesupport=yes
stunaddr=stun.l.google.com:19302
EOF

print_success "rtp.conf configurado"

print_header "Paso 4: Iniciar Asterisk"
systemctl start asterisk
sleep 3

if systemctl is-active --quiet asterisk; then
    print_success "Asterisk iniciado correctamente"
else
    print_error "Asterisk no inició"
    print_info "Ver logs: sudo journalctl -u asterisk -n 50"
    exit 1
fi

# Verificar puerto TLS
sleep 2
if netstat -tulpn 2>/dev/null | grep -q ":5061"; then
    print_success "Puerto 5061 (TLS) escuchando"
else
    print_warning "Puerto 5061 no visible (verificar manualmente)"
fi

# Verificar endpoints
sleep 2
ENDPOINTS=$(asterisk -rx "pjsip show endpoints" 2>/dev/null | grep -c "1001\|1002\|1003" || echo "0")
if [ "$ENDPOINTS" -ge 3 ]; then
    print_success "Endpoints PJSIP configurados ($ENDPOINTS)"
else
    print_warning "Verificar endpoints manualmente"
fi

print_header "LAB 2.3 ASTERISK TLS/SRTP CONFIGURADO"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         ASTERISK TLS/SRTP CONFIGURADO                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Configuración:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  └─ IP Pública: $PUBLIC_IP"
echo ""
echo "🎛️  Componentes Lab 2.3:"
echo "  ✓ Transport TLS configurado"
echo "  ✓ Certificados autofirmados"
echo "  ✓ SRTP (SDES) en endpoints"
echo "  ✓ media_encryption_optimistic=no"
echo ""
echo "🔌 Puertos:"
echo "  ├─ 5060 UDP (opcional, compatibilidad)"
echo "  └─ 5061 TCP (TLS)"
echo ""
echo "🔐 Certificados:"
echo "  ├─ Cert: /etc/asterisk/keys/asterisk-cert.pem"
echo "  └─ Key: /etc/asterisk/keys/asterisk-key.pem"
echo ""
echo "👥 Extensiones configuradas:"
echo "  ├─ 1001 (TLS, SRTP mandatory)"
echo "  ├─ 1002 (TLS, SRTP mandatory)"
echo "  └─ 1003 (TLS, SRTP mandatory)"
echo ""
echo "⚠️  Security Groups AWS:"
echo "  En SG-Asterisk agregar:"
echo "    └─ 5061 TCP → sg-kamailio"
echo ""
echo "🧪 Verificación:"
echo "  1. Ver endpoints:"
echo "     asterisk -rx 'pjsip show endpoints'"
echo ""
echo "  2. Ver transports:"
echo "     asterisk -rx 'pjsip show transports'"
echo ""
echo "  3. Ver puertos:"
echo "     netstat -tulpn | grep asterisk"
echo ""
echo "  4. Probar conexión TLS:"
echo "     openssl s_client -connect localhost:5061"
echo ""
echo "  5. Verificar en Wireshark:"
echo "     - Debe verse TLS handshake"
echo "     - SDP debe contener 'a=crypto'"
echo "     - RTP debe aparecer como SRTP"
echo ""
echo "📱 Configuración Softphone:"
echo "  - Server: IP_PUBLICA_KAMAILIO"
echo "  - Port: 5061"
echo "  - Transport: TLS"
echo "  - Media encryption: SRTP (Mandatory)"
echo "  - Desactivar verificación certificado"
echo ""
echo "💾 Backup de configuración anterior:"
echo "  └─ $BACKUP_FILE"
echo ""
echo "✅ Lab 2.3 COMPLETO"
echo "   Ahora tienes:"
echo "   ├─ Kamailio con TLS (5061)"
echo "   ├─ Asterisk con TLS/SRTP (5061)"
echo "   ├─ Señalización cifrada (TLS)"
echo "   └─ Medios cifrados (SRTP)"
echo ""

print_success "¡Lab 2.3 completo!"
print_info "Probar con softphone configurado para TLS/SRTP"
