#!/bin/bash
#
# Script de Actualización de IPs
# Curso: CUY5132 - Comunicaciones Unificadas
# Versión: 2.0
#
# Este script actualiza las IPs en las configuraciones
# cuando AWS Academy cambia las IPs públicas
#

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ ERROR: $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     ACTUALIZACIÓN DE IPs DINÁMICAS                           ║
║     CUY5132 - Comunicaciones Unificadas                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Este script actualiza las configuraciones cuando AWS"
echo "cambia tu IP pública al detener/iniciar instancias."
echo ""

# Verificar permisos
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root"
   echo "Uso: sudo bash $0"
   exit 1
fi

# Detectar componentes
ASTERISK_INSTALLED=false
KAMAILIO_INSTALLED=false
RTPPROXY_INSTALLED=false

command -v asterisk &>/dev/null && ASTERISK_INSTALLED=true
command -v kamailio &>/dev/null && KAMAILIO_INSTALLED=true
command -v rtpproxy &>/dev/null && RTPPROXY_INSTALLED=true

# Obtener IPs actuales
print_header "DETECTANDO IPs ACTUALES"

PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me || echo "ERROR")

if [ "$PUBLIC_IP" == "ERROR" ]; then
    print_error "No se pudo obtener IP pública"
    echo "Verifica tu conexión a Internet"
    exit 1
fi

echo "IPs detectadas:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  └─ IP Pública: $PUBLIC_IP"
echo ""

# Obtener IPs antiguas de configuraciones
print_header "DETECTANDO IPs ANTIGUAS"

OLD_PUBLIC_IP=""
OLD_PRIVATE_IP=""

# Buscar en Kamailio
if [ -f /etc/kamailio/kamailio.cfg ]; then
    OLD_PUBLIC_IP=$(grep "advertise" /etc/kamailio/kamailio.cfg | head -1 | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "")
    OLD_PRIVATE_IP=$(grep "listen=" /etc/kamailio/kamailio.cfg | head -1 | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "")
fi

# Buscar en RTPProxy
if [ -f /etc/default/rtpproxy ]; then
    RTPPROXY_IPS=$(grep "EXTRA_OPTS.*-l" /etc/default/rtpproxy | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "")
    if [ -z "$OLD_PRIVATE_IP" ]; then
        OLD_PRIVATE_IP=$(echo "$RTPPROXY_IPS" | head -1)
    fi
    if [ -z "$OLD_PUBLIC_IP" ]; then
        OLD_PUBLIC_IP=$(echo "$RTPPROXY_IPS" | tail -1)
    fi
fi

# Buscar en Asterisk
if [ -f /etc/asterisk/pjsip.conf ]; then
    ASTERISK_IP=$(grep "external_media_address" /etc/asterisk/pjsip.conf | head -1 | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "")
    if [ -z "$OLD_PUBLIC_IP" ] && [ -n "$ASTERISK_IP" ]; then
        OLD_PUBLIC_IP="$ASTERISK_IP"
    fi
fi

if [ -n "$OLD_PUBLIC_IP" ] && [ -n "$OLD_PRIVATE_IP" ]; then
    echo "IPs en configuraciones actuales:"
    echo "  ├─ IP Privada: $OLD_PRIVATE_IP"
    echo "  └─ IP Pública: $OLD_PUBLIC_IP"
    echo ""
    
    # Comparar
    if [ "$OLD_PUBLIC_IP" == "$PUBLIC_IP" ] && [ "$OLD_PRIVATE_IP" == "$PRIVATE_IP" ]; then
        print_success "Las IPs NO han cambiado. No es necesario actualizar."
        echo ""
        read -p "¿Actualizar de todas formas? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Saliendo sin cambios."
            exit 0
        fi
    else
        print_warning "Las IPs HAN CAMBIADO. Es necesario actualizar."
        echo ""
        echo "Cambios detectados:"
        if [ "$OLD_PRIVATE_IP" != "$PRIVATE_IP" ]; then
            echo "  ├─ IP Privada: $OLD_PRIVATE_IP → $PRIVATE_IP"
        fi
        if [ "$OLD_PUBLIC_IP" != "$PUBLIC_IP" ]; then
            echo "  └─ IP Pública: $OLD_PUBLIC_IP → $PUBLIC_IP"
        fi
        echo ""
    fi
else
    print_warning "No se pudieron detectar IPs antiguas"
    echo "Se usarán las IPs actuales detectadas"
    echo ""
fi

# Confirmar actualización
read -p "¿Proceder con la actualización? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado por el usuario."
    exit 0
fi

# Detener servicios
print_header "DETENIENDO SERVICIOS"

SERVICES_STOPPED=()

if $KAMAILIO_INSTALLED && systemctl is-active --quiet kamailio; then
    systemctl stop kamailio
    SERVICES_STOPPED+=("kamailio")
    print_success "Kamailio detenido"
fi

if $RTPPROXY_INSTALLED && systemctl is-active --quiet rtpproxy; then
    systemctl stop rtpproxy
    SERVICES_STOPPED+=("rtpproxy")
    print_success "RTPProxy detenido"
fi

if $ASTERISK_INSTALLED && systemctl is-active --quiet asterisk; then
    systemctl stop asterisk
    SERVICES_STOPPED+=("asterisk")
    print_success "Asterisk detenido"
fi

# Crear backups
print_header "CREANDO BACKUPS"

BACKUP_DIR="/tmp/voip-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f /etc/kamailio/kamailio.cfg ]; then
    cp /etc/kamailio/kamailio.cfg "$BACKUP_DIR/"
    print_success "Backup: kamailio.cfg"
fi

if [ -f /etc/default/rtpproxy ]; then
    cp /etc/default/rtpproxy "$BACKUP_DIR/"
    print_success "Backup: rtpproxy"
fi

if [ -f /etc/asterisk/pjsip.conf ]; then
    cp /etc/asterisk/pjsip.conf "$BACKUP_DIR/"
    print_success "Backup: pjsip.conf"
fi

echo "Backups guardados en: $BACKUP_DIR"

# Actualizar configuraciones
print_header "ACTUALIZANDO CONFIGURACIONES"

FILES_UPDATED=0

# Actualizar Kamailio
if [ -f /etc/kamailio/kamailio.cfg ]; then
    print_info "Actualizando Kamailio..."
    
    # Actualizar listen
    sed -i "s/listen=udp:[0-9.]*:5060/listen=udp:$PRIVATE_IP:5060/g" /etc/kamailio/kamailio.cfg
    
    # Actualizar advertise
    sed -i "s/advertise [0-9.]*:5060/advertise $PUBLIC_IP:5060/g" /etc/kamailio/kamailio.cfg
    
    # Verificar sintaxis
    if kamailio -c -f /etc/kamailio/kamailio.cfg &>/dev/null; then
        print_success "Kamailio configuración actualizada y válida"
        ((FILES_UPDATED++))
    else
        print_error "Error en configuración de Kamailio"
        echo "Restaurando backup..."
        cp "$BACKUP_DIR/kamailio.cfg" /etc/kamailio/
        print_warning "Backup restaurado"
    fi
fi

# Actualizar RTPProxy
if [ -f /etc/default/rtpproxy ]; then
    print_info "Actualizando RTPProxy..."
    
    # Actualizar IPs
    sed -i "s/-l [0-9.]*/[0-9.]*/-l $PRIVATE_IP\/$PUBLIC_IP/g" /etc/default/rtpproxy
    
    print_success "RTPProxy configuración actualizada"
    ((FILES_UPDATED++))
fi

# Actualizar Asterisk
if [ -f /etc/asterisk/pjsip.conf ]; then
    print_info "Actualizando Asterisk..."
    
    # Actualizar external_media_address
    sed -i "s/external_media_address=[0-9.]*/external_media_address=$PUBLIC_IP/g" /etc/asterisk/pjsip.conf
    
    # Actualizar external_signaling_address
    sed -i "s/external_signaling_address=[0-9.]*/external_signaling_address=$PUBLIC_IP/g" /etc/asterisk/pjsip.conf
    
    print_success "Asterisk configuración actualizada"
    ((FILES_UPDATED++))
fi

echo ""
echo "Archivos actualizados: $FILES_UPDATED"

# Reiniciar servicios
print_header "REINICIANDO SERVICIOS"

SERVICES_STARTED=0

for service in "${SERVICES_STOPPED[@]}"; do
    systemctl start "$service"
    sleep 2
    
    if systemctl is-active --quiet "$service"; then
        print_success "$service reiniciado correctamente"
        ((SERVICES_STARTED++))
    else
        print_error "$service NO se pudo reiniciar"
        echo "Ver logs: sudo journalctl -u $service -n 50"
    fi
done

# Verificación final
print_header "VERIFICACIÓN FINAL"

echo ""
echo "Estado de servicios:"

for service in "${SERVICES_STOPPED[@]}"; do
    STATUS=$(systemctl is-active "$service")
    if [ "$STATUS" == "active" ]; then
        echo -e "  ${GREEN}✓${NC} $service: $STATUS"
    else
        echo -e "  ${RED}✗${NC} $service: $STATUS"
    fi
done

echo ""
echo "Puertos escuchando:"

if netstat -tulpn 2>/dev/null | grep -q ":5060"; then
    echo -e "  ${GREEN}✓${NC} Puerto 5060 (SIP)"
else
    echo -e "  ${RED}✗${NC} Puerto 5060 (SIP)"
fi

if netstat -tulpn 2>/dev/null | grep -q ":7722"; then
    echo -e "  ${GREEN}✓${NC} Puerto 7722 (RTPProxy)"
else
    echo -e "  ${YELLOW}⚠${NC} Puerto 7722 (RTPProxy) - normal si no usas RTPProxy"
fi

# Resumen final
print_header "RESUMEN"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          ACTUALIZACIÓN COMPLETADA                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "IPs actualizadas:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  └─ IP Pública: $PUBLIC_IP"
echo ""
echo "Archivos modificados: $FILES_UPDATED"
echo "Servicios reiniciados: $SERVICES_STARTED"
echo ""
echo "Backups disponibles en:"
echo "  └─ $BACKUP_DIR"
echo ""

if [ "$FILES_UPDATED" -gt 0 ] && [ "$SERVICES_STARTED" -eq "${#SERVICES_STOPPED[@]}" ]; then
    print_success "¡Actualización exitosa!"
    echo ""
    echo "Próximos pasos:"
    echo "  1. Actualizar softphones con nueva IP pública"
    echo "  2. Probar registro desde softphone"
    echo "  3. Realizar llamada de prueba"
    echo ""
    EXIT_CODE=0
else
    print_warning "Actualización con advertencias"
    echo ""
    echo "Verificar:"
    echo "  1. Logs de servicios"
    echo "  2. Configuraciones en $BACKUP_DIR"
    echo ""
    EXIT_CODE=1
fi

echo "Para más información:"
echo "  └─ https://github.com/nicsanchezr/NEW-CUY5132-DUOC"
echo ""

# Guardar IPs en archivo para referencia
cat > /tmp/current-voip-ips.txt << EOF
# IPs actuales - $(date)
IP_PRIVADA=$PRIVATE_IP
IP_PUBLICA=$PUBLIC_IP

# Configurar softphone con:
# Server: $PUBLIC_IP
# Port: 5060 (o 5061 para TLS)
EOF

print_info "IPs guardadas en: /tmp/current-voip-ips.txt"

exit $EXIT_CODE
