#!/bin/bash
#
# Script de Instalación - Lab 2.3: Kamailio TLS
# Para DOCENTES - Demostración
# Curso: CUY5132 - Comunicaciones Unificadas
# Versión: 2.0
#
# Este script agrega TLS a Kamailio
# REQUIERE: Labs 2.1 y 2.2 previamente instalados
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
print_header "LAB 2.3: INSTALACIÓN TLS EN KAMAILIO"
echo ""
echo "Este script agrega TLS a Kamailio (Labs 2.1 + 2.2)."
echo ""
echo "Componentes:"
echo "  ✓ Módulo TLS de Kamailio"
echo "  ✓ Certificados autofirmados"
echo "  ✓ Transport TLS en puerto 5061"
echo ""
echo "⚠️  REQUISITO: Labs 2.1 y 2.2 instalados previamente"
echo ""
echo "Tiempo estimado: ~15 minutos"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Verificar requisitos
if ! command -v kamailio &>/dev/null; then
    print_error "Kamailio no está instalado"
    exit 1
fi

if ! systemctl is-active --quiet rtpproxy; then
    print_warning "RTPProxy no está corriendo (Lab 2.2)"
    echo "Se recomienda tener Lab 2.2 completo antes"
    read -p "¿Continuar de todas formas? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
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

print_header "Paso 1: Instalar módulos TLS"
apt install -y kamailio-tls-modules openssl >/dev/null 2>&1
print_success "Módulos TLS instalados"

systemctl stop kamailio

print_header "Paso 2: Generar certificados TLS"

# Crear directorio
mkdir -p /etc/kamailio/tls
cd /etc/kamailio/tls

# Generar certificado autofirmado
print_info "Generando certificado autofirmado..."
openssl req -new -x509 -nodes \
    -out kamailio-cert.pem \
    -keyout kamailio-key.pem \
    -days 365 \
    -subj "/C=CL/ST=Region/L=Ciudad/O=DUOC/OU=Lab/CN=$PUBLIC_IP" \
    2>/dev/null

chmod 600 kamailio-key.pem
chown kamailio:kamailio kamailio-*.pem

print_success "Certificados generados"
print_info "Cert: /etc/kamailio/tls/kamailio-cert.pem"
print_info "Key: /etc/kamailio/tls/kamailio-key.pem"

print_header "Paso 3: Configurar TLS"

# Crear tls.cfg
cat > /etc/kamailio/tls.cfg << 'EOFTLS'
[server:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
private_key = /etc/kamailio/tls/kamailio-key.pem
certificate = /etc/kamailio/tls/kamailio-cert.pem
ca_list = /etc/ssl/certs/ca-certificates.crt

[client:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
EOFTLS

print_success "Archivo tls.cfg creado"

print_header "Paso 4: Actualizar kamailio.cfg"

# Backup
BACKUP_FILE="/etc/kamailio/kamailio.cfg.pre-lab2.3"
cp /etc/kamailio/kamailio.cfg $BACKUP_FILE
print_success "Backup: $BACKUP_FILE"

# Obtener IP de Asterisk de config actual
ASTERISK_IP=$(grep "ASTERISK_IP" /etc/kamailio/kamailio.cfg | grep "define" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)

cat > /etc/kamailio/kamailio.cfg << 'EOFKAMAILIO'
#!KAMAILIO
#
# Configuración Kamailio SBC - Lab 2.3
# SBC con RTPProxy, NAT y TLS
#

####### Global Parameters #########

debug=2
log_stderror=no
memdbg=5
memlog=5
log_facility=LOG_LOCAL0
fork=yes
children=4

# TLS
enable_tls=yes

# IPs
listen=udp:PRIVATE_IP:5060
listen=tls:PRIVATE_IP:5061
advertise PUBLIC_IP:5060
advertise PUBLIC_IP:5061

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
loadmodule "tls.so"

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

# Module: usrloc
modparam("usrloc", "db_mode", 0)

# Module: nathelper
modparam("nathelper", "natping_interval", 30)
modparam("nathelper", "ping_nated_only", 1)
modparam("nathelper", "sipping_bflag", 7)
modparam("nathelper", "sipping_from", "sip:pinger@kamailio.local")

# Module: rtpproxy
modparam("rtpproxy", "rtpproxy_sock", "udp:127.0.0.1:7722")

# Module: tls
modparam("tls", "config", "/etc/kamailio/tls.cfg")
modparam("tls", "tls_log", 2)

####### Routing Logic ########

request_route {
    xlog("L_INFO", "[$rm] $fu -> $ru (from $si:$sp proto=$proto)\n");
    
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
        setflag(5);
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
        xlog("L_INFO", "REGISTER from $fu via $proto\n");
        
        if(isflagset(5)) {
            setbflag(6);
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
    
    if (is_request()) {
        if (!has_totag()) {
            if(t_is_branch_route()) {
                add_rr_param(";nat=yes");
            }
        }
    }
    
    if (is_reply()) {
        if(isbflagset(6)) {
            fix_nated_contact();
        }
    }
    
    if (is_method("INVITE|UPDATE")) {
        rtpproxy_manage("co");
    } else if (is_method("ACK") && has_body("application/sdp")) {
        rtpproxy_manage("co");
    } else if (is_method("BYE|CANCEL")) {
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

print_success "Configuración actualizada con TLS"

print_header "Paso 5: Verificar configuración"
if kamailio -c >/dev/null 2>&1; then
    print_success "Configuración válida"
else
    print_error "Error en configuración"
    kamailio -c
    exit 1
fi

print_header "Paso 6: Reiniciar Kamailio"
systemctl start kamailio
sleep 3

if systemctl is-active --quiet kamailio; then
    print_success "Kamailio reiniciado correctamente"
else
    print_error "Kamailio no inició"
    print_info "Ver logs: sudo journalctl -u kamailio -n 50"
    exit 1
fi

# Verificar puerto TLS
sleep 2
if netstat -tulpn 2>/dev/null | grep -q ":5061.*kamailio"; then
    print_success "Puerto 5061 (TLS) escuchando"
else
    print_warning "Puerto 5061 no visible (verificar manualmente)"
fi

print_header "LAB 2.3 KAMAILIO TLS INSTALADO"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         KAMAILIO TLS CONFIGURADO                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Configuración:"
echo "  ├─ IP Privada: $PRIVATE_IP"
echo "  ├─ IP Pública: $PUBLIC_IP"
echo "  └─ Asterisk: $ASTERISK_IP"
echo ""
echo "🎛️  Componentes agregados Lab 2.3:"
echo "  ✓ Módulo TLS cargado"
echo "  ✓ Certificado autofirmado generado"
echo "  ✓ Transport TLS en puerto 5061"
echo "  ✓ Soporte TLS 1.2+"
echo ""
echo "🔌 Puertos agregados:"
echo "  └─ 5061 TCP (TLS/SIPS)"
echo ""
echo "🔐 Certificados:"
echo "  ├─ Cert: /etc/kamailio/tls/kamailio-cert.pem"
echo "  ├─ Key: /etc/kamailio/tls/kamailio-key.pem"
echo "  └─ Config: /etc/kamailio/tls.cfg"
echo ""
echo "⚠️  Security Groups AWS - ACTUALIZAR:"
echo "  En SG-Kamailio:"
echo "    └─ Agregar: 5061 TCP → 0.0.0.0/0"
echo ""
echo "🧪 Verificación TLS:"
echo "  1. Probar conexión TLS:"
echo "     openssl s_client -connect $PUBLIC_IP:5061 -showcerts"
echo ""
echo "  2. Ver puertos:"
echo "     netstat -tulpn | grep -E '5060|5061'"
echo ""
echo "  3. Configurar softphone con TLS:"
echo "     - Server: $PUBLIC_IP"
echo "     - Port: 5061"
echo "     - Transport: TLS"
echo "     - Desactivar verificación certificado"
echo ""
echo "  4. Ver logs durante registro:"
echo "     tail -f /var/log/syslog | grep -E 'kamailio|tls'"
echo ""
echo "📖 Siguiente paso - Configurar Asterisk:"
echo "  En la instancia de Asterisk ejecutar:"
echo "  └─ ./configure-asterisk-tls-srtp.sh"
echo ""
echo "💾 Backup de configuración anterior:"
echo "  └─ $BACKUP_FILE"
echo ""

print_success "¡Lab 2.3 Kamailio completado!"
print_warning "Recuerda configurar también Asterisk con TLS/SRTP"
