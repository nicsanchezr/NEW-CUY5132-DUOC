# Troubleshooting VoIP
## Diagnóstico de Problemas en Laboratorios Kamailio/Asterisk

Guía completa de solución de problemas comunes en laboratorios de VoIP.

---

## 📱 Softphones Recomendados

**IMPORTANTE:** Usa estos softphones para mejores resultados en los laboratorios.

### Linphone ⭐ (RECOMENDADO)

**Características:**
- ✅ Multiplataforma (Windows, Mac, Linux, Android, iOS)
- ✅ Open Source (GPLv3)
- ✅ Excelente soporte TLS/SRTP
- ✅ Interfaz amigable
- ✅ Indicador visual de llamada segura 🔒

**Descarga:** https://www.linphone.org/

### MicroSIP ⭐ (Alternativa Windows)

**Características:**
- ✅ Solo Windows
- ✅ Muy ligero (~3 MB)
- ✅ Portable (no requiere instalación)
- ✅ Buen soporte TLS/SRTP
- ✅ Configuración simple

**Descarga:** https://www.microsip.org/

### ❌ NO Recomendado: Zoiper

- Requiere versión PRO (pago) para TLS/SRTP
- No funciona para Lab 2.3

---

## 📞 Problemas de Registro

### Softphone no registra

**Síntoma:** "Registration Failed" o "Timeout"

**Diagnóstico paso a paso:**

```bash
# 1. Verificar que Kamailio está corriendo
sudo systemctl status kamailio

# 2. Verificar que escucha en puerto 5060
sudo netstat -tulpn | grep 5060

# 3. Capturar tráfico SIP
sudo tcpdump -i any -n port 5060 -A

# 4. Intentar registrar y ver qué llega
```

**Causas comunes:**

| Causa | Solución |
|-------|----------|
| Security Group bloqueando | Agregar regla 5060 UDP en SG-Kamailio |
| IP incorrecta en softphone | Usar IP pública de Kamailio (curl ifconfig.me) |
| Kamailio no corriendo | `sudo systemctl start kamailio` |
| Kamailio no reenvía a Asterisk | Verificar `$du` en kamailio.cfg |
| Asterisk no corriendo | `sudo systemctl start asterisk` |
| Puerto incorrecto | Lab 2.1-2.2: 5060, Lab 2.3+: 5061 TLS |

### Registro exitoso pero llamadas fallan

**Verificar flujo completo:**

```bash
# En Kamailio - ver logs
sudo tail -f /var/log/syslog | grep kamailio

# En Asterisk - ver CLI
sudo asterisk -rvvv
# Ver si llegan REGISTERs e INVITEs
```

**Problema común:** Record-Route no configurado

```python
# En kamailio.cfg debe haber:
if (method!="REGISTER") {
    record_route();
}
```

---

## 🔇 Problemas de Audio

### Llamada conecta pero NO hay audio

**Este es EL problema más común en VoIP**

**Diagnóstico:**

```bash
# 1. Verificar que RTPProxy está corriendo (si Lab 2.2+)
sudo systemctl status rtpproxy

# 2. Verificar puertos RTP abiertos
sudo netstat -tulpn | grep -E '10000|20000'

# 3. Capturar tráfico RTP
sudo tcpdump -i any -n 'portrange 10000-20000' -c 100
```

**Causas por laboratorio:**

**Lab 2.1 (sin RTPProxy):**
- Security Group debe permitir 10000-20000 UDP en SG-Kamailio Y SG-Asterisk
- Clientes deben poder alcanzar directamente IP de Asterisk
- Audio fluye directo Cliente ←→ Asterisk

**Lab 2.2+ (con RTPProxy):**
- RTPProxy no corriendo → `sudo systemctl start rtpproxy`
- RTPProxy mal configurado → Verificar `-l PUBLIC_IP/PRIVATE_IP`
- rtpproxy_offer() o rtpproxy_answer() faltante en config
- Audio fluye Cliente ←→ RTPProxy ←→ Asterisk

**Verificación con tcpdump:**

```bash
# Si ves paquetes UDP en 10000-20000 = RTP está fluyendo ✓
# Si NO ves paquetes = problema de configuración ✗
```

### Audio solo en una dirección

**Síntoma:** Escucho pero no me escuchan (o viceversa)

**Causa:** RTPProxy no está haciendo relay bidireccional

**Solución:**

```bash
# Verificar configuración RTPProxy
cat /etc/default/rtpproxy

# Debe tener AMBAS IPs:
EXTRA_OPTS="-l PUBLIC_IP/PRIVATE_IP -m 10000 -M 20000"

# Reiniciar
sudo systemctl restart rtpproxy
```

**Verificar en kamailio.cfg:**

```python
# Debe tener ambas funciones:
route[NATMANAGE] {
    ...
    if (is_method("INVITE|UPDATE")) {
        rtpproxy_manage("co");  # ← CRÍTICO
    }
    ...
}
```

### Audio entrecortado o con eco

**Causas:**
- Latencia de red alta
- Codecs incompatibles
- Problemas de ancho de banda
- RTPProxy sobrecargado

**Verificar codecs:**

```bash
# En Asterisk
asterisk -rx "pjsip show endpoint 1001"

# Debe mostrar codecs: ulaw, alaw
```

**Optimizar:**

```ini
# En /etc/asterisk/pjsip.conf
[endpoint_template](!)
allow=!all,ulaw,alaw
```

---

## 🔐 Problemas de TLS/SRTP (Lab 2.3)

### Softphone no registra con TLS

**Verificar configuración TLS:**

```bash
# 1. Puerto 5061 abierto en Security Group
EC2 → Security Groups → SG-Kamailio → Inbound Rules
   → Debe tener: Custom TCP 5061 0.0.0.0/0

# 2. Puerto 5061 escuchando
sudo netstat -tulpn | grep 5061

# 3. Certificado existe
ls -l /etc/kamailio/tls/

# 4. Kamailio cargó módulo TLS
sudo kamailio -c 2>&1 | grep tls

# 5. Test conexión TLS
openssl s_client -connect IP_PUBLICA:5061 -showcerts
```

**Problemas comunes:**

| Problema | Solución |
|----------|----------|
| Puerto 5061 no escucha | Verificar `listen=tls:IP_PRIVADA:5061` en kamailio.cfg |
| Certificado no válido | Regenerar con CN=IP_PUBLICA |
| Softphone rechaza cert | Desactivar verificación de certificado |
| Module not loaded | loadmodule "tls.so" en kamailio.cfg |
| Transport incorrecto en softphone | Seleccionar TLS, NO UDP |

**Configuración Linphone para TLS:**
```
Account Settings → Advanced:
- Transport: TLS
- Server Port: 5061
Media encryption: SRTP → Mandatory
```

**Configuración MicroSIP para TLS:**
```
Account → Network:
- Transport: TLS
Advanced → Security:
- Use encryption: Always
- SRTP Mode: Mandatory
```

### SRTP no funciona

**Verificar:**

```bash
# En Asterisk
asterisk -rx "pjsip show endpoint 1001"

# Debe mostrar:
#  media_encryption : sdes
```

**Configuración correcta en pjsip.conf:**

```ini
[1001]
type=endpoint
media_encryption=sdes
media_encryption_optimistic=no  # ← IMPORTANTE
```

### Wireshark muestra SIP en texto plano

**Causa:** Cliente usando UDP 5060 en lugar de TLS 5061

**Verificar configuración softphone:**
```
Transport: TLS (NO UDP)
Puerto: 5061 (NO 5060)
```

**Qué debe mostrar Wireshark:**
```
✓ TLS Handshake (Client Hello, Server Hello, Certificate)
✓ Application Data (SIP cifrado, NO legible)
✓ SDP con líneas "a=crypto:..." visible en handshake
✗ NO debe verse SIP/2.0 en texto plano
```

---

## 🛠️ Problemas de Configuración

### Kamailio no inicia

**Ver error específico:**

```bash
# Logs detallados
sudo journalctl -u kamailio -n 50

# Verificar sintaxis
sudo kamailio -c

# Ver en qué línea falla
sudo kamailio -c -f /etc/kamailio/kamailio.cfg
```

**Errores comunes:**

| Error | Causa | Solución |
|-------|-------|----------|
| "bind: Cannot assign requested address" | IP incorrecta en `listen` | Usar IP privada de la instancia |
| "bad command" | Sintaxis incorrecta | Revisar línea indicada |
| "module not found" | Módulo no instalado | `apt install kamailio-extra-modules` |
| "cannot open file" | Ruta incorrecta | Verificar paths de certificados |

### Asterisk no inicia

```bash
# Ver error
sudo journalctl -u asterisk -n 50

# Probar en foreground
sudo asterisk -cvvv

# Ver errores de configuración
sudo asterisk -rx "core show config"
```

### Cambios en configuración no aplican

**Solución:**

```bash
# Kamailio - reiniciar completamente
sudo systemctl restart kamailio

# Asterisk - recargar módulo específico
asterisk -rx "pjsip reload"

# O reiniciar Asterisk
sudo systemctl restart asterisk

# RTPProxy - reiniciar
sudo systemctl restart rtpproxy
```

---

## 📊 Problemas de Monitoreo (Lab 2.4)

### sngrep no muestra llamadas

**Causas comunes:**

**1. sngrep no instalado:**
```bash
sudo apt install sngrep -y
```

**2. Interfaz incorrecta:**
```bash
# Ver interfaces disponibles
ip addr show

# Capturar en todas las interfaces
sudo sngrep -d any

# O interfaz específica
sudo sngrep -d eth0
```

**3. Puerto incorrecto:**
```bash
# Especificar puerto SIP
sudo sngrep port 5060

# O para TLS
sudo sngrep port 5061
```

**4. Falta de permisos:**
```bash
# Ejecutar con sudo
sudo sngrep

# O dar permisos al usuario
sudo setcap cap_net_raw+eip /usr/bin/sngrep
```

### sngrep muestra "Encrypted: Yes" pero no puedo ver contenido

**Esto es NORMAL con TLS:**

- sngrep NO puede descifrar TLS
- Solo muestra metadata (IPs, puertos, timestamps)
- Para ver contenido SIP cifrado, necesitas las llaves privadas

**Usar Wireshark para análisis profundo:**
```bash
# Capturar con tcpdump
sudo tcpdump -i any -n port 5061 -w tls-capture.pcap

# Analizar en Wireshark (en tu PC)
```

### sngrep teclas no funcionan

**Teclas principales:**

| Tecla | Función |
|-------|---------|
| ↑↓ | Navegar llamadas |
| Enter | Ver detalles de llamada seleccionada |
| F2 | Guardar captura PCAP |
| F7 | Ver diagrama de flujo |
| F10 | Menú de configuración |
| Q | Salir |
| / | Buscar/Filtrar |

**Problemas comunes:**
- En PuTTY: Habilitar "Application keypad mode"
- En algunos terminales: Usar Esc + tecla en lugar de F-key

---

## 🛡️ Problemas de fail2ban (Lab 2.4)

### fail2ban no está baneando atacantes

**Diagnóstico:**

```bash
# 1. Verificar que fail2ban está corriendo
sudo systemctl status fail2ban

# 2. Ver jails activos
sudo fail2ban-client status

# 3. Ver estado de jail kamailio
sudo fail2ban-client status kamailio-auth

# 4. Ver logs de fail2ban
sudo tail -f /var/log/fail2ban.log
```

**Causas comunes:**

**1. Jail no habilitado:**
```bash
# Verificar /etc/fail2ban/jail.local
[kamailio-auth]
enabled = true  # ← Debe estar en true
```

**2. Filtro no coincide:**
```bash
# Probar regex del filtro manualmente
sudo fail2ban-regex /var/log/syslog /etc/fail2ban/filter.d/kamailio-auth.conf

# Debe mostrar: "Lines: X lines, X ignored, X matched"
```

**3. Tiempo de ban muy corto:**
```bash
# En /etc/fail2ban/jail.local
[kamailio-auth]
bantime = 3600      # 1 hora (no 60 segundos)
findtime = 600      # 10 minutos
maxretry = 3
```

**4. Log file incorrecto:**
```bash
# Verificar que Kamailio loguea donde fail2ban busca
[kamailio-auth]
logpath = /var/log/syslog  # ← Debe coincidir con logs de Kamailio
```

### fail2ban baneó mi propia IP

**Síntoma:** No puedes conectarte por SSH o SIP

**Solución:**

```bash
# Ver IPs baneadas
sudo fail2ban-client status kamailio-auth

# Desbanear tu IP
sudo fail2ban-client set kamailio-auth unbanip TU_IP

# Agregar tu IP a whitelist
# Editar /etc/fail2ban/jail.local:
[DEFAULT]
ignoreip = 127.0.0.1/8 TU_IP_PUBLICA
```

### fail2ban no reinicia después de cambios

**Solución:**

```bash
# Reiniciar fail2ban
sudo systemctl restart fail2ban

# Ver errores si no inicia
sudo journalctl -u fail2ban -n 50

# Verificar configuración
sudo fail2ban-client -d  # modo debug
```

### Ver qué IPs están actualmente baneadas

```bash
# Método 1: fail2ban
sudo fail2ban-client status kamailio-auth

# Método 2: iptables directamente
sudo iptables -L -n | grep f2b-kamailio

# Método 3: Ver todas las cadenas fail2ban
sudo iptables -L f2b-kamailio-auth -n -v
```

---

## 🔍 Herramientas de Diagnóstico

### tcpdump - Captura de Tráfico

```bash
# Capturar SIP en tiempo real
sudo tcpdump -i any -n port 5060 -A

# Guardar a archivo
sudo tcpdump -i any -n port 5060 -w captura.pcap

# Capturar SIP y RTP
sudo tcpdump -i any -n 'port 5060 or portrange 10000-20000' -w completo.pcap

# Capturar solo TLS (Lab 2.3)
sudo tcpdump -i any -n port 5061 -w tls-capture.pcap

# Ver solo headers
sudo tcpdump -i any -n port 5060 -v
```

### Wireshark - Análisis

```bash
# En tu PC, después de descargar .pcap

# Filtros útiles:
sip                          # Solo SIP
rtp                          # Solo RTP
srtp                         # Solo SRTP
sip.Method == "INVITE"       # Solo INVITEs
sip.Status-Code == 200       # Solo 200 OK
sip.Status-Code == 401       # Fallos autenticación
tls.handshake                # Handshake TLS
tls.app_data                 # Application Data cifrada
```

**Analizar llamada:**
1. Telephony → VoIP Calls
2. Seleccionar llamada
3. Flow Sequence

**Verificar cifrado TLS:**
1. Filtro: `tls.handshake`
2. Buscar: Client Hello, Server Hello, Certificate
3. Filtro: `tls.app_data` → SIP debe estar cifrado

**Verificar SRTP:**
1. Buscar en SDP: `a=crypto:`
2. RTP packets deben aparecer como "Encrypted" o no decodificables

### sngrep - Monitor SIP en Tiempo Real

```bash
# Instalar
sudo apt install sngrep -y

# Ejecutar (modo básico)
sudo sngrep

# Especificar interfaz
sudo sngrep -d any

# Especificar puerto
sudo sngrep port 5060

# Guardar al iniciar
sudo sngrep -O /tmp/capture.pcap

# Modo extendido (más columnas)
sudo sngrep -c /etc/sngrep/sngrep.conf
```

**Funciones en interfaz:**
```
↑↓          - Navegar llamadas
Enter       - Ver detalles de llamada
F2          - Guardar PCAP
F7          - Ver flow diagram (diagrama de flujo)
F10         - Configuración
/           - Filtro
Q           - Salir
Espacio     - Extender/colapsar vista
```

**Filtros útiles en sngrep:**
```
host 192.168.1.100    # Solo de/hacia esta IP
method INVITE         # Solo INVITEs
to 1001               # Llamadas a extensión 1001
callid ABC123         # Call-ID específico
```

### Logs en Tiempo Real

```bash
# Kamailio
sudo tail -f /var/log/syslog | grep kamailio

# Asterisk
sudo tail -f /var/log/asterisk/messages

# RTPProxy
sudo tail -f /var/log/syslog | grep rtpproxy

# fail2ban
sudo tail -f /var/log/fail2ban.log

# Ver todo junto
sudo tail -f /var/log/syslog | grep -E 'kamailio|asterisk|rtpproxy|fail2ban'
```

### Comandos de Verificación Rápida

```bash
# Ver todos los servicios VoIP
sudo systemctl status kamailio asterisk rtpproxy fail2ban

# Ver todos los puertos VoIP
sudo netstat -tulpn | grep -E '5060|5061|7722'

# Ver procesos
ps aux | grep -E 'kamailio|asterisk|rtpproxy|fail2ban'

# Ver uso de CPU/RAM
htop
# Buscar: kamailio, asterisk, rtpproxy
```

---

## 📊 Checklist de Verificación por Lab

### Lab 2.1: SBC Básico

```
☐ Kamailio corriendo
☐ Asterisk corriendo
☐ Puerto 5060 abierto en SG-Kamailio
☐ Puerto 5060 abierto en SG-Asterisk (temporal)
☐ Puertos 10000-20000 abiertos en ambos
☐ IP de Asterisk correcta en kamailio.cfg
☐ Softphone registra (Linphone o MicroSIP)
☐ Llamada funciona
☐ Hay audio bidireccional
```

### Lab 2.2: NAT + RTPProxy

```
☐ Todo de Lab 2.1 ✓
☐ RTPProxy corriendo
☐ Puertos 10000-20000 solo en SG-Kamailio
☐ SG-Asterisk acepta solo desde SG-Kamailio
☐ RTPProxy con IPs correctas (PUBLIC/PRIVATE)
☐ nathelper module cargado
☐ rtpproxy_offer() en INVITE
☐ rtpproxy_answer() en respuesta
☐ rtpproxy_manage("co") en NATMANAGE
☐ Audio funciona con clientes NAT
☐ tcpdump muestra RTP en Kamailio
```

### Lab 2.3: TLS/SRTP

```
☐ Todo de Lab 2.1 y 2.2 ✓
☐ Puerto 5061 TCP abierto en SG-Kamailio
☐ Puerto 5061 TCP abierto en SG-Asterisk (desde Kamailio)
☐ Certificado Kamailio generado (/etc/kamailio/tls/)
☐ Certificado Asterisk generado (/etc/asterisk/keys/)
☐ TLS module cargado en Kamailio
☐ Kamailio escucha en 5061 TLS
☐ Asterisk transport-tls configurado
☐ Asterisk media_encryption=sdes
☐ Softphone configurado con TLS
☐ Softphone configurado con SRTP Mandatory
☐ Registro con TLS exitoso
☐ Llamada con SRTP funciona
☐ Wireshark muestra TLS Application Data
☐ Wireshark muestra SDP con a=crypto
☐ RTP aparece cifrado (SRTP)
```

### Lab 2.4: Monitoreo y Defensa

```
☐ Todo de Lab 2.1, 2.2 y 2.3 ✓
☐ sngrep instalado
☐ sngrep muestra llamadas en vivo
☐ Puedo ver diagrama de flujo (F7)
☐ Puedo guardar PCAP (F2)
☐ fail2ban instalado
☐ fail2ban corriendo
☐ Jail kamailio-auth habilitado
☐ Filtro kamailio-auth configurado
☐ fail2ban detecta intentos fallidos
☐ fail2ban banea después de 3 intentos
☐ Puedo ver IPs baneadas
☐ Puedo desbanear IPs
☐ Mi IP en ignoreip (whitelist)
```

---

## 🆘 Último Recurso

### Reinstalación Limpia

Si todo falla, reinstalar desde cero:

```bash
# 1. Detener servicios
sudo systemctl stop kamailio asterisk rtpproxy fail2ban

# 2. Remover paquetes
sudo apt remove --purge kamailio asterisk rtpproxy fail2ban sngrep

# 3. Limpiar configuraciones
sudo rm -rf /etc/kamailio/* /etc/asterisk/* /etc/fail2ban/jail.local

# 4. Reinstalar
# Ejecutar scripts desde el repositorio GitHub
```

### Crear Nueva Instancia

Si la instancia está muy dañada:

```
1. Terminar instancia actual en AWS
2. Crear nueva instancia EC2 (t2.micro Ubuntu 24.04)
3. Configurar Security Groups correctos según Lab
4. SSH a nueva instancia
5. Clonar repositorio GitHub
6. Ejecutar scripts de instalación
7. Documentar qué causó el problema
```

---

## 🧪 Simulación de Problemas (Testing)

### Simular ataque para fail2ban

```bash
# Desde tu PC, intentar registrar con password incorrecto 4 veces
# Softphone: Password = "wrong123" (incorrecto)

# Verificar que fail2ban detecta
sudo tail -f /var/log/fail2ban.log

# Debe mostrar:
# fail2ban.actions: WARNING [kamailio-auth] Ban TU_IP

# Verificar ban
sudo fail2ban-client status kamailio-auth

# Desbanear para continuar testing
sudo fail2ban-client set kamailio-auth unbanip TU_IP
```

### Simular problema NAT

```bash
# Desactivar RTPProxy temporalmente
sudo systemctl stop rtpproxy

# Intentar llamada → Audio debe fallar

# Ver en sngrep que SDP tiene IPs privadas incorrectas

# Reactivar
sudo systemctl start rtpproxy
```

### Simular problema TLS

```bash
# Softphone: Cambiar de TLS a UDP temporalmente

# Intentar registrar → Debe fallar si solo TLS está configurado

# Wireshark debe mostrar:
# - SIP en texto plano (UDP)
# - Rechazo del servidor
```

---

## 📚 Recursos Adicionales

- [Kamailio Troubleshooting](https://www.kamailio.org/wikidocs/tutorials/trouble-shooting/)
- [Asterisk Troubleshooting](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Troubleshooting)
- [SIP Response Codes](https://en.wikipedia.org/wiki/List_of_SIP_response_codes)
- [RTPProxy Documentation](http://www.rtpproxy.org/)
- [fail2ban Manual](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8)
- [sngrep GitHub](https://github.com/irontec/sngrep)
- [Troubleshooting AWS](./troubleshooting-aws.md)

---

**Última actualización:** Diciembre 2025  
**Versión:** 2.0

**💡 Consejo:** Mantén un log de problemas y soluciones que encuentres. La documentación de tus propios troubleshooting es invaluable para referencia futura.
