# Material Complementario - Actividad 2.2
## Topología y Anti-NAT con Kamailio

**Asignatura:** CUY5132 - Comunicaciones Unificadas  
**Experiencia de Aprendizaje:** EA 2 - Seguridad Perimetral e Integración de Servicios  
**Duración:** 3-4 horas pedagógicas

---

## 1. Cheat Sheet de Comandos

### Comandos de RTPProxy

```bash
# Verificar estado de RTPProxy
sudo systemctl status rtpproxy
sudo systemctl start rtpproxy
sudo systemctl stop rtpproxy
sudo systemctl restart rtpproxy

# Ver configuración de RTPProxy
cat /etc/default/rtpproxy

# Iniciar RTPProxy manualmente (debug)
rtpproxy -F -d DBUG:LOG_LOCAL0

# Ver procesos RTPProxy
ps aux | grep rtpproxy

# Ver puertos RTP en uso
sudo netstat -anp | grep rtpproxy
sudo ss -anp | grep rtpproxy

# Logs de RTPProxy
sudo tail -f /var/log/syslog | grep rtpproxy
```

### Comandos de Verificación NAT

```bash
# Detectar IP pública vs privada
# IP Pública:
curl ifconfig.me
curl icanhazip.com
dig +short myip.opendns.com @resolver1.opendns.com

# IP Privada:
hostname -I
ip addr show

# Verificar si estás tras NAT
if [[ $(hostname -I | awk '{print $1}') =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
    echo "Estás tras NAT - IP privada"
else
    echo "IP pública directa"
fi
```

### Comandos de Captura de Tráfico RTP

```bash
# Capturar SOLO tráfico RTP
sudo tcpdump -i any -n 'portrange 10000-20000' -w rtp.pcap

# Capturar SIP + RTP simultáneamente
sudo tcpdump -i any -n '(port 5060 or portrange 10000-20000)' -w completo.pcap

# Ver paquetes RTP en tiempo real (contador)
sudo tcpdump -i any -n 'portrange 10000-20000' | wc -l

# Estadísticas de tráfico RTP
sudo tcpdump -i any -n -c 1000 'portrange 10000-20000' -q
```

### Comandos de Diagnóstico de Audio

```bash
# Verificar que RTP está fluyendo
# Durante una llamada activa:
sudo tcpdump -i any -n -c 10 'portrange 10000-20000'

# Si ves paquetes = RTP funciona ✓
# Si NO ves paquetes = problema de configuración ✗

# Ver sesiones activas de RTPProxy
# (requiere socket de control configurado)
echo "I" | nc -u localhost 7722

# Verificar ancho de banda RTP
iftop -i eth0 -f 'port 10000 or port 20000'
```

---

## 2. Glosario Técnico NAT/RTP

| Término | Español | Definición |
|---------|---------|------------|
| **NAT** | Network Address Translation | Traducción de direcciones de red; permite compartir IP pública |
| **RTP** | Real-time Transport Protocol | Protocolo de transporte para audio/video en tiempo real |
| **RTCP** | RTP Control Protocol | Protocolo de control para estadísticas de RTP |
| **RTPProxy** | - | Servidor proxy para relay de medios RTP |
| **Media Relay** | Relevo de medios | Reenvío de paquetes RTP/RTCP a través de un proxy |
| **Symmetric RTP** | RTP simétrico | RTP se envía de vuelta a la IP/puerto de origen |
| **One-way audio** | Audio unidireccional | Solo una parte escucha audio |
| **SDP** | Session Description Protocol | Protocolo que describe sesión multimedia |
| **c= line** | Connection line | Línea SDP que indica IP para RTP |
| **m= line** | Media line | Línea SDP que indica puerto y codec |
| **nathelper** | - | Módulo Kamailio para gestión NAT |
| **rtpproxy** | - | Módulo Kamailio para control de RTPProxy |
| **fix_nated_contact** | - | Función que corrige header Contact |
| **fix_nated_sdp** | - | Función que corrige IPs en SDP |

---

## 3. Conceptos Fundamentales de NAT

### ¿Qué es NAT y por qué es un problema para VoIP?

**NAT (Network Address Translation):**
- Permite a múltiples dispositivos con IPs privadas compartir una sola IP pública
- Router modifica las IPs en paquetes que salen/entran

**IP Privadas (RFC 1918):**
- `10.0.0.0/8` (10.0.0.0 - 10.255.255.255)
- `172.16.0.0/12` (172.16.0.0 - 172.31.255.255)
- `192.168.0.0/16` (192.168.0.0 - 192.168.255.255)

**Problema con VoIP:**

```
Cliente en casa              Router NAT              Internet
IP: 192.168.1.100    ←→    IP Privada: 192.168.1.1   
                           IP Pública: 200.1.2.3    ←→  Servidor VoIP
```

1. **Señalización SIP:** Headers contienen IP privada (192.168.1.100)
2. **SDP (para RTP):** Indica IP privada para recibir audio
3. **Servidor intenta enviar audio a 192.168.1.100** → ✗ NO ES ROUTABLE

---

## 4. Diagrama: Problema de NAT sin Solución

```
Softphone                Router NAT              Kamailio          Asterisk
192.168.1.5              200.50.50.1            200.100.100.1     10.0.2.10
     |                        |                      |                |
     |--INVITE--------------->|                      |                |
     | SDP: c=192.168.1.5     |                      |                |
     |                        |--INVITE (src:200.50.50.1)------------>|
     |                        |  SDP: c=192.168.1.5  |                |
     |                        |                      |                |
     |                        |                      |<---200 OK------|
     |                        |                      | SDP: c=10.0.2.10
     |<-------200 OK----------|                      |                |
     | SDP: c=10.0.2.10       |                      |                |
     |                        |                      |                |
     | Intenta enviar RTP a 10.0.2.10 ✗ (no routable)                |
     | Asterisk intenta enviar RTP a 192.168.1.5 ✗ (detrás de NAT)   |
     |                        |                      |                |
     |          ❌ NO HAY AUDIO (problema de NAT) ❌                  |
```

**Problema:** Ambas partes tienen IPs que la otra no puede alcanzar.

---

## 5. Diagrama: Solución con RTPProxy

```
Softphone         Router NAT     Kamailio+RTPProxy        Asterisk
192.168.1.5       200.50.50.1    200.100.100.1            10.0.2.10
     |                 |              |                       |
     |--INVITE-------->|              |                       |
     | SDP: c=192.168.1.5 port 20000 |                       |
     |                 |--INVITE----->|                       |
     |                 | src IP: 200.50.50.1 (NAT translation)|
     |                 |              |                       |
     |                 |              | RTPProxy detecta NAT  |
     |                 |              | Asigna puerto 15000   |
     |                 |              | Modifica SDP          |
     |                 |              |                       |
     |                 |              |--INVITE-------------->|
     |                 |              | SDP: c=200.100.100.1  |
     |                 |              |      port 15000       |
     |                 |              |                       |
     |                 |              |<------200 OK----------|
     |                 |              | SDP: c=10.0.2.10      |
     |                 |              |      port 25000       |
     |                 |              |                       |
     |                 |              | RTPProxy asigna 16000 |
     |                 |              | Modifica SDP          |
     |                 |              |                       |
     |                 |<----200 OK---|                       |
     |                 | SDP: c=200.100.100.1                 |
     |<---200 OK-------|      port 16000                      |
     | SDP: c=200.100.100.1                                   |
     |      port 16000 |              |                       |
     |                 |              |                       |
     |===RTP (20000)===|==RTP (src port NAT)==>RTPProxy:15000 |
     |                 |              |===RTP================>| :25000
     |                 |              |                       |
     |                 |              | <===RTP===============| :25000
     |<==RTP===========|<==RTP (NAT translate)==RTPProxy:16000|
     |                 |              |                       |
     |         ✅ AUDIO BIDIRECCIONAL FUNCIONA ✅             |
```

**Solución:** RTPProxy actúa como relay, usando su IP pública routable.

---

## 6. Flujo de Procesamiento con rtpproxy_manage()

### ¿Qué hace rtpproxy_manage()?

Es una función de Kamailio que:
1. **Detecta dirección del flujo** (cliente → servidor o servidor → cliente)
2. **Analiza SDP** en el mensaje SIP
3. **Comunica con RTPProxy** para obtener puerto relay
4. **Reescribe SDP** con IP/puerto de RTPProxy
5. **Gestiona sesión** hasta que termine la llamada

### Momento de Invocación

```python
# En INVITE (ofrecer)
if (is_method("INVITE") && has_body("application/sdp")) {
    rtpproxy_manage("co");
    # co = replace Connection IP + Offer
}

# En 200 OK (responder)
if (is_method("ACK|PRACK|UPDATE") && has_body("application/sdp")) {
    rtpproxy_manage("ca");
    # ca = replace Connection IP + Answer
}

# En respuesta a INVITE
if (status =~ "18[03]|2[0-9][0-9]" && has_body("application/sdp")) {
    rtpproxy_manage("ca");
}
```

### Flags de rtpproxy_manage()

| Flag | Significado | Cuándo usar |
|------|-------------|-------------|
| **c** | Replace Connection IP | Siempre (cambia c= line) |
| **o** | Offer | En INVITE (quien inicia) |
| **a** | Answer | En 200 OK (quien responde) |
| **w** | Symmetric | Usar IP de donde vino el paquete |
| **e** | External | Usar IP pública (no privada) |
| **i** | Internal | Usar IP privada (no pública) |
| **r** | Rport | Activar rport para NAT |

### Ejemplo Completo

```python
if (is_method("INVITE") && has_body("application/sdp")) {
    if (nat_uac_test("19")) {
        # Cliente está tras NAT
        rtpproxy_manage("cowr");
        # c = replace IP
        # o = offer
        # w = symmetric
        # r = rport
    }
}
```

---

## 7. Configuración de RTPProxy Explicada

### Archivo: /etc/default/rtpproxy

```bash
# Dirección de escucha para control (desde Kamailio)
# udp:localhost:7722 = socket UDP en puerto 7722
CONTROL_SOCK="udp:localhost:7722"

# IPs para RTP
# -l PRIVATE_IP/PUBLIC_IP
# PRIVATE_IP = IP interna de la instancia (10.0.X.X)
# PUBLIC_IP = IP pública de la instancia
EXTRA_OPTS="-l 10.0.1.10/200.100.100.1"

# Rango de puertos RTP
# Por defecto: 35000-65000
# Se puede cambiar con -m/-M:
# EXTRA_OPTS="-l 10.0.1.10/200.100.100.1 -m 10000 -M 20000"

# Logging level (debug)
# EXTRA_OPTS="-l 10.0.1.10/200.100.100.1 -d DBUG:LOG_LOCAL0"

# Usuario bajo el cual corre
USER=rtpproxy
GROUP=rtpproxy
```

### ¿Cómo Obtener las IPs Correctas?

```bash
# IP Privada (primera IP en hostname -I)
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo $PRIVATE_IP

# IP Pública
PUBLIC_IP=$(curl -s ifconfig.me)
echo $PUBLIC_IP

# Configurar en /etc/default/rtpproxy
sudo sed -i "s|EXTRA_OPTS=.*|EXTRA_OPTS=\"-l $PRIVATE_IP/$PUBLIC_IP\"|" /etc/default/rtpproxy

# Reiniciar
sudo systemctl restart rtpproxy
```

---

## 8. Configuración de Kamailio con NAT

### Módulos Necesarios

```python
# Módulos para NAT
loadmodule "nathelper.so"   # Detección y manejo NAT
loadmodule "rtpproxy.so"    # Control de RTPProxy

# Parámetros de rtpproxy
modparam("rtpproxy", "rtpproxy_sock", "udp:127.0.0.1:7722")

# Parámetros de nathelper
modparam("nathelper", "natping_interval", 30)  # Keep-alive cada 30s
modparam("nathelper", "ping_nated_only", 1)    # Ping solo a NATed clients
modparam("nathelper", "sipping_from", "sip:pinger@kamailio.local")
```

### Funciones Clave

```python
# Detectar si cliente está tras NAT
nat_uac_test("flags")

# Flags comunes:
# 1 - Contact header tiene IP privada
# 2 - Via header tiene IP diferente a fuente
# 4 - Via header tiene rport sin valor
# 8 - Via header tiene rport diferente al puerto fuente
# 16 - Contact tiene puerto diferente al fuente
# 19 = 1+2+16 (combinación común)

# Ejemplo de uso:
if (nat_uac_test("19")) {
    xlog("L_INFO", "Cliente $fu está tras NAT\n");
    setflag(FLT_NATED);
}
```

### Lógica de Routing para NAT

```python
request_route {
    # ... código anterior ...
    
    # Detectar NAT en requests
    route(NATDETECT);
    
    # ... más código ...
    
    # En INVITE
    if (is_method("INVITE")) {
        route(NATMANAGE);
        route(TOASTERISK);
    }
}

# Ruta: Detectar NAT
route[NATDETECT] {
    force_rport();  # Forzar rport siempre
    
    if (nat_uac_test("19")) {
        if (is_method("REGISTER")) {
            fix_nated_register();
        } else {
            # Marcar como NATed para uso posterior
            setflag(FLT_NATED);
            fix_nated_contact();
        }
    }
}

# Ruta: Gestionar NAT y RTPProxy
route[NATMANAGE] {
    if (is_method("INVITE") && has_body("application/sdp")) {
        # Ofrecer relay RTP
        rtpproxy_manage("cowr");
    }
    
    if (is_method("ACK") && has_body("application/sdp")) {
        # Responder relay RTP
        rtpproxy_manage("cowr");
    }
}

# Procesar respuestas
onreply_route {
    if (status =~ "18[03]|2[0-9][0-9]" && has_body("application/sdp")) {
        # Gestionar relay RTP en respuestas
        rtpproxy_manage("cowr");
    }
    
    if (isflagset(FLT_NATED)) {
        fix_nated_contact();
    }
}

# Limpiar sesión al finalizar
failure_route[MANAGE_FAILURE] {
    if (t_is_canceled()) {
        rtpproxy_delete();
        exit;
    }
}
```

---

## 9. Análisis de SDP Antes y Después de RTPProxy

### SDP Original (Cliente NAT)

```
v=0
o=user 12345 67890 IN IP4 192.168.1.5        ← IP privada
s=Call
c=IN IP4 192.168.1.5                         ← IP privada (problema!)
t=0 0
m=audio 20000 RTP/AVP 0 8                    ← Puerto cliente
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
```

**Problema:** `c=IN IP4 192.168.1.5` no es routable desde Internet.

### SDP Modificado por RTPProxy (hacia Asterisk)

```
v=0
o=user 12345 67890 IN IP4 200.100.100.1      ← IP pública RTPProxy
s=Call
c=IN IP4 200.100.100.1                       ← IP pública RTPProxy ✓
t=0 0
m=audio 15000 RTP/AVP 0 8                    ← Puerto RTPProxy ✓
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
```

**Solución:** Asterisk enviará RTP a `200.100.100.1:15000` (RTPProxy).

### Tabla de Mapeo RTPProxy

| Origen | IP:Puerto | RTPProxy Relay | Destino | IP:Puerto |
|--------|-----------|----------------|---------|-----------|
| Cliente A | 192.168.1.5:20000 | → 15000 | Asterisk | 10.0.2.10:25000 |
| Asterisk | 10.0.2.10:25000 | → 16000 | Cliente A | 200.50.50.1:xxxx |

*Nota: Puerto de retorno del cliente es asignado dinámicamente por NAT*

---

## 10. Preguntas Frecuentes (FAQ)

### P1: ¿Por qué hay llamada pero NO audio?

**R:** Este es EL problema más común. Verificar:
1. RTPProxy está corriendo: `sudo systemctl status rtpproxy`
2. Puertos 10000-20000 UDP abiertos en Security Group
3. `rtpproxy_manage()` se llama en INVITE y 200 OK
4. IPs correctas en `/etc/default/rtpproxy`

### P2: ¿Cómo verifico que RTPProxy está funcionando?

**R:** Durante una llamada activa:
```bash
sudo tcpdump -i any -n 'portrange 10000-20000' -c 10
```
Si ves paquetes UDP = RTPProxy está relayando ✓

### P3: Audio solo en UNA dirección, ¿por qué?

**R:** RTPProxy no está configurado con ambas IPs correctas:
```bash
# Verificar
cat /etc/default/rtpproxy

# Debe tener:
EXTRA_OPTS="-l IP_PRIVADA/IP_PUBLICA"

# Si falta alguna, corregir y reiniciar
sudo systemctl restart rtpproxy
```

### P4: ¿Qué significa "symmetric RTP"?

**R:** RTP se envía de vuelta a la IP/puerto desde donde se recibió el primer paquete. Útil para NAT porque el puerto de origen puede ser diferente al anunciado.

### P5: ¿Por qué RTPProxy usa rango 10000-20000 por defecto?

**R:** Rango estándar para RTP definido por IANA. Puedes cambiarlo con `-m` y `-M` en `EXTRA_OPTS`.

### P6: ¿Cómo sé qué puerto asignó RTPProxy a mi llamada?

**R:** Ver logs de RTPProxy:
```bash
sudo tail -f /var/log/syslog | grep rtpproxy
```
Verás mensajes como: "new session on port 15234"

### P7: Mi IP pública cambió, ¿afecta a RTPProxy?

**R:** Sí. Debes:
1. Actualizar `/etc/default/rtpproxy` con nueva IP pública
2. Reiniciar: `sudo systemctl restart rtpproxy`

### P8: ¿RTPProxy transcoda audio?

**R:** No. RTPProxy solo hace RELAY (reenvío). No modifica el contenido de los paquetes RTP ni hace transcodificación entre codecs.

### P9: ¿fix_nated_sdp() es lo mismo que rtpproxy_manage()?

**R:** No. 
- `fix_nated_sdp()`: Función legacy para reescribir SDP
- `rtpproxy_manage()`: Función moderna, más completa y recomendada

### P10: ¿Puedo tener múltiples instancias de RTPProxy?

**R:** Sí, para balanceo de carga. Kamailio puede gestionar un pool de RTPProxy servers.

---

## 11. Checklist de Verificación Lab 2.2

### Instalación y Servicios
- [ ] RTPProxy instalado correctamente
- [ ] RTPProxy corriendo: `sudo systemctl status rtpproxy`
- [ ] RTPProxy inicia automáticamente: `systemctl is-enabled rtpproxy`
- [ ] Socket de control en puerto 7722: `netstat -tulpn | grep 7722`

### Configuración de RTPProxy
- [ ] Archivo `/etc/default/rtpproxy` editado
- [ ] IP privada correcta configurada
- [ ] IP pública correcta configurada
- [ ] Sin errores en logs: `journalctl -u rtpproxy`

### Configuración de Kamailio
- [ ] Módulos nathelper y rtpproxy cargados
- [ ] Socket de RTPProxy configurado en modparam
- [ ] `rtpproxy_manage()` presente en route de INVITE
- [ ] `rtpproxy_manage()` presente en onreply_route
- [ ] Sintaxis verificada: `sudo kamailio -c`

### Configuración de Red AWS
- [ ] Security Group permite 10000-20000 UDP (RTP)
- [ ] Security Group permite 7722 UDP (control RTPProxy)
- [ ] Security Group permite 5060 UDP (SIP)

### Pruebas Funcionales
- [ ] Lab 2.1 funciona (prerequisito)
- [ ] Softphone registra
- [ ] Llamada se establece
- [ ] **Audio bidireccional confirmado** ✓
- [ ] Audio funciona con cliente detrás de NAT
- [ ] Captura tcpdump muestra paquetes RTP

### Validación con Wireshark
- [ ] Captura .pcap tomada
- [ ] Se ven paquetes RTP/RTCP
- [ ] IPs en RTP corresponden a RTPProxy
- [ ] Puertos en rango 10000-20000

---

## 12. Ejercicios Adicionales

### Ejercicio 1: Análisis de Tráfico RTP

1. Iniciar captura: `sudo tcpdump -i any -n 'portrange 10000-20000' -w rtp.pcap`
2. Hacer llamada de 30 segundos
3. Detener captura
4. Abrir con Wireshark
5. Responder:
   - ¿Cuántos paquetes RTP capturaste?
   - ¿Cada cuánto tiempo llegan (pacing)?
   - ¿Qué codec se usó?
   - ¿Hubo pérdida de paquetes?

### Ejercicio 2: Simular Problema de NAT

1. Detener RTPProxy: `sudo systemctl stop rtpproxy`
2. Hacer llamada
3. ¿Qué pasa? Documentar
4. Ver logs de Kamailio
5. Iniciar RTPProxy de nuevo
6. ¿Se recupera la llamada?

### Ejercicio 3: Cambiar Rango de Puertos RTP

Modifica `/etc/default/rtpproxy`:
```bash
EXTRA_OPTS="-l IP_PRIVADA/IP_PUBLICA -m 30000 -M 40000"
```
1. Actualiza Security Group AWS (30000-40000 UDP)
2. Reinicia RTPProxy
3. Prueba llamada
4. Verifica que RTP usa nuevo rango

### Ejercicio 4: Implementar Logging Detallado

Agrega a kamailio.cfg:
```python
route[NATMANAGE] {
    if (is_method("INVITE") && has_body("application/sdp")) {
        xlog("L_INFO", "ANTES de RTPProxy: $rb\n");
        rtpproxy_manage("cowr");
        xlog("L_INFO", "DESPUES de RTPProxy: $rb\n");
    }
}
```
Compara el SDP antes y después.

---

## 13. Caso de Estudio

### Escenario: Call Center con Agentes Remotos

**Contexto:**
- Call center "SoporteTech" con 50 agentes
- 20 agentes en oficina (red local)
- 30 agentes remotos (trabajo desde casa, detrás de NAT)
- Asterisk en datacenter (IP pública)
- Kamailio como SBC

**Problemas actuales:**
- Agentes remotos tienen audio solo en una dirección
- Algunos no escuchan, otros no pueden hablar
- Problema intermitente

**Tu misión:**
1. Diagnosticar el problema
2. Proponer solución con RTPProxy
3. Diseñar arquitectura
4. Estimar recursos (ancho de banda, puertos)

**Cálculos:**
- 30 agentes remotos simultáneos
- Codec G.711 (64 kbps)
- 2 puertos RTP por llamada (audio + RTCP)

¿Cuánto ancho de banda necesita RTPProxy?
¿Cuántos puertos en el rango 10000-20000?

---

## 14. Diagramas de Troubleshooting

### Árbol de Decisión: "NO HAY AUDIO"

```
┌─────────────────────────┐
│   NO HAY AUDIO          │
└────────────┬────────────┘
             │
             ▼
┌────────────────────────────┐
│ ¿Llamada se establece OK?  │
└────┬──────────────────┬────┘
     │ NO               │ SÍ
     ▼                  ▼
┌─────────────┐   ┌─────────────────────┐
│ Problema de │   │ ¿Audio en una       │
│ señalización│   │ dirección?          │
│ (Lab 2.1)   │   └────┬───────────┬────┘
└─────────────┘        │ SÍ        │ NO (ninguna)
                       ▼           ▼
              ┌────────────────┐  ┌──────────────────┐
              │ Problema NAT   │  │ ¿RTPProxy        │
              │ asimétrico     │  │ corriendo?       │
              │                │  └────┬────────┬────┘
              │ Verificar:     │       │ NO     │ SÍ
              │ - Symmetric    │       ▼        ▼
              │   RTP          │  ┌────────┐ ┌─────────────┐
              │ - IPs públicas │  │ Iniciar│ │ ¿Puertos    │
              │   correctas    │  │ rtpproxy│ │ 10k-20k     │
              └────────────────┘  └────────┘ │ abiertos?   │
                                             └──┬──────┬───┘
                                                │ NO   │ SÍ
                                                ▼      ▼
                                           ┌─────────────────┐
                                           │ Abrir en        │
                                           │ Security Group  │
                                           └─────────────────┘
```

---

## 15. Comparativa de Soluciones NAT

| Solución | Complejidad | Escalabilidad | Rendimiento | Costo |
|----------|-------------|---------------|-------------|-------|
| **RTPProxy** | Media | Alta | Muy bueno | Gratis (OSS) |
| **RTPEngine** | Alta | Muy alta | Excelente | Gratis (OSS) |
| **STUN** | Baja | Alta | Excelente | Gratis |
| **TURN** | Media | Media | Bueno | Ancho de banda |
| **ICE** | Alta | Alta | Excelente | Gratis |
| **VPN** | Baja | Baja | Bueno | Infraestructura |
| **SBC Comercial** | Baja | Alta | Excelente | $$$ Alto |

**Recomendación para labs:** RTPProxy (buen balance)

---

## 16. Recursos Adicionales

### Documentación Oficial
- [RTPProxy GitHub](https://github.com/sippy/rtpproxy)
- [Kamailio nathelper module](https://www.kamailio.org/docs/modules/stable/modules/nathelper.html)
- [RFC 3550 - RTP](https://tools.ietf.org/html/rfc3550)

### Tutoriales
- [NAT Traversal in SIP](https://www.voip-info.org/nat-and-voip/)
- [RTPProxy Configuration Guide](https://www.kamailio.org/docs/modules/stable/modules/rtpproxy.html)

### Herramientas
- Wireshark VoIP Analysis
- sngrep para análisis SIP
- RTPProxy control socket

---

**Última actualización:** 2024  
**Versión:** 1.0
