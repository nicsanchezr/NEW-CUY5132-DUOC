#!/bin/bash
#
# Script de Instalación - Lab 2.2: NAT + RTPProxy
# Para DOCENTES - Demostración
# Curso: CUY5132 - Comunicaciones Unificadas
# Versión: 2.0
#
# Este script agrega RTPProxy y configuración NAT
# REQUIERE: Lab 2.1 previamente instalado
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
print_header "LAB 2.2: INSTALACIÓN NAT + RTPPROXY"
echo ""
echo "Este script agrega RTPProxy y configuración NAT al Lab 2.1."
echo ""
echo "Componentes:"
echo "  ✓ RTPProxy (relay de medios)"
echo "  ✓ Configuración NAT en Kamailio"
echo "  ✓ Módulos nathelper + rtpproxy"
echo ""
echo "⚠️  REQUISITO: Lab 2.1 debe estar instalado previamente"
echo ""
echo "Tiempo estimado: ~10 minutos"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Verificar que Kamailio esté instalado
if ! command -v kamailio &>/dev/null; then
    print_error "Kamailio no está instalado"
    echo "Primero ejecuta: ./install-kamailio-sbc-quick.sh"
    exit 1
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

print_header "Paso 1: Instalar RTPProxy"
apt install -y rtpproxy >/dev/null 2>&1
print_success "RTPProxy instalado"

systemctl stop rtpproxy 2>/dev/null || true

print_header "Paso 2: Configurar RTPProxy"

cat > /etc/default/rtpproxy << EOF
USER=rtpproxy
GROUP=rtpproxy
EXTRA_OPTS="-l $PRIVATE_IP/$PUBLIC_IP -s udp:127.0.0.1:7722 -m 10000 -M 20000 -d INFO"
EOF

print_success "RTPProxy configurado"

systemctl enable rtpproxy >/dev/null 2>&1
systemctl start rtpproxy
sleep 2

if systemctl is-active --quiet rtpproxy; then
    print_success "RTPProxy iniciado"
else
    print_error "RTPProxy no inició"
    exit 1
fi

print_header "Paso 3: Actualizar configuración Kamailio"

systemctl stop kamailio

# Backup
BACKUP_FILE="/etc/kamailio/kamailio.cfg.pre-lab2.2"
cp /etc/kamailio/kamailio.cfg $BACKUP_FILE
print_success "Backup: $BACKUP_FILE"

# Obtener IP de Asterisk de la config actual
ASTERISK_IP=$(grep "ASTERISK_IP" /etc/kamailio/kamailio.cfg | grep "define" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)

cat > /etc/kamailio/kamailio.cfg << 'EOFKAMAILIO'
#!KAMAILIO
#
# Configuración Kamailio SBC - Lab 2.2
# SBC con RTPProxy y NAT Traversal
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
loadmodule "nathelper.so"
loadmodule "rtpproxy.so"

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

# Module: nathelper
modparam("nathelper", "natping_interval", 30)
modparam("nathelper", "ping_nated_only", 1)
modparam("nathelper", "sipping_bflag", 7)
modparam("nathelper", "sipping_from", "sip:pinger@kamailio.local")

# Module: rtpproxy
modparam("rtpproxy", "rtpproxy_sock", "udp:127.0.0.1:7722")

####### Routing Logic ########

request_route {
    xlog("L_INFO", "[$rm] $fu -> $ru (from $si:$sp)\n");
    
    route(REQINIT);
    route(NATDETECT);
    route(WITHINDLG);
    route(REGISTRAR);
    route(RELAY);
}

route[REQINIT] {
    if (!mf_process_maxfwd_header("10")) {
        sl_send_reply("483","Too Many Hops");
        exit;
    }
    
    if(!sanity_check("1511", "7")) {
        xlog("L_WARN", "Malformed SIP message from $si:$sp\n");
        exit;
    }
}

route[NATDETECT] {
    force_rport();
    if (nat_uac_test("19")) {
        xlog("L_INFO", "NAT detected from $si:$sp\n");
        if (is_method("REGISTER")) {
            fix_nated_register();
        } else {
            fix_nated_contact();
        }
        setflag(5); # FLT_NATS
    }
}

route[WITHINDLG] {
    if (has_totag()) {
        if (loose_route()) {
            route(NATMANAGE);
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
        
        if(isflagset(5)) {
            setbflag(6);
            xlog("L_INFO", "Setting branch flag for NAT\n");
        }
        
        if (!save("location")) {
            sl_reply_error();
        }
        exit;
    }
}

route[RELAY] {
    if (!is_method("REGISTER")) {
        record_route();
    }
    
    route(NATMANAGE);
    
    if (!is_method("REGISTER")) {
        xlog("L_INFO", "Forwarding to Asterisk: $ASTERISK_IP\n");
        $du = "sip:" + $ASTERISK_IP + ":5060";
    }
    
    if (!t_relay()) {
        sl_reply_error();
    }
}

route[NATMANAGE] {
    if (is_request()) {
        if(has_totag()) {
            if(check_route_param("nat=yes")) {
                setbflag(6);
            }
        }
    }
    
    if (!(isflagset(5) || isbflagset(6)))
        return;
    
    xlog("L_INFO", "NATMANAGE: Applying NAT handling\n");
    
    if (is_request()) {
        if (!has_totag()) {
            if(t_is_branch_route()) {
                add_rr_param(";nat=yes");
            }
        }
    }
    
    if (is_reply()) {
        if(isbflagset(6)) {
            xlog("L_INFO", "Fixing NATed contact in reply\n");
            fix_nated_contact();
        }
    }
    
    if (is_method("INVITE|UPDATE")) {
        xlog("L_INFO", "RTPProxy: Managing RTP for INVITE/UPDATE\n");
        rtpproxy_manage("co");
    } else if (is_method("ACK") && has_body("application/sdp")) {
        xlog("L_INFO", "RTPProxy: Managing RTP for ACK\n");
        rtpproxy_manage("co");
    } else if (is_method("BYE|CANCEL")) {
        xlog("L_INFO", "RTPProxy: Destroying session\n");
        rtpproxy_destroy();
    }
}

failure_route[MANAGE_FAILURE] {
    route(NATMANAGE);
    if (t_is_canceled()) {
        exit;
    }
}

EOFKAMAILIO

# Reemplazar variables
sed -i "s/PRIVATE_IP/$PRIVATE_IP/g" /etc/kamailio/kamailio.cfg
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" /etc/kamailio/kamailio.cfg
sed -i "s/ASTERISK_IP/$ASTERISK_IP/g" /etc/kamailio/kamailio.cfg

print_success "Configuración actualizada"

print_header "Paso 4: Verificar configuración"
if kamailio -c >/dev/null 2>&1; then
    print_success "Configuración válida"
else
    print_error "Error en configuración"
    kamailio -c
    exit 1
fi

print_header "Paso 5: Reiniciar Kamailio"
systemctl start kamailio
sleep 3

if systemctl is-active --quiet kamailio; then
    print_success "Kamailio reiniciado correctamente"
else
    print_error "Kamailio no inició"
    print_info "Ver logs: sudo journalctl -u kamailio -n 50"
    exit 1
fi

print_header "LAB 2.2 INSTALADO EXITOSAMENTE"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         NAT + RTPPROXY CONFIGURADO                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Configuración:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  ├─ IP Pública: $PUBLIC_IP"
echo "  └─ Asterisk: $ASTERISK_IP"
echo ""
echo "🎛️  Componentes agregados Lab 2.2:"
echo "  ✓ RTPProxy (relay de medios)"
echo "  ✓ NAT detection (nat_uac_test)"
echo "  ✓ Fix Contact headers (fix_nated_contact)"
echo "  ✓ RTP relay automático"
echo "  ✓ Keepalive para clientes NAT"
echo ""
echo "🔌 Puertos agregados:"
echo "  ├─ 7722 UDP (RTPProxy control)"
echo "  └─ 10000-20000 UDP (RTP/medios)"
echo ""
echo "⚠️  Security Groups AWS - ACTUALIZAR:"
echo "  En SG-Kamailio:"
echo "    └─ Agregar: 10000-20000 UDP → 0.0.0.0/0"
echo ""
echo "  En SG-Asterisk:"
echo "    ⚠️  CAMBIAR de público a privado:"
echo "    ├─ Eliminar: 5060 UDP → 0.0.0.0/0"
echo "    ├─ Agregar: 5060 UDP → sg-kamailio"
echo "    ├─ Eliminar: 10000-20000 UDP → 0.0.0.0/0"
echo "    └─ Agregar: 10000-20000 UDP → sg-kamailio"
echo ""
echo "🧪 Próximos pasos:"
echo "  1. Verificar servicios:"
echo "     systemctl status kamailio rtpproxy"
echo ""
echo "  2. Ver logs combinados:"
echo "     tail -f /var/log/syslog | grep -E 'kamailio|rtpproxy'"
echo ""
echo "  3. Actualizar Security Groups en AWS Console"
echo ""
echo "  4. Probar con cliente NAT:"
echo "     - Debe detectar NAT automáticamente"
echo "     - Audio debe funcionar en ambas direcciones"
echo ""
echo "  5. Monitorear durante llamada:"
echo "     netstat -tunap | grep rtpproxy"
echo ""
echo "📖 Para continuar con Lab 2.3:"
echo "  └─ Ejecutar: ./install-tls-srtp-quick.sh"
echo ""
echo "💾 Backup de configuración anterior:"
echo "  └─ $BACKUP_FILE"
echo ""

print_success "¡Lab 2.2 completado!"
