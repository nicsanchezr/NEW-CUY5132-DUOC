# Material Complementario - Actividad 2.1
## Introducción al SBC con Kamailio

**Asignatura:** CUY5132 - Comunicaciones Unificadas  
**Experiencia de Aprendizaje:** EA 2 - Seguridad Perimetral e Integración de Servicios  
**Duración:** 3-4 horas pedagógicas

---

## 1. Cheat Sheet de Comandos

### Comandos Esenciales de Kamailio

```bash
# Verificar estado del servicio
sudo systemctl status kamailio
sudo systemctl start kamailio
sudo systemctl stop kamailio
sudo systemctl restart kamailio

# Verificar sintaxis de configuración
sudo kamailio -c
sudo kamailio -c -f /etc/kamailio/kamailio.cfg

# Ver logs en tiempo real
sudo tail -f /var/log/syslog | grep kamailio
sudo journalctl -u kamailio -f

# Comandos kamctl (gestión)
kamctl start
kamctl stop
kamctl restart
kamctl stats

# Comandos kamcmd (runtime)
kamcmd core.version
kamcmd core.uptime
kamcmd stats.get_statistics all
kamcmd stats.get_statistics shmem:
```

### Comandos Esenciales de Asterisk

```bash
# Acceder a CLI de Asterisk
sudo asterisk -rvvv

# Comandos dentro de CLI
pjsip show endpoints
pjsip show aors
pjsip show contacts
pjsip show transports
core show channels
dialplan show
module reload res_pjsip

# Ver logs
sudo tail -f /var/log/asterisk/messages
sudo tail -f /var/log/asterisk/full
```

### Comandos de Red y Diagnóstico

```bash
# Verificar puertos abiertos
sudo netstat -tulpn | grep 5060
sudo ss -tulpn | grep kamailio
sudo lsof -i :5060

# Capturar tráfico SIP
sudo tcpdump -i any -n port 5060 -A
sudo tcpdump -i any -n port 5060 -w captura.pcap

# Ver IPs del sistema
ip addr show
hostname -I
curl ifconfig.me  # IP pública

# Probar conectividad
ping -c 3 IP_ASTERISK
telnet IP_ASTERISK 5060
nc -zv IP_ASTERISK 5060
```

---

## 2. Glosario Técnico

| Término | Español | Definición |
|---------|---------|------------|
| **SBC** | Session Border Controller | Controlador de frontera de sesión; dispositivo que media el tráfico SIP entre redes |
| **PBX** | Private Branch Exchange | Central telefónica privada; sistema que gestiona llamadas internas |
| **UAC** | User Agent Client | Cliente SIP que inicia peticiones |
| **UAS** | User Agent Server | Servidor SIP que responde peticiones |
| **SIP** | Session Initiation Protocol | Protocolo de señalización para VoIP |
| **RTP** | Real-time Transport Protocol | Protocolo de transporte de medios en tiempo real |
| **Via** | - | Header SIP que registra la ruta de un mensaje |
| **Record-Route** | - | Header que fuerza el enrutamiento a través de proxies |
| **Contact** | - | Header que indica la dirección real del endpoint |
| **From/To** | De/Para | Headers que identifican origen y destino |
| **Call-ID** | - | Identificador único de la llamada |
| **CSeq** | Command Sequence | Número de secuencia de comandos SIP |

---

## 3. Códigos de Respuesta SIP Comunes

### Respuestas Exitosas (2xx)

| Código | Significado | Cuándo ocurre |
|--------|-------------|---------------|
| 200 OK | Éxito | REGISTER exitoso, llamada aceptada |
| 202 Accepted | Aceptado | Solicitud procesada pero no completada |

### Respuestas de Redirección (3xx)

| Código | Significado | Cuándo ocurre |
|--------|-------------|---------------|
| 301 Moved Permanently | Movido permanentemente | Usuario cambió de dirección |
| 302 Moved Temporarily | Movido temporalmente | Redirección temporal |

### Errores del Cliente (4xx)

| Código | Significado | Cuándo ocurre |
|--------|-------------|---------------|
| 400 Bad Request | Solicitud mal formada | Sintaxis SIP incorrecta |
| 401 Unauthorized | No autorizado | Falta autenticación |
| 403 Forbidden | Prohibido | Credenciales incorrectas |
| 404 Not Found | No encontrado | Usuario no existe |
| 407 Proxy Auth Required | Auth proxy requerida | Proxy requiere autenticación |
| 408 Request Timeout | Tiempo agotado | No hubo respuesta a tiempo |
| 480 Temporarily Unavailable | Temp. no disponible | Usuario offline |
| 486 Busy Here | Ocupado | Usuario en otra llamada |

### Errores del Servidor (5xx)

| Código | Significado | Cuándo ocurre |
|--------|-------------|---------------|
| 500 Server Internal Error | Error interno | Problema en el servidor |
| 503 Service Unavailable | Servicio no disponible | Servidor sobrecargado |

---

## 4. Diagrama de Flujo SIP - REGISTER

```
Cliente                  Kamailio                  Asterisk
   |                        |                         |
   |--REGISTER------------->|                         |
   |  To: 1001@domain       |                         |
   |  From: 1001@domain     |                         |
   |                        |--REGISTER-------------->|
   |                        |  (reescribe headers)    |
   |                        |                         |
   |                        |<-------401 Unauthorized-|
   |<--401 Unauthorized-----|  (solicita auth)        |
   |  WWW-Authenticate      |                         |
   |                        |                         |
   |--REGISTER------------->|                         |
   |  Authorization: ...    |                         |
   |                        |--REGISTER-------------->|
   |                        |  (con credenciales)     |
   |                        |                         |
   |                        |<--------------200 OK----|
   |<--------200 OK---------|  (registrado)           |
   |  Contact: updated      |                         |
   |                        |                         |
```

**Puntos clave:**
1. Kamailio actúa como proxy transparente
2. Asterisk solicita autenticación (401)
3. Cliente reenvía con credenciales
4. Registro exitoso (200 OK)

---

## 5. Diagrama de Flujo SIP - INVITE (Llamada)

```
Cliente A            Kamailio              Asterisk           Cliente B
   |                    |                     |                  |
   |--INVITE----------->|                     |                  |
   |  (inicia llamada)  |                     |                  |
   |                    |--INVITE------------>|                  |
   |                    |  (enruta)           |                  |
   |                    |                     |--INVITE--------->|
   |                    |                     |                  |
   |                    |                     |<---180 Ringing---|
   |                    |<--180 Ringing-------|                  |
   |<--180 Ringing------|                     |                  |
   |                    |                     |                  |
   |                    |                     |<------200 OK-----|
   |                    |<------200 OK--------|  (acepta)        |
   |<------200 OK-------|                     |                  |
   |                    |                     |                  |
   |--ACK-------------->|                     |                  |
   |                    |--ACK--------------->|                  |
   |                    |                     |--ACK------------>|
   |                    |                     |                  |
   |<==================RTP (audio)=====================>|
   |                    |                     |                  |
   |--BYE-------------->|                     |                  |
   |                    |--BYE--------------->|                  |
   |                    |                     |--BYE------------>|
   |                    |                     |<------200 OK-----|
   |                    |<------200 OK--------|                  |
   |<------200 OK-------|                     |                  |
```

**Fases de la llamada:**
1. **Setup:** INVITE → 180 Ringing → 200 OK
2. **Confirmación:** ACK
3. **Conversación:** RTP (audio bidireccional)
4. **Terminación:** BYE → 200 OK

---

## 6. Anatomía de un Mensaje SIP INVITE

```
INVITE sip:1002@domain.com SIP/2.0          ← Request Line
Via: SIP/2.0/UDP 10.0.1.100:5060;           ← Ruta de retorno
Record-Route: <sip:kamailio.com;lr>         ← Forzar ruta
From: "Alice"<sip:1001@domain.com>;tag=abc  ← Origen
To: <sip:1002@domain.com>                   ← Destino
Call-ID: unique-id-12345                    ← ID de llamada
CSeq: 1 INVITE                              ← Secuencia
Contact: <sip:1001@10.0.1.100:5060>         ← Dir. real cliente
Content-Type: application/sdp               ← Tipo de contenido
Content-Length: 250                         ← Tamaño del body

v=0                                         ← SDP: Versión
o=alice 123 456 IN IP4 10.0.1.100          ← Origen de sesión
s=Call                                      ← Nombre de sesión
c=IN IP4 10.0.1.100                        ← Conexión
t=0 0                                       ← Tiempos
m=audio 20000 RTP/AVP 0 8                  ← Media (audio)
a=rtpmap:0 PCMU/8000                       ← Codec (G.711 μ-law)
a=rtpmap:8 PCMA/8000                       ← Codec (G.711 A-law)
```

**Headers críticos para SBC:**
- **Via:** Kamailio debe agregarse aquí
- **Record-Route:** Kamailio se inserta para permanecer en ruta
- **Contact:** Dirección real del cliente (puede necesitar reescritura)

---

## 7. Configuración de Kamailio Comentada

### Sección: Definiciones Globales

```python
#!KAMAILIO

####### Defined Values #########

# Dirección IP del servidor Asterisk (backend PBX)
#!define ASTERISK_IP "10.0.2.10"

# Puerto SIP del servidor
#!define SIP_PORT 5060

####### Global Parameters #########

# Nivel de debug (3 = info, 4 = debug)
debug=3

# Número de procesos workers
children=4

# Puerto de escucha SIP
port=SIP_PORT

# Escuchar en todas las interfaces
listen=udp:0.0.0.0:SIP_PORT

# Logging
log_stderror=no
log_facility=LOG_LOCAL0
```

### Sección: Módulos Cargados

```python
####### Modules Section ########

# Dirección donde están los módulos
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules/"

# Módulos básicos
loadmodule "tm.so"        # Transaction Management
loadmodule "sl.so"        # Stateless replies
loadmodule "rr.so"        # Record-Route
loadmodule "pv.so"        # Pseudo-Variables
loadmodule "maxfwd.so"    # Max-Forwards (anti-loop)
loadmodule "textops.so"   # Text operations
loadmodule "siputils.so"  # SIP utilities

# Módulos para registro
loadmodule "usrloc.so"    # User location
loadmodule "registrar.so" # REGISTER processing
```

### Sección: Lógica de Routing Principal

```python
####### Routing Logic ########

# Ruta principal: procesa TODA solicitud SIP entrante
request_route {
    
    # Anti-loop: verificar Max-Forwards
    if (!mf_process_maxfwd_header("10")) {
        sl_send_reply("483", "Too Many Hops");
        exit;
    }
    
    # Logging para debug
    xlog("L_INFO", "[$rm] from $fu to $tu\n");
    
    # Procesar REGISTER
    if (is_method("REGISTER")) {
        route(REGISTER);
        exit;
    }
    
    # Record-Route para llamadas (excepto REGISTER)
    if (!is_method("REGISTER")) {
        record_route();
    }
    
    # Lookup de usuario registrado
    if (!lookup("location")) {
        sl_send_reply("404", "Not Found");
        exit;
    }
    
    # Enviar a Asterisk
    route(TOASTERISK);
}

# Ruta: Procesar REGISTER
route[REGISTER] {
    # Guardar en usrloc (tabla de ubicaciones)
    if (!save("location")) {
        sl_reply_error();
    }
    # Reenviar a Asterisk para autenticación
    $du = "sip:" + ASTERISK_IP + ":" + SIP_PORT;
    t_relay();
    exit;
}

# Ruta: Enviar a Asterisk
route[TOASTERISK] {
    # Establecer destination URI
    $du = "sip:" + ASTERISK_IP + ":" + SIP_PORT;
    
    # Logging
    xlog("L_INFO", "Routing to Asterisk: $du\n");
    
    # Reenviar con transaction
    if (!t_relay()) {
        sl_reply_error();
    }
    exit;
}
```

**Conceptos clave:**
- `request_route`: Punto de entrada de TODAS las peticiones SIP
- `route[NOMBRE]`: Sub-rutas para organizar lógica
- `$du`: Destination URI (hacia dónde enviar)
- `t_relay()`: Reenviar con gestión de transacciones

---

## 8. Configuración de Asterisk Comentada

### Archivo: pjsip.conf

```ini
;========== TRANSPORT UDP ==========
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060          ; Escuchar en todas las IPs, puerto 5060
external_media_address=    ; IP pública (se configura si NAT)
external_signaling_address=; IP pública para SIP (se configura si NAT)

;========== PLANTILLA DE ENDPOINT ==========
; Configuración común heredable
[endpoint_template](!)
type=endpoint
context=default            ; Contexto del dialplan
disallow=all              ; Desactivar todos los codecs
allow=ulaw                ; Permitir G.711 μ-law
allow=alaw                ; Permitir G.711 A-law
direct_media=no           ; Forzar que RTP pase por Asterisk
rtp_symmetric=yes         ; Ayuda con NAT
force_rport=yes           ; Ayuda con NAT
rewrite_contact=yes       ; Reescribir Contact header

;========== EXTENSIONES ==========
[1001](endpoint_template)  ; Hereda de template
type=endpoint
auth=auth1001             ; Referencia a autenticación
aors=1001                 ; Referencia a AOR

[auth1001]
type=auth
auth_type=userpass
username=1001
password=SecurePass123    ; Contraseña del usuario

[1001]
type=aor
max_contacts=1            ; Permitir 1 registro simultáneo
remove_existing=yes       ; Remover registros previos

; Repetir patrón para 1002, 1003, etc.
```

### Archivo: extensions.conf

```ini
;========== CONTEXTO DEFAULT ==========
[default]

; Extensión 100: Echo test
exten => 100,1,Answer()
 same => n,Playback(demo-echotest)
 same => n,Echo()                    ; Devolver audio al emisor
 same => n,Hangup()

; Patrón para llamadas internas (1001-1999)
exten => _1XXX,1,NoOp(Llamada de ${CALLERID(num)} a ${EXTEN})
 same => n,Dial(PJSIP/${EXTEN},30)   ; Llamar durante 30 segundos
 same => n,Hangup()

; Extensión inválida
exten => _X.,1,Playback(invalid)
 same => n,Hangup()
```

**Explicación del dialplan:**
- `_1XXX`: Patrón que coincide con 1000-1999
- `NoOp()`: No operation (solo logging)
- `Dial(PJSIP/${EXTEN},30)`: Llamar al endpoint por 30 seg
- `Hangup()`: Colgar la llamada

---

## 9. Preguntas Frecuentes (FAQ)

### P1: ¿Por qué mi softphone no registra?

**R:** Verificar en orden:
1. Kamailio está corriendo: `sudo systemctl status kamailio`
2. Puerto 5060 abierto en Security Group de AWS
3. IP correcta en softphone (IP pública de Kamailio)
4. Asterisk está corriendo: `sudo systemctl status asterisk`
5. Ver logs: `sudo tail -f /var/log/syslog | grep kamailio`

### P2: ¿Cómo sé si Kamailio está recibiendo el REGISTER?

**R:** Usar tcpdump:
```bash
sudo tcpdump -i any -n port 5060 -A
```
Deberías ver el mensaje REGISTER llegar. Si no ves nada, el problema es de red/firewall.

### P3: ¿Qué significa el error "483 Too Many Hops"?

**R:** Hay un loop en el routing. Kamailio está reenviando mensajes a sí mismo. Verificar:
- La IP de Asterisk en `kamailio.cfg` es correcta
- No hay loops en record-route

### P4: ¿Por qué Asterisk responde 401 Unauthorized?

**R:** Es normal. El flujo correcto es:
1. Cliente envía REGISTER sin credenciales
2. Asterisk responde 401 (solicita autenticación)
3. Cliente reenvía REGISTER CON credenciales
4. Asterisk responde 200 OK

### P5: ¿Cómo verifico que el REGISTER llegó a Asterisk?

**R:** En Asterisk CLI:
```bash
sudo asterisk -rvvv
pjsip show endpoints
pjsip show contacts
```
Deberías ver el endpoint con estado "Avail" y un contacto activo.

### P6: ¿Puedo usar la IP privada de Kamailio en el softphone?

**R:** No. Desde Internet debes usar la **IP pública** de Kamailio. La IP privada solo funciona dentro de la VPC de AWS.

### P7: ¿Qué es exactamente Record-Route?

**R:** Es un header que Kamailio agrega para decirle a los endpoints: "pasa todos los mensajes futuros de esta llamada por mí". Así Kamailio permanece en el path de señalización.

### P8: ¿Por qué necesito kamcmd y kamctl?

**R:** 
- `kamctl`: Scripts de gestión del servicio (start/stop)
- `kamcmd`: Interfaz para comandos en runtime (stats, debugging)

### P9: Mi IP pública de AWS cambió, ¿qué hago?

**R:** 
1. Anotar nueva IP: `curl ifconfig.me`
2. Actualizar en softphone
3. Reiniciar Kamailio si es necesario
4. Actualizar alias en `kamailio.cfg` si lo usas

### P10: ¿Cómo sé la versión de Kamailio instalada?

**R:**
```bash
kamailio -v
# o
kamcmd core.version
```

---

## 10. Checklist de Verificación Lab 2.1

Antes de dar por completado el laboratorio, verificar:

### Instalación y Servicios
- [ ] Kamailio instalado correctamente
- [ ] Asterisk instalado correctamente
- [ ] Kamailio corriendo: `sudo systemctl status kamailio`
- [ ] Asterisk corriendo: `sudo systemctl status asterisk`
- [ ] Ambos inician automáticamente: `systemctl is-enabled kamailio asterisk`

### Configuración de Red
- [ ] Security Group permite puerto 5060 UDP
- [ ] Security Group permite puerto 22 TCP (SSH)
- [ ] IP pública de Kamailio anotada
- [ ] IP privada de Asterisk anotada
- [ ] Ping funciona entre instancias

### Configuración de Kamailio
- [ ] Archivo `kamailio.cfg` editado
- [ ] IP de Asterisk correcta en configuración
- [ ] Sintaxis verificada: `sudo kamailio -c`
- [ ] Sin errores en logs: `journalctl -u kamailio`

### Configuración de Asterisk
- [ ] Archivo `pjsip.conf` configurado
- [ ] Archivo `extensions.conf` configurado
- [ ] Al menos 2 extensiones creadas (1001, 1002)
- [ ] Transporte UDP configurado

### Pruebas Funcionales
- [ ] Softphone registra exitosamente
- [ ] `pjsip show endpoints` muestra endpoint "Avail"
- [ ] `pjsip show contacts` muestra contacto activo
- [ ] Llamada de prueba a extensión 100 (echo test) funciona
- [ ] Llamada entre extensiones (1001 → 1002) funciona
- [ ] Audio bidireccional confirmado

### Documentación
- [ ] Capturas de pantalla tomadas
- [ ] IPs documentadas
- [ ] Configuraciones respaldadas
- [ ] Problemas y soluciones anotados

---

## 11. Ejercicios Adicionales

### Ejercicio 1: Análisis de Headers SIP

Captura un REGISTER exitoso y responde:
1. ¿Cuántos Via headers hay? ¿Por qué?
2. ¿Qué diferencia hay entre From y Contact?
3. ¿Qué significa el parámetro `lr` en Record-Route?

### Ejercicio 2: Modificar Número de Workers

1. Edita `/etc/kamailio/kamailio.cfg`
2. Cambia `children=4` a `children=8`
3. Reinicia Kamailio
4. Verifica con `ps aux | grep kamailio`
5. ¿Cuántos procesos ves ahora?

### Ejercicio 3: Crear Extensión de Buzón de Voz

Modifica `extensions.conf` para crear extensión 200:
```ini
exten => 200,1,Answer()
 same => n,Playback(vm-intro)
 same => n,Record(/tmp/mensaje.wav,3,20)
 same => n,Playback(vm-saved)
 same => n,Hangup()
```

### Ejercicio 4: Implementar Horario Laboral

Crea lógica en dialplan para:
- Lunes-Viernes 9:00-18:00: Llamadas normales
- Fuera de horario: Mensaje "Fuera de horario"

---

## 12. Caso de Estudio

### Escenario: Pequeña Empresa con 2 Sucursales

**Contexto:**
- Empresa "TechCorp" tiene oficina principal en Santiago y sucursal en Valparaíso
- 10 empleados en Santiago, 5 en Valparaíso
- Necesitan comunicación interna sin costos de telefonía

**Tu misión:**
Diseñar la arquitectura VoIP considerando:
1. ¿Dónde colocar el SBC y el PBX?
2. ¿Cómo numerarías las extensiones?
3. ¿Qué Security Groups configurarías?
4. ¿Cómo manejarías la caída del servicio?

**Entregable:**
Diagrama de arquitectura y justificación de decisiones.

---

## 13. Recursos Adicionales

### Documentación Oficial
- [Kamailio Documentation](https://www.kamailio.org/wikidocs/)
- [Asterisk PJSIP Guide](https://wiki.asterisk.org/wiki/display/AST/Configuring+res_pjsip)

### Tutoriales Recomendados
- Kamailio Basics: https://www.kamailio.org/docs/tutorials/
- SIP Protocol Overview: https://www.ietf.org/rfc/rfc3261.txt

### Herramientas Online
- SIP Response Code Reference: https://www.iana.org/assignments/sip-parameters/
- SIP Header Visualizer: https://www.sipcapture.org/

---

**Última actualización:** 2024  
**Versión:** 1.0
