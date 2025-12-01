#!/bin/bash
#
# Script de Instalación - Lab 2.1: Kamailio SBC Básico
# Para DOCENTES - Demostración
# Curso: CUY5132 - Comunicaciones Unificadas
# Versión: 2.0
#
# Este script instala Kamailio como SBC básico
# Lab 2.1 únicamente (sin RTPProxy, sin TLS)
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
print_header "LAB 2.1: INSTALACIÓN KAMAILIO SBC BÁSICO"
echo ""
echo "Este script instala Kamailio como Session Border Controller básico."
echo ""
echo "Componentes:"
echo "  ✓ Kamailio SBC"
echo "  ✓ Configuración básica de routing"
echo "  ✗ Sin RTPProxy (Lab 2.2)"
echo "  ✗ Sin TLS/SRTP (Lab 2.3)"
echo ""
echo "Tiempo estimado: ~10 minutos"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Obtener IPs
print_info "Detectando IPs..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me || echo "ERROR")

if [ "$PUBLIC_IP" == "ERROR" ]; then
    print_error "No se pudo obtener IP pública"
    exit 1
fi

echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  └─ IP Pública: $PUBLIC_IP"
echo ""

# Solicitar IP de Asterisk
echo "Configuración de Backend:"
read -p "IP PRIVADA de Asterisk (ej: 10.0.2.10): " ASTERISK_IP
if [ -z "$ASTERISK_IP" ]; then
    print_error "Debes ingresar la IP de Asterisk"
    exit 1
fi

echo ""
print_info "Configuración:"
echo "  ├─ Kamailio: $PRIVATE_IP (privada) / $PUBLIC_IP (pública)"
echo "  └─ Asterisk: $ASTERISK_IP"
echo ""

print_header "Paso 1: Actualizar sistema"
apt update -y >/dev/null 2>&1
print_success "Sistema actualizado"

print_header "Paso 2: Instalar Kamailio"
apt install -y kamailio kamailio-extra-modules >/dev/null 2>&1
print_success "Kamailio instalado"

KAMAILIO_VERSION=$(kamailio -v 2>&1 | head -1)
print_info "Versión: $KAMAILIO_VERSION"

systemctl stop kamailio 2>/dev/null || true

print_header "Paso 3: Configurar Kamailio"

# Backup
BACKUP_DIR="/etc/kamailio/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR
cp /etc/kamailio/kamailio.cfg $BACKUP_DIR/ 2>/dev/null || true
print_success "Backup creado"

cat > /etc/kamailio/kamailio.cfg << 'EOFKAMAILIO'
#!KAMAILIO
#
# Configuración Kamailio SBC - Lab 2.1
# SBC Básico sin RTPProxy ni TLS
#

####### Global Parameters #########

debug=2
log_stderror=no
memdbg=5
memlog=5
log_facility=LOG_LOCAL0
fork=yes
children=4

# IPs
listen=udp:PRIVATE_IP:5060
advertise PUBLIC_IP:5060

#!define ASTERISK_IP "ASTERISK_IP"

####### Modules Section ########

loadmodule "tm.so"
loadmodule "sl.so"
loadmodule "rr.so"
loadmodule "pv.so"
loadmodule "maxfwd.so"
loadmodule "usrloc.so"
loadmodule "registrar.so"
loadmodule "textops.so"
loadmodule "siputils.so"
loadmodule "xlog.so"
loadmodule "sanity.so"

####### Module Parameters ########

# Module: tm
modparam("tm", "failure_route", "MANAGE_FAILURE")
modparam("tm", "append_branches", 1)

# Module: rr
modparam("rr", "enable_full_lr", 1)
modparam("rr", "append_fromtag", 1)

# Module: registrar
modparam("registrar", "method_filtering", 1)
modparam("registrar", "max_expires", 3600)
modparam("registrar", "gruu_enabled", 0)

# Module: usrloc
modparam("usrloc", "db_mode", 0)

####### Routing Logic ########

request_route {
    # Log request
    xlog("L_INFO", "[$rm] $fu -> $ru (from $si:$sp)\n");
    
    # Per request initial checks
    route(REQINIT);
    
    # Handle requests within SIP dialogs
    route(WITHINDLG);
    
    # Handle registrations
    route(REGISTRAR);
    
    # Route to Asterisk
    route(RELAY);
}

route[REQINIT] {
    # Max-Forwards check
    if (!mf_process_maxfwd_header("10")) {
        sl_send_reply("483","Too Many Hops");
        exit;
    }
    
    # Sanity checks
    if(!sanity_check("1511", "7")) {
        xlog("L_WARN", "Malformed SIP message from $si:$sp\n");
        exit;
    }
}

route[WITHINDLG] {
    # Handle in-dialog requests
    if (has_totag()) {
        if (loose_route()) {
            route(RELAY);
        } else {
            if (is_method("ACK")) {
                if (t_check_trans()) {
                    route(RELAY);
                    exit;
                } else {
                    exit;
                }
            }
            sl_send_reply("404","Not here");
        }
        exit;
    }
}

route[REGISTRAR] {
    if (is_method("REGISTER")) {
        xlog("L_INFO", "REGISTER from $fu (Contact: $ct)\n");
        
        if (!save("location")) {
            sl_reply_error();
        }
        exit;
    }
}

route[RELAY] {
    # Record-Route for dialog-forming requests
    if (!is_method("REGISTER")) {
        record_route();
    }
    
    # Forward to Asterisk
    if (!is_method("REGISTER")) {
        xlog("L_INFO", "Forwarding to Asterisk: $ASTERISK_IP\n");
        $du = "sip:" + $ASTERISK_IP + ":5060";
    }
    
    # Send the request
    if (!t_relay()) {
        sl_reply_error();
    }
}

failure_route[MANAGE_FAILURE] {
    xlog("L_INFO", "Failure route: $rs $rr\n");
}

EOFKAMAILIO

# Reemplazar variables
sed -i "s/PRIVATE_IP/$PRIVATE_IP/g" /etc/kamailio/kamailio.cfg
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" /etc/kamailio/kamailio.cfg
sed -i "s/ASTERISK_IP/$ASTERISK_IP/g" /etc/kamailio/kamailio.cfg

print_success "Configuración creada"

print_header "Paso 4: Verificar configuración"
if kamailio -c >/dev/null 2>&1; then
    print_success "Configuración válida"
else
    print_error "Error en configuración"
    kamailio -c
    exit 1
fi

print_header "Paso 5: Habilitar e iniciar Kamailio"
systemctl enable kamailio >/dev/null 2>&1
systemctl start kamailio
sleep 3

if systemctl is-active --quiet kamailio; then
    print_success "Kamailio iniciado correctamente"
else
    print_error "Kamailio no inició"
    print_info "Ver logs: sudo journalctl -u kamailio -n 50"
    exit 1
fi

print_header "LAB 2.1 INSTALADO EXITOSAMENTE"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         KAMAILIO SBC BÁSICO INSTALADO                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Configuración:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  ├─ IP Pública: $PUBLIC_IP"
echo "  └─ Backend Asterisk: $ASTERISK_IP"
echo ""
echo "🎛️  Componentes Lab 2.1:"
echo "  ✓ Kamailio SBC"
echo "  ✓ Routing SIP básico"
echo "  ✓ Record-Route"
echo "  ✓ Location service (REGISTER)"
echo ""
echo "🔌 Puertos:"
echo "  └─ 5060 UDP (SIP)"
echo ""
echo "⚠️  Security Groups AWS:"
echo "  En SG-Kamailio:"
echo "    ├─ 22 TCP → Tu-IP"
echo "    └─ 5060 UDP → 0.0.0.0/0"
echo ""
echo "  En SG-Asterisk:"
echo "    ├─ 22 TCP → Tu-IP"
echo "    ├─ 5060 UDP → 0.0.0.0/0 (Lab 2.1 - temporal)"
echo "    └─ 10000-20000 UDP → 0.0.0.0/0 (Lab 2.1 - temporal)"
echo ""
echo "    ⚠️ En Lab 2.2 cambiar Asterisk a privado:"
echo "       5060 UDP → sg-kamailio"
echo "       10000-20000 UDP → sg-kamailio"
echo ""
echo "🧪 Próximos pasos:"
echo "  1. Verificar: sudo systemctl status kamailio"
echo "  2. Ver logs: sudo tail -f /var/log/syslog | grep kamailio"
echo "  3. Configurar softphone:"
echo "     - Server: $PUBLIC_IP"
echo "     - Port: 5060"
echo "     - Transport: UDP"
echo "  4. Probar registro"
echo "  5. Realizar llamada de prueba"
echo ""
echo "📖 Para continuar con Lab 2.2:"
echo "  └─ Ejecutar: ./install-nat-rtpproxy-quick.sh"
echo ""

print_success "¡Lab 2.1 completado!"
