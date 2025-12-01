#!/bin/bash
#
# Script de Instalación de Asterisk para Laboratorios VoIP
# Curso: CUY5132 - Comunicaciones Unificadas
# Plataforma: Ubuntu 24.04 LTS en AWS Academy
# Versión: 2.0
#
# Este script instala y configura Asterisk como PBX interno
# Para uso en Labs 2.1, 2.2, 2.3 y 2.4
#

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root (usa sudo)"
   exit 1
fi

# Verificar que estamos en Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    print_error "Este script está diseñado para Ubuntu 24.04"
    exit 1
fi

print_header "Instalación de Asterisk para Labs VoIP"

# Obtener información de IPs
print_info "Obteniendo información de red..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me || echo "No disponible")

echo ""
echo "Información de red detectada:"
echo "  IP Privada: $PRIVATE_IP"
echo "  IP Pública: $PUBLIC_IP"
echo ""

# Paso 1: Actualizar sistema
print_header "Paso 1: Actualizando sistema"
apt update -y
apt upgrade -y
print_success "Sistema actualizado"

# Paso 2: Instalar Asterisk
print_header "Paso 2: Instalando Asterisk"
apt install -y asterisk
print_success "Asterisk instalado"

# Verificar instalación
if ! command -v asterisk &> /dev/null; then
    print_error "Asterisk no se instaló correctamente"
    exit 1
fi

ASTERISK_VERSION=$(asterisk -V)
print_success "Versión instalada: $ASTERISK_VERSION"

# Paso 3: Detener Asterisk para configuración
print_header "Paso 3: Preparando configuración"
systemctl stop asterisk
print_success "Asterisk detenido para configuración"

# Paso 4: Backup de configuraciones originales
print_header "Paso 4: Respaldo de configuraciones originales"
BACKUP_DIR="/etc/asterisk/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR
cp /etc/asterisk/pjsip.conf $BACKUP_DIR/ 2>/dev/null || true
cp /etc/asterisk/extensions.conf $BACKUP_DIR/ 2>/dev/null || true
print_success "Backup creado en: $BACKUP_DIR"

# Paso 5: Configurar PJSIP
print_header "Paso 5: Configurando PJSIP"

cat > /etc/asterisk/pjsip.conf << 'EOF'
;
; Configuración PJSIP para Laboratorios VoIP
; CUY5132 - Comunicaciones Unificadas
;

[global]
type=global
max_forwards=70
default_realm=voip.local

;==============================================
; TRANSPORTS
;==============================================

; Transport UDP (Labs 2.1, 2.2)
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=AUTO_PUBLIC_IP
external_signaling_address=AUTO_PUBLIC_IP
local_net=10.0.0.0/8

; Transport TLS (Lab 2.3+)
; Descomentar después de generar certificados
;[transport-tls]
;type=transport
;protocol=tls
;bind=0.0.0.0:5061
;cert_file=/etc/asterisk/keys/asterisk-cert.pem
;priv_key_file=/etc/asterisk/keys/asterisk-key.pem
;method=tlsv1_2

;==============================================
; TEMPLATES
;==============================================

; Template para endpoints básicos
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

; Template para autenticación
[auth_template](!)
type=auth
auth_type=userpass

; Template para AOR
[aor_template](!)
type=aor
max_contacts=1
remove_existing=yes

;==============================================
; EXTENSIONES
;==============================================

; Extensión 1001
[1001]
type=endpoint
transport=transport-udp
;transport=transport-tls  ; Descomentar para Lab 2.3
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
;media_encryption=sdes  ; Descomentar para Lab 2.3 (SRTP)
;media_encryption_optimistic=no

[auth1001](auth_template)
username=1001
password=pass1001

[1001](aor_template)

; Extensión 1002
[1002]
type=endpoint
transport=transport-udp
;transport=transport-tls  ; Descomentar para Lab 2.3
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
;media_encryption=sdes  ; Descomentar para Lab 2.3 (SRTP)
;media_encryption_optimistic=no

[auth1002](auth_template)
username=1002
password=pass1002

[1002](aor_template)

; Extensión 1003
[1003]
type=endpoint
transport=transport-udp
;transport=transport-tls  ; Descomentar para Lab 2.3
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
;media_encryption=sdes  ; Descomentar para Lab 2.3 (SRTP)
;media_encryption_optimistic=no

[auth1003](auth_template)
username=1003
password=pass1003

[1003](aor_template)

EOF

print_success "Archivo pjsip.conf creado"

# Actualizar IPs en pjsip.conf
sed -i "s/AUTO_PUBLIC_IP/$PUBLIC_IP/g" /etc/asterisk/pjsip.conf
print_success "IPs actualizadas en pjsip.conf"

# Paso 6: Configurar Dialplan
print_header "Paso 6: Configurando Dialplan"

cat > /etc/asterisk/extensions.conf << 'EOF'
;
; Dialplan para Laboratorios VoIP
; CUY5132 - Comunicaciones Unificadas
;

[general]
static=yes
writeprotect=no
clearglobalvars=no

[globals]

;==============================================
; CONTEXTO INTERNAL
; Llamadas entre extensiones
;==============================================

[internal]
; Llamadas entre extensiones (1001, 1002, 1003)
exten => 1001,1,NoOp(Llamada a extensión 1001)
 same => n,Dial(PJSIP/1001,30)
 same => n,Hangup()

exten => 1002,1,NoOp(Llamada a extensión 1002)
 same => n,Dial(PJSIP/1002,30)
 same => n,Hangup()

exten => 1003,1,NoOp(Llamada a extensión 1003)
 same => n,Dial(PJSIP/1003,30)
 same => n,Hangup()

; Test de echo (extensión 9999)
exten => 9999,1,NoOp(Test de Echo)
 same => n,Answer()
 same => n,Playback(demo-echotest)
 same => n,Echo()
 same => n,Hangup()

EOF

print_success "Archivo extensions.conf creado"

# Paso 7: Configurar RTP
print_header "Paso 7: Configurando RTP"

cat > /etc/asterisk/rtp.conf << 'EOF'
;
; RTP Configuration
;

[general]
rtpstart=10000
rtpend=20000
strictrtp=yes
icesupport=yes
stunaddr=stun.l.google.com:19302

EOF

print_success "Archivo rtp.conf creado"

# Paso 8: Habilitar inicio automático
print_header "Paso 8: Configurando inicio automático"
systemctl enable asterisk
print_success "Asterisk habilitado para inicio automático"

# Paso 9: Iniciar Asterisk
print_header "Paso 9: Iniciando Asterisk"
systemctl start asterisk

# Esperar a que inicie
sleep 3

# Verificar estado
if systemctl is-active --quiet asterisk; then
    print_success "Asterisk está corriendo"
else
    print_error "Asterisk no se inició correctamente"
    print_info "Ver logs: sudo journalctl -u asterisk -n 50"
    exit 1
fi

# Paso 10: Verificación final
print_header "Paso 10: Verificación de instalación"

# Verificar que está escuchando en puertos
if netstat -tulpn | grep -q ":5060"; then
    print_success "Puerto 5060 (SIP) escuchando"
else
    print_warning "Puerto 5060 no está escuchando"
fi

# Verificar endpoints PJSIP
ENDPOINTS=$(asterisk -rx "pjsip show endpoints" | grep -c "1001\|1002\|1003")
if [ $ENDPOINTS -ge 3 ]; then
    print_success "Endpoints PJSIP configurados correctamente"
else
    print_warning "Algunos endpoints no están configurados"
fi

# Resumen final
print_header "INSTALACIÓN COMPLETADA"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           ASTERISK INSTALADO EXITOSAMENTE                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Información del Sistema:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  ├─ IP Pública: $PUBLIC_IP"
echo "  └─ Versión: $ASTERISK_VERSION"
echo ""
echo "Extensiones Configuradas:"
echo "  ├─ 1001 (password: pass1001)"
echo "  ├─ 1002 (password: pass1002)"
echo "  ├─ 1003 (password: pass1003)"
echo "  └─ 9999 (test de echo)"
echo ""
echo "Puertos Configurados:"
echo "  ├─ SIP UDP: 5060"
echo "  └─ RTP: 10000-20000"
echo ""
echo "Configuración TLS/SRTP (Lab 2.3):"
echo "  ├─ Transport TLS: Comentado (descomentar después)"
echo "  ├─ Puerto TLS: 5061"
echo "  └─ SRTP: Comentado (descomentar después)"
echo ""
echo "Archivos de Configuración:"
echo "  ├─ /etc/asterisk/pjsip.conf"
echo "  ├─ /etc/asterisk/extensions.conf"
echo "  ├─ /etc/asterisk/rtp.conf"
echo "  └─ Backup: $BACKUP_DIR"
echo ""
echo "Comandos Útiles:"
echo "  ├─ Ver estado: systemctl status asterisk"
echo "  ├─ CLI: sudo asterisk -rvvv"
echo "  ├─ Ver endpoints: asterisk -rx 'pjsip show endpoints'"
echo "  ├─ Ver contactos: asterisk -rx 'pjsip show contacts'"
echo "  └─ Reiniciar: sudo systemctl restart asterisk"
echo ""
echo "⚠ IMPORTANTE - Security Groups AWS:"
echo "  Para Lab 2.1:"
echo "    ├─ Abrir 5060 UDP (SIP) a 0.0.0.0/0"
echo "    └─ Abrir 10000-20000 UDP (RTP) a 0.0.0.0/0"
echo ""
echo "  Para Lab 2.2+:"
echo "    ├─ Abrir 5060 UDP solo desde IP de Kamailio"
echo "    └─ Abrir 10000-20000 UDP solo desde IP de Kamailio"
echo ""
echo "  Para Lab 2.3+:"
echo "    └─ Agregar 5061 TCP desde IP de Kamailio"
echo ""
echo "📖 Documentación:"
echo "  └─ https://github.com/nicsanchezr/NEW-CUY5132-DUOC"
echo ""

print_success "¡Instalación completada exitosamente!"

# Mostrar próximos pasos
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "PRÓXIMOS PASOS:"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "1. Verificar instalación:"
echo "   sudo asterisk -rvvv"
echo "   pjsip show endpoints"
echo ""
echo "2. Configurar Security Groups en AWS Console"
echo ""
echo "3. Probar registro desde softphone:"
echo "   - Server: $PRIVATE_IP (si desde Kamailio)"
echo "   - Username: 1001"
echo "   - Password: pass1001"
echo "   - Port: 5060"
echo ""
echo "4. Para Lab 2.3 (TLS/SRTP):"
echo "   - Generar certificados en /etc/asterisk/keys/"
echo "   - Descomentar secciones TLS en pjsip.conf"
echo "   - Reiniciar Asterisk"
echo ""
echo "═══════════════════════════════════════════════════════════"
