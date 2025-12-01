#!/bin/bash
#
# Script de Verificación de Instalación VoIP
# Curso: CUY5132 - Comunicaciones Unificadas
# Versión: 2.0
#
# Este script verifica que los servicios VoIP estén
# correctamente instalados y configurados
#

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Contadores
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Funciones
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_section() {
    echo ""
    echo -e "${MAGENTA}━━━ $1 ━━━${NC}"
}

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     VERIFICACIÓN DE INSTALACIÓN VOIP                         ║
║     CUY5132 - Comunicaciones Unificadas                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Detectar componentes instalados
ASTERISK_INSTALLED=false
KAMAILIO_INSTALLED=false
RTPPROXY_INSTALLED=false

command -v asterisk &>/dev/null && ASTERISK_INSTALLED=true
command -v kamailio &>/dev/null && KAMAILIO_INSTALLED=true
command -v rtpproxy &>/dev/null && RTPPROXY_INSTALLED=true

echo "Componentes detectados:"
$ASTERISK_INSTALLED && echo "  ✓ Asterisk" || echo "  ✗ Asterisk"
$KAMAILIO_INSTALLED && echo "  ✓ Kamailio" || echo "  ✗ Kamailio"
$RTPPROXY_INSTALLED && echo "  ✓ RTPProxy" || echo "  ✗ RTPProxy"
echo ""

# ============================================
# VERIFICACIÓN DE SISTEMA
# ============================================

print_section "SISTEMA OPERATIVO"

# OS
if grep -q "Ubuntu" /etc/os-release; then
    VERSION=$(lsb_release -rs)
    if [ "$VERSION" == "24.04" ]; then
        check_pass "Ubuntu 24.04 LTS detectado"
    else
        check_warn "Ubuntu $VERSION (recomendado: 24.04)"
    fi
else
    check_fail "No es Ubuntu (recomendado: Ubuntu 24.04)"
fi

# Internet
if ping -c 1 8.8.8.8 &>/dev/null; then
    check_pass "Conectividad a Internet"
else
    check_fail "Sin conectividad a Internet"
fi

# Disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    check_pass "Espacio en disco: ${DISK_USAGE}% usado"
else
    check_warn "Espacio en disco: ${DISK_USAGE}% usado (>80%)"
fi

# ============================================
# VERIFICACIÓN DE RED
# ============================================

print_section "CONFIGURACIÓN DE RED"

# IPs
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me || echo "No disponible")

if [ -n "$PRIVATE_IP" ]; then
    check_pass "IP Privada: $PRIVATE_IP"
else
    check_fail "IP Privada no detectada"
fi

if [ "$PUBLIC_IP" != "No disponible" ]; then
    check_pass "IP Pública: $PUBLIC_IP"
else
    check_warn "IP Pública no detectada (normal si es Asterisk privado)"
fi

# ============================================
# VERIFICACIÓN DE ASTERISK
# ============================================

if $ASTERISK_INSTALLED; then
    print_section "ASTERISK PBX"
    
    # Servicio corriendo
    if systemctl is-active --quiet asterisk; then
        check_pass "Servicio Asterisk activo"
    else
        check_fail "Servicio Asterisk NO activo"
        print_info "  └─ Iniciar: sudo systemctl start asterisk"
    fi
    
    # Habilitado
    if systemctl is-enabled --quiet asterisk; then
        check_pass "Asterisk habilitado para inicio automático"
    else
        check_warn "Asterisk NO habilitado para inicio automático"
        print_info "  └─ Habilitar: sudo systemctl enable asterisk"
    fi
    
    # Puerto 5060
    if netstat -tulpn 2>/dev/null | grep -q ":5060.*asterisk\|:5060.*pjsip"; then
        check_pass "Puerto 5060 (SIP) escuchando"
    else
        check_fail "Puerto 5060 NO escuchando"
    fi
    
    # Archivos de configuración
    if [ -f /etc/asterisk/pjsip.conf ]; then
        check_pass "Archivo pjsip.conf existe"
        
        # Verificar extensiones
        ENDPOINTS=$(grep -c "^\[100" /etc/asterisk/pjsip.conf)
        if [ "$ENDPOINTS" -ge 3 ]; then
            check_pass "Extensiones configuradas: $ENDPOINTS"
        else
            check_warn "Pocas extensiones: $ENDPOINTS (esperado: ≥3)"
        fi
    else
        check_fail "Archivo pjsip.conf NO existe"
    fi
    
    if [ -f /etc/asterisk/extensions.conf ]; then
        check_pass "Archivo extensions.conf existe"
    else
        check_warn "Archivo extensions.conf NO existe"
    fi
    
    # CLI funcionando
    if timeout 2 asterisk -rx "core show version" &>/dev/null; then
        VERSION=$(asterisk -rx "core show version" 2>/dev/null | head -1)
        check_pass "CLI Asterisk funcional ($VERSION)"
        
        # Endpoints activos
        if timeout 2 asterisk -rx "pjsip show endpoints" &>/dev/null; then
            ACTIVE_EP=$(asterisk -rx "pjsip show endpoints" 2>/dev/null | grep -c "Endpoint:")
            if [ "$ACTIVE_EP" -ge 3 ]; then
                check_pass "Endpoints PJSIP activos: $ACTIVE_EP"
            else
                check_warn "Endpoints PJSIP: $ACTIVE_EP (esperado: ≥3)"
            fi
        fi
    else
        check_warn "No se pudo conectar al CLI de Asterisk"
    fi
fi

# ============================================
# VERIFICACIÓN DE KAMAILIO
# ============================================

if $KAMAILIO_INSTALLED; then
    print_section "KAMAILIO SBC"
    
    # Servicio corriendo
    if systemctl is-active --quiet kamailio; then
        check_pass "Servicio Kamailio activo"
    else
        check_fail "Servicio Kamailio NO activo"
        print_info "  └─ Iniciar: sudo systemctl start kamailio"
    fi
    
    # Habilitado
    if systemctl is-enabled --quiet kamailio; then
        check_pass "Kamailio habilitado para inicio automático"
    else
        check_warn "Kamailio NO habilitado para inicio automático"
        print_info "  └─ Habilitar: sudo systemctl enable kamailio"
    fi
    
    # Puerto 5060
    if netstat -tulpn 2>/dev/null | grep -q ":5060.*kamailio"; then
        check_pass "Puerto 5060 (SIP) escuchando"
    else
        check_fail "Puerto 5060 NO escuchando"
    fi
    
    # Configuración
    if [ -f /etc/kamailio/kamailio.cfg ]; then
        check_pass "Archivo kamailio.cfg existe"
        
        # Verificar sintaxis
        if kamailio -c -f /etc/kamailio/kamailio.cfg &>/dev/null; then
            check_pass "Configuración kamailio.cfg válida"
        else
            check_fail "Configuración kamailio.cfg tiene errores"
            print_info "  └─ Verificar: sudo kamailio -c"
        fi
        
        # Módulos importantes
        if grep -q "loadmodule.*nathelper" /etc/kamailio/kamailio.cfg; then
            check_pass "Módulo nathelper cargado"
        else
            check_warn "Módulo nathelper NO cargado (necesario para NAT)"
        fi
        
        if grep -q "loadmodule.*rtpproxy" /etc/kamailio/kamailio.cfg; then
            check_pass "Módulo rtpproxy cargado"
        else
            check_warn "Módulo rtpproxy NO cargado (necesario para Lab 2.2+)"
        fi
    else
        check_fail "Archivo kamailio.cfg NO existe"
    fi
    
    # CLI funcionando
    if command -v kamcmd &>/dev/null; then
        if timeout 2 kamcmd stats.get_statistics all &>/dev/null; then
            check_pass "CLI Kamailio (kamcmd) funcional"
        else
            check_warn "kamcmd no responde (Kamailio podría no estar corriendo)"
        fi
    else
        check_warn "kamcmd no instalado"
    fi
fi

# ============================================
# VERIFICACIÓN DE RTPPROXY
# ============================================

if $RTPPROXY_INSTALLED; then
    print_section "RTPPROXY"
    
    # Servicio corriendo
    if systemctl is-active --quiet rtpproxy; then
        check_pass "Servicio RTPProxy activo"
    else
        check_fail "Servicio RTPProxy NO activo"
        print_info "  └─ Iniciar: sudo systemctl start rtpproxy"
    fi
    
    # Habilitado
    if systemctl is-enabled --quiet rtpproxy; then
        check_pass "RTPProxy habilitado para inicio automático"
    else
        check_warn "RTPProxy NO habilitado para inicio automático"
        print_info "  └─ Habilitar: sudo systemctl enable rtpproxy"
    fi
    
    # Socket control
    if ss -ulpn 2>/dev/null | grep -q ":7722"; then
        check_pass "Socket control (7722) escuchando"
    else
        check_fail "Socket control (7722) NO escuchando"
    fi
    
    # Configuración
    if [ -f /etc/default/rtpproxy ]; then
        check_pass "Archivo configuración /etc/default/rtpproxy existe"
        
        # Verificar IPs
        if grep -q "EXTRA_OPTS.*-l.*/" /etc/default/rtpproxy; then
            check_pass "Configuración IPs (IP_PRIVADA/IP_PUBLICA)"
        else
            check_warn "Configuración IPs no detectada"
        fi
        
        # Verificar puertos RTP
        if grep -q "\-m.*10000.*\-M.*20000" /etc/default/rtpproxy; then
            check_pass "Puertos RTP configurados (10000-20000)"
        else
            check_warn "Puertos RTP no detectados"
        fi
    else
        check_fail "Archivo /etc/default/rtpproxy NO existe"
    fi
fi

# ============================================
# VERIFICACIÓN DE PUERTOS
# ============================================

print_section "PUERTOS Y CONECTIVIDAD"

# Puerto SSH
if netstat -tulpn 2>/dev/null | grep -q ":22"; then
    check_pass "Puerto 22 (SSH) escuchando"
else
    check_warn "Puerto 22 (SSH) no detectado"
fi

# Puertos SIP
SIP_LISTENING=$(netstat -tulpn 2>/dev/null | grep -c ":5060")
if [ "$SIP_LISTENING" -gt 0 ]; then
    check_pass "Puerto 5060 (SIP) escuchando ($SIP_LISTENING servicio(s))"
else
    check_fail "Puerto 5060 (SIP) NO escuchando"
fi

# Puerto TLS (si configurado)
if netstat -tulpn 2>/dev/null | grep -q ":5061"; then
    check_pass "Puerto 5061 (TLS) escuchando (Lab 2.3)"
else
    check_warn "Puerto 5061 (TLS) NO escuchando (normal para Lab 2.1-2.2)"
fi

# ============================================
# VERIFICACIÓN DE HERRAMIENTAS
# ============================================

print_section "HERRAMIENTAS DE DIAGNÓSTICO"

# tcpdump
if command -v tcpdump &>/dev/null; then
    check_pass "tcpdump instalado"
else
    check_warn "tcpdump NO instalado (recomendado)"
    print_info "  └─ Instalar: sudo apt install tcpdump"
fi

# sngrep
if command -v sngrep &>/dev/null; then
    check_pass "sngrep instalado (Lab 2.4)"
else
    check_warn "sngrep NO instalado (necesario para Lab 2.4)"
    print_info "  └─ Instalar: sudo apt install sngrep"
fi

# fail2ban
if command -v fail2ban-client &>/dev/null; then
    check_pass "fail2ban instalado (Lab 2.4)"
    
    if systemctl is-active --quiet fail2ban; then
        check_pass "fail2ban activo"
    else
        check_warn "fail2ban instalado pero NO activo"
    fi
else
    check_warn "fail2ban NO instalado (necesario para Lab 2.4)"
    print_info "  └─ Instalar: sudo apt install fail2ban"
fi

# netstat / ss
if command -v netstat &>/dev/null || command -v ss &>/dev/null; then
    check_pass "Herramientas de red (netstat/ss) disponibles"
else
    check_warn "netstat/ss NO disponibles"
    print_info "  └─ Instalar: sudo apt install net-tools"
fi

# ============================================
# RESUMEN FINAL
# ============================================

echo ""
print_header "RESUMEN DE VERIFICACIÓN"
echo ""

# Calcular porcentaje
PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo "Resultados:"
echo -e "  ${GREEN}✓ Pasadas:${NC}    $PASSED_CHECKS"
echo -e "  ${RED}✗ Fallidas:${NC}   $FAILED_CHECKS"
echo -e "  ${YELLOW}⚠ Advertencias:${NC} $WARNING_CHECKS"
echo -e "  ─────────────"
echo "  Total:        $TOTAL_CHECKS"
echo ""

# Barra de progreso
echo -n "Salud del sistema: ["
for i in {1..20}; do
    if [ $((i * 5)) -le $PERCENTAGE ]; then
        echo -ne "${GREEN}█${NC}"
    else
        echo -n "░"
    fi
done
echo "] ${PERCENTAGE}%"
echo ""

# Evaluación
if [ "$FAILED_CHECKS" -eq 0 ] && [ "$WARNING_CHECKS" -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ SISTEMA COMPLETAMENTE FUNCIONAL                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    EXIT_CODE=0
elif [ "$FAILED_CHECKS" -eq 0 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠ SISTEMA FUNCIONAL CON ADVERTENCIAS                      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Revisar advertencias arriba. El sistema debería funcionar."
    EXIT_CODE=0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ SISTEMA CON PROBLEMAS                                   ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Problemas detectados. Revisar errores marcados con ✗"
    EXIT_CODE=1
fi

echo ""
echo "Próximos pasos:"

if $ASTERISK_INSTALLED && ! systemctl is-active --quiet asterisk; then
    echo "  1. Iniciar Asterisk: sudo systemctl start asterisk"
fi

if $KAMAILIO_INSTALLED && ! systemctl is-active --quiet kamailio; then
    echo "  2. Iniciar Kamailio: sudo systemctl start kamailio"
fi

if $RTPPROXY_INSTALLED && ! systemctl is-active --quiet rtpproxy; then
    echo "  3. Iniciar RTPProxy: sudo systemctl start rtpproxy"
fi

if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "  4. Ver troubleshooting: docs/troubleshooting-voip.md"
    echo "  5. Ver logs: sudo journalctl -xe"
fi

echo ""
echo "Para más información:"
echo "  └─ https://github.com/nicsanchezr/NEW-CUY5132-DUOC"
echo ""

exit $EXIT_CODE
