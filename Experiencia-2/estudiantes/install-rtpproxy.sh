#!/bin/bash
#
# Script de Instalación de RTPProxy para Laboratorios VoIP
# Curso: CUY5132 - Comunicaciones Unificadas
# Plataforma: Ubuntu 24.04 LTS en AWS Academy
# Versión: 2.0
#
# Este script instala y configura RTPProxy para relay de medios
# Para uso en Labs 2.2, 2.3 y 2.4
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

print_header "Instalación de RTPProxy para Labs VoIP"

# Obtener información de IPs
print_info "Obteniendo información de red..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me || echo "No disponible")

echo ""
echo "Información de red detectada:"
echo "  IP Privada: $PRIVATE_IP"
echo "  IP Pública: $PUBLIC_IP"
echo ""

if [ "$PUBLIC_IP" == "No disponible" ]; then
    print_warning "No se pudo obtener IP pública. Verifica tu conexión a Internet."
    read -p "¿Deseas continuar de todas formas? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Paso 1: Actualizar sistema
print_header "Paso 1: Actualizando sistema"
apt update -y
print_success "Sistema actualizado"

# Paso 2: Instalar RTPProxy
print_header "Paso 2: Instalando RTPProxy"
apt install -y rtpproxy
print_success "RTPProxy instalado"

# Verificar instalación
if ! command -v rtpproxy &> /dev/null; then
    print_error "RTPProxy no se instaló correctamente"
    exit 1
fi

RTPPROXY_VERSION=$(rtpproxy -V 2>&1 | head -1)
print_success "Versión instalada: $RTPPROXY_VERSION"

# Paso 3: Detener RTPProxy para configuración
print_header "Paso 3: Preparando configuración"
systemctl stop rtpproxy 2>/dev/null || true
print_success "RTPProxy detenido para configuración"

# Paso 4: Backup de configuración original
print_header "Paso 4: Respaldo de configuración original"
if [ -f /etc/default/rtpproxy ]; then
    cp /etc/default/rtpproxy /etc/default/rtpproxy.backup-$(date +%Y%m%d-%H%M%S)
    print_success "Backup creado"
else
    print_info "No hay configuración previa"
fi

# Paso 5: Configurar RTPProxy
print_header "Paso 5: Configurando RTPProxy"

cat > /etc/default/rtpproxy << EOF
#
# Configuración RTPProxy para Laboratorios VoIP
# CUY5132 - Comunicaciones Unificadas
#

# Usuario bajo el cual corre RTPProxy
USER=rtpproxy
GROUP=rtpproxy

# Opciones de RTPProxy
# -l: IP privada/IP pública (para NAT traversal)
# -s: Socket de control (Kamailio se conecta aquí)
# -m: Puerto RTP mínimo
# -M: Puerto RTP máximo
# -d: Nivel de debug (INFO para producción)

EXTRA_OPTS="-l $PRIVATE_IP/$PUBLIC_IP -s udp:127.0.0.1:7722 -m 10000 -M 20000 -d INFO"

# Opciones adicionales (descomentar si es necesario):
# -F: Log a syslog
# -p: Archivo PID
# -r: Directorio de grabación (opcional)

# Para debug más verboso, cambiar -d INFO a -d DBUG

EOF

print_success "Archivo /etc/default/rtpproxy creado"

# Mostrar configuración
echo ""
echo "Configuración aplicada:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  ├─ IP Pública: $PUBLIC_IP"
echo "  ├─ Socket control: udp:127.0.0.1:7722"
echo "  ├─ Puerto RTP mín: 10000"
echo "  ├─ Puerto RTP máx: 20000"
echo "  └─ Debug level: INFO"
echo ""

# Paso 6: Crear directorio de logs
print_header "Paso 6: Configurando logs"
mkdir -p /var/log/rtpproxy
chown rtpproxy:rtpproxy /var/log/rtpproxy
print_success "Directorio de logs creado"

# Paso 7: Habilitar inicio automático
print_header "Paso 7: Configurando inicio automático"
systemctl enable rtpproxy
print_success "RTPProxy habilitado para inicio automático"

# Paso 8: Iniciar RTPProxy
print_header "Paso 8: Iniciando RTPProxy"
systemctl start rtpproxy

# Esperar a que inicie
sleep 2

# Verificar estado
if systemctl is-active --quiet rtpproxy; then
    print_success "RTPProxy está corriendo"
else
    print_error "RTPProxy no se inició correctamente"
    print_info "Ver logs: sudo journalctl -u rtpproxy -n 50"
    exit 1
fi

# Paso 9: Verificación final
print_header "Paso 9: Verificación de instalación"

# Verificar que está escuchando en socket
if ss -ulpn | grep -q ":7722"; then
    print_success "Socket de control 7722 escuchando"
else
    print_warning "Socket 7722 no está escuchando"
fi

# Verificar proceso
if pgrep -x "rtpproxy" > /dev/null; then
    print_success "Proceso RTPProxy corriendo"
    PID=$(pgrep -x "rtpproxy")
    print_info "PID: $PID"
else
    print_warning "Proceso RTPProxy no encontrado"
fi

# Resumen final
print_header "INSTALACIÓN COMPLETADA"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          RTPPROXY INSTALADO EXITOSAMENTE                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Información del Sistema:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  ├─ IP Pública: $PUBLIC_IP"
echo "  └─ Versión: $RTPPROXY_VERSION"
echo ""
echo "Configuración RTPProxy:"
echo "  ├─ Socket control: udp:127.0.0.1:7722"
echo "  ├─ Puertos RTP: 10000-20000"
echo "  ├─ Listener: $PRIVATE_IP (privada)"
echo "  └─ Advertise: $PUBLIC_IP (pública)"
echo ""
echo "Archivos de Configuración:"
echo "  ├─ /etc/default/rtpproxy"
echo "  └─ Logs: /var/log/rtpproxy/"
echo ""
echo "Comandos Útiles:"
echo "  ├─ Ver estado: systemctl status rtpproxy"
echo "  ├─ Ver logs: sudo journalctl -u rtpproxy -f"
echo "  ├─ Ver sockets: ss -ulpn | grep 7722"
echo "  ├─ Ver procesos: ps aux | grep rtpproxy"
echo "  └─ Reiniciar: sudo systemctl restart rtpproxy"
echo ""
echo "⚠ IMPORTANTE - Security Groups AWS:"
echo "  En el Security Group de Kamailio:"
echo "    └─ Abrir 10000-20000 UDP (RTP) a 0.0.0.0/0"
echo ""
echo "📖 Integración con Kamailio:"
echo "  En /etc/kamailio/kamailio.cfg agregar:"
echo "    loadmodule \"rtpproxy.so\""
echo "    modparam(\"rtpproxy\", \"rtpproxy_sock\", \"udp:127.0.0.1:7722\")"
echo ""
echo "  En route[NATMANAGE]:"
echo "    if (is_method(\"INVITE|UPDATE\")) {"
echo "        rtpproxy_manage(\"co\");"
echo "    }"
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
echo "1. Verificar que RTPProxy está corriendo:"
echo "   sudo systemctl status rtpproxy"
echo "   sudo ss -ulpn | grep 7722"
echo ""
echo "2. Configurar Kamailio para usar RTPProxy:"
echo "   - Editar /etc/kamailio/kamailio.cfg"
echo "   - Cargar módulo rtpproxy"
echo "   - Configurar rtpproxy_sock"
echo "   - Agregar rtpproxy_manage() en rutas"
echo ""
echo "3. Configurar Security Groups en AWS:"
echo "   - Abrir puertos 10000-20000 UDP en SG-Kamailio"
echo ""
echo "4. Reiniciar Kamailio:"
echo "   sudo systemctl restart kamailio"
echo ""
echo "5. Probar llamada con cliente NAT:"
echo "   - Audio debe funcionar en ambas direcciones"
echo ""
echo "6. Verificar logs durante llamada:"
echo "   sudo tail -f /var/log/syslog | grep rtpproxy"
echo ""
echo "═══════════════════════════════════════════════════════════"

# Test de conectividad (opcional)
echo ""
read -p "¿Deseas ejecutar test de conectividad? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_header "Test de Conectividad"
    
    # Test socket
    if echo "V" | nc -u -w1 127.0.0.1 7722 > /dev/null 2>&1; then
        print_success "Socket de control responde correctamente"
    else
        print_warning "Socket de control no responde (puede ser normal)"
    fi
    
    # Mostrar puertos abiertos
    echo ""
    print_info "Puertos UDP abiertos en rango RTP:"
    ss -ulpn | grep rtpproxy | head -5
    
    echo ""
    print_success "Test completado"
fi

echo ""
print_info "Para más información, consulta las guías de laboratorio"
