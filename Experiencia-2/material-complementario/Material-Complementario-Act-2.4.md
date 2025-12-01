# Material Complementario - Actividad 2.4
## Análisis de Tráfico y Defensa Activa

**Asignatura:** CUY5132 - Comunicaciones Unificadas  
**Experiencia de Aprendizaje:** EA 2 - Seguridad Perimetral e Integración de Servicios  
**Duración:** 3-4 horas pedagógicas

---

## 1. Cheat Sheet de Comandos

### Comandos de sngrep

```bash
# Instalar sngrep
sudo apt install sngrep -y

# Iniciar captura básica
sudo sngrep

# Capturar en interfaz específica
sudo sngrep -d eth0

# Capturar solo puerto específico
sudo sngrep port 5060

# Capturar y guardar a archivo
sudo sngrep -O captura.pcap

# Leer archivo existente
sngrep -I archivo.pcap

# Filtrar por IP
sudo sngrep host 10.0.1.100

# Filtrar por método SIP
sudo sngrep 'method == INVITE'
```

**Teclas útiles en sngrep:**
- `F1`: Ayuda
- `F2`: Guardar captura
- `F3`: Buscar
- `F7`: Filtros
- `Enter`: Ver detalles de llamada
- `F4`: Diagrama de flujo extendido
- `q`: Salir

### Comandos de Wireshark (tshark - CLI)

```bash
# Capturar SIP en CLI
sudo tshark -i any -f "port 5060"

# Capturar y guardar
sudo tshark -i any -f "port 5060" -w captura.pcap

# Leer y filtrar SIP
tshark -r captura.pcap -Y sip

# Mostrar solo métodos INVITE
tshark -r captura.pcap -Y "sip.Method == INVITE"

# Estadísticas de llamadas SIP
tshark -r captura.pcap -q -z sip,stat

# Extraer números llamados
tshark -r captura.pcap -Y sip.Method==INVITE -T fields -e sip.to.user

# Analizar RTP
tshark -r captura.pcap -Y rtp -q -z rtp,streams
```

### Comandos de fail2ban

```bash
# Instalar fail2ban
sudo apt install fail2ban -y

# Estado del servicio
sudo systemctl status fail2ban

# Ver jails activos
sudo fail2ban-client status

# Ver IPs baneadas en jail específico
sudo fail2ban-client status kamailio

# Desbanear IP manualmente
sudo fail2ban-client set kamailio unbanip IP_ADDRESS

# Ver logs de fail2ban
sudo tail -f /var/log/fail2ban.log

# Testear regex de filtro
fail2ban-regex /var/log/syslog /etc/fail2ban/filter.d/kamailio.conf
```

### Comandos de Análisis de Logs

```bash
# Buscar intentos de REGISTER fallidos
sudo grep "401 Unauthorized" /var/log/syslog | wc -l

# IPs con más intentos fallidos
sudo grep "401 Unauthorized" /var/log/syslog | \
  grep -oP '\d+\.\d+\.\d+\.\d+' | sort | uniq -c | sort -rn | head -10

# Buscar escaneo de puertos (OPTIONS flood)
sudo grep "OPTIONS" /var/log/syslog | wc -l

# Análisis de tráfico por método SIP
sudo grep -E "INVITE|REGISTER|BYE|ACK|CANCEL" /var/log/syslog | \
  awk '{print $NF}' | sort | uniq -c

# Ver últimos errores SIP
sudo journalctl -u kamailio | grep -i error | tail -20
```

---

## 2. Glosario Técnico

| Término | Español | Definición |
|---------|---------|------------|
| **Wireshark** | - | Analizador de protocolos de red (GUI) |
| **tshark** | - | Versión CLI de Wireshark |
| **sngrep** | - | Analizador SIP en tiempo real (CLI) |
| **PCAP** | Packet Capture | Formato de archivo de captura |
| **fail2ban** | - | Sistema de prevención de intrusiones |
| **jail** | Cárcel | Contenedor de reglas fail2ban |
| **bantime** | Tiempo de baneo | Duración del bloqueo IP |
| **findtime** | Tiempo de búsqueda | Ventana de tiempo para contar fallos |
| **maxretry** | Máximo reintentos | Intentos permitidos antes de ban |
| **SIP Scanner** | - | Herramienta que busca servidores SIP |
| **Brute Force** | Fuerza bruta | Ataque por prueba y error |
| **DoS** | Denial of Service | Ataque de denegación de servicio |
| **DDoS** | Distributed DoS | DoS desde múltiples fuentes |
| **VoIP Fraud** | Fraude VoIP | Uso no autorizado del sistema |

---

## 3. Filtros de Wireshark/tshark

### Filtros de Visualización (Display Filters)

```wireshark
# Filtros SIP
sip                          # Todo el tráfico SIP
sip.Method == "INVITE"       # Solo INVITEs
sip.Method == "REGISTER"     # Solo REGISTERs
sip.Status-Code == 200       # Solo respuestas 200 OK
sip.Status-Code >= 400       # Solo errores 4xx/5xx

# Filtrar por IP
ip.src == 192.168.1.100      # Tráfico desde esta IP
ip.dst == 10.0.2.10          # Tráfico hacia esta IP
ip.addr == 192.168.1.100     # Tráfico desde/hacia esta IP

# Filtros RTP
rtp                          # Todo RTP
rtp.ssrc == 0x12345678       # SSRC específico
rtp.p_type == 0              # Solo codec PCMU

# Filtros TLS
tls                          # Todo TLS
tls.handshake                # Solo handshakes TLS
tls.handshake.type == 1      # Solo ClientHello

# Combinaciones lógicas
sip && ip.src == 10.0.1.1    # SIP desde IP específica
sip.Method == "INVITE" || sip.Method == "BYE"
!(sip.Method == "OPTIONS")   # Todo excepto OPTIONS
```

### Filtros de Captura (Capture Filters)

```tcpdump
# Sintaxis tcpdump/BPF
port 5060                    # SIP (puerto 5060)
port 5061                    # TLS (puerto 5061)
portrange 10000-20000        # RTP
host 192.168.1.100           # Tráfico desde/hacia IP
src host 192.168.1.100       # Solo desde IP
dst host 10.0.2.10           # Solo hacia IP

# Combinaciones
port 5060 or portrange 10000-20000     # SIP + RTP
tcp port 5061                          # Solo TLS (TCP)
udp port 5060                          # Solo SIP sin TLS
```

---

## 4. Anatomía de una Captura VoIP en Wireshark

### Análisis de Llamada Completa

**Paso 1: Filtrar llamada específica**
```
1. Filtro: sip
2. Buscar INVITE inicial
3. Click derecho → Follow → SIP Call
4. Wireshark mostrará solo paquetes de esa llamada
```

**Paso 2: Ver diagrama de flujo**
```
1. Telephony → VoIP Calls
2. Seleccionar llamada
3. Click "Flow Sequence"
4. Ver diagrama visual completo
```

**Paso 3: Analizar RTP**
```
1. Telephony → RTP → RTP Streams
2. Seleccionar stream de audio
3. Click "Analyze"
4. Ver estadísticas:
   - Packet Loss %
   - Max Jitter
   - Mean Jitter
   - Problems (banderas rojas)
```

**Paso 4: Reproducir audio** (solo RTP sin cifrar)
```
1. Telephony → RTP → RTP Streams
2. Seleccionar stream
3. Click "Play Streams"
4. Escuchar calidad de audio
```

---

## 5. Diagrama: Flujo de Análisis con sngrep

```
Terminal con sngrep
┌─────────────────────────────────────────────────────────────┐
│ Call List                                             [F1] Help│
├─────────────────────────────────────────────────────────────┤
│ │Idx│ Method │      Src      │     Dst       │   State      │
│ ├───┼────────┼───────────────┼───────────────┼──────────────┤
│ │ 1 │ INVITE │ 192.168.1.5   │ 10.0.2.10    │  Completed   │
│ │ 2 │ REGISTER│ 192.168.1.6  │ 10.0.2.10    │  Completed   │
│ │ 3 │ INVITE │ 192.168.1.5   │ 10.0.2.10    │  In Progress │
└─────────────────────────────────────────────────────────────┘
         │
         │ [Enter] Ver detalles
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Call Flow                                                    │
├─────────────────────────────────────────────────────────────┤
│ 192.168.1.5         Kamailio        Asterisk   192.168.1.6 │
│     │                  │                │           │        │
│     │─INVITE──────────>│                │           │        │
│     │                  │─INVITE────────>│           │        │
│     │                  │                │─INVITE───>│        │
│     │                  │                │<─180─────│        │
│     │                  │<─180──────────│           │        │
│     │<─180────────────│                │           │        │
│     │                  │                │<─200 OK──│        │
│     │<─200 OK─────────│<─200 OK───────│           │        │
│     │─ACK─────────────>│─ACK──────────>│─ACK──────>│        │
│     │<══════════════RTP═══════════════════════════>│        │
└─────────────────────────────────────────────────────────────┘
         │
         │ [F4] Detalles extendidos
         ▼
Muestra headers SIP completos, SDP, etc.
```

---

## 6. Ataques Comunes VoIP y Detección

### 1. Brute Force Registration

**Descripción:** Atacante intenta adivinar credenciales probando muchas contraseñas.

**Patrón en logs:**
```
Multiple 401 Unauthorized from same IP
IP: 203.0.113.50
Timestamps within short timespan (< 1 minute)
```

**Detección:**
```bash
# Contar intentos 401 por IP
grep "401 Unauthorized" /var/log/syslog | \
  grep -oP '\d+\.\d+\.\d+\.\d+' | \
  sort | uniq -c | sort -rn

# Ejemplo resultado:
# 150 203.0.113.50  ← Sospechoso!
#   5 192.168.1.100 ← Normal
```

**Defensa:**
- fail2ban con jail kamailio
- Rate limiting en Kamailio
- IPs whitelisting

### 2. SIP Scanner (OPTIONS Flood)

**Descripción:** Herramientas como sipvicious escanean buscando servidores SIP.

**Patrón:**
```
Muchos OPTIONS de misma IP
User-Agent: "friendly-scanner" o similar
No sigue con REGISTER/INVITE
```

**Detección en Kamailio:**
```python
# En kamailio.cfg
if (is_method("OPTIONS")) {
    if ($ua =~ "(friendly-scanner|sipvicious|sipcli)") {
        xlog("L_WARN", "Scanner detected: $si - $ua\n");
        exit;
    }
}
```

### 3. INVITE Flood (DoS)

**Descripción:** Envío masivo de INVITEs para saturar el servidor.

**Patrón:**
```
Cientos de INVITEs por segundo
Desde misma IP o múltiples IPs (DDoS)
Números aleatorios o inexistentes
```

**Defensa:**
```python
# Rate limiting en Kamailio
loadmodule "pike.so"

modparam("pike", "sampling_time_unit", 2)
modparam("pike", "reqs_density_per_unit", 30)  # Max 30 req/2s

route {
    if (!pike_check_req()) {
        xlog("L_ALERT", "FLOOD from $si\n");
        exit;
    }
}
```

### 4. Call Hijacking

**Descripción:** Atacante intercepta Call-ID y secuestra llamada.

**Patrón:**
```
BYE desde IP diferente a la original
Call-ID válido pero dirección sospechosa
```

**Defensa:**
- TLS (previene sniffing de Call-ID)
- Validar dirección de origen
- Autenticación estricta

---

## 7. Configuración de fail2ban para Kamailio

### Archivo: /etc/fail2ban/jail.local

```ini
[DEFAULT]
# Configuración global
bantime = 3600        # 1 hora de baneo
findtime = 600        # Ventana de 10 minutos
maxretry = 5          # Máximo 5 intentos

# Acción al banear (iptables)
banaction = iptables-multiport
action = %(action_mwl)s  # Ban + email + whois

[kamailio]
enabled = true
port = 5060,5061
protocol = udp
filter = kamailio
logpath = /var/log/syslog
maxretry = 3          # Solo 3 intentos para Kamailio
bantime = 7200        # 2 horas
```

### Archivo: /etc/fail2ban/filter.d/kamailio.conf

```ini
[Definition]

# Patrón para detectar intentos fallidos
failregex = ^.* kamailio.*\[WARN\].*401 Unauthorized.*from.*<HOST>
            ^.* kamailio.*authentication failed for.*<HOST>
            ^.* kamailio.*REGISTER.*401.*<HOST>

# Líneas a ignorar
ignoreregex = 
```

### Activar fail2ban

```bash
# Habilitar e iniciar
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verificar jail activo
sudo fail2ban-client status kamailio

# Ver IPs baneadas
sudo fail2ban-client status kamailio | grep "Banned IP"

# Ver logs
sudo tail -f /var/log/fail2ban.log
```

---

## 8. Análisis de Calidad de Llamada (QoS)

### Métricas Clave

| Métrica | Descripción | Valor Óptimo | Impacto si excede |
|---------|-------------|--------------|-------------------|
| **Latencia** | Retardo end-to-end | < 150 ms | Eco, conversación lenta |
| **Jitter** | Variación del retardo | < 30 ms | Audio entrecortado |
| **Packet Loss** | % paquetes perdidos | < 1% | Audio con huecos |
| **MOS** | Mean Opinion Score | > 4.0 | Calidad perceptual baja |

### Análisis con Wireshark

```
1. Telephony → RTP → RTP Streams
2. Seleccionar stream
3. Analyze

Métricas mostradas:
┌────────────────────────────────────┐
│ Stream Statistics                  │
├────────────────────────────────────┤
│ Packets: 1500                      │
│ Lost: 15 (1.0%)          ← ⚠️ OK  │
│ Max Jitter: 45 ms        ← ⚠️ Alto│
│ Mean Jitter: 12 ms       ← ✓ OK   │
│ Max Delta: 102 ms                  │
│ Problems: Yes (Jitter)   ← ⚠️ Ver │
└────────────────────────────────────┘
```

### Causas Comunes de Problemas QoS

| Problema | Síntoma | Causa Probable |
|----------|---------|----------------|
| Jitter alto | Audio entrecortado | Congestión de red |
| Packet loss | Huecos en audio | Pérdida de paquetes UDP |
| Latencia alta | Eco, delay | Ruta de red larga |
| One-way audio | Solo escucha 1 parte | Firewall/NAT |

---

## 9. Configuración de Logging en Kamailio

### Niveles de Log

```python
# En kamailio.cfg

# Nivel de debug
debug=3  # 0=mínimo, 4=máximo debug

# Facility de syslog
log_facility=LOG_LOCAL0

# Logging personalizado
xlog("L_INFO", "Llamada de $fU a $tU - Call-ID: $ci\n");
xlog("L_WARN", "Intento de auth falló: $si\n");
xlog("L_ERR", "Error crítico: $var(error)\n");
```

### Rotación de Logs

```bash
# Configurar logrotate
sudo nano /etc/logrotate.d/kamailio
```

```
/var/log/kamailio/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /usr/sbin/invoke-rc.d kamailio reload > /dev/null
    endscript
}
```

---

## 10. Preguntas Frecuentes (FAQ)

### P1: ¿Cuál es mejor: Wireshark o sngrep?

**R:**
- **Wireshark:** Análisis profundo, todos los protocolos, GUI
- **sngrep:** Análisis rápido SIP, CLI, más ágil
- **Recomendación:** sngrep para troubleshooting diario, Wireshark para análisis forense

### P2: ¿Por qué Wireshark no puede reproducir audio SRTP?

**R:** SRTP está cifrado. Wireshark no tiene las claves de cifrado, por lo que no puede descifrar el audio.

### P3: fail2ban no está baneando IPs, ¿por qué?

**R:** Verificar:
```bash
# 1. El regex funciona?
fail2ban-regex /var/log/syslog /etc/fail2ban/filter.d/kamailio.conf

# 2. Kamailio logea donde espera fail2ban?
grep "401 Unauthorized" /var/log/syslog

# 3. El jail está activo?
sudo fail2ban-client status
```

### P4: ¿Cómo exporto captura de sngrep para análisis con Wireshark?

**R:**
```bash
# Durante captura en sngrep:
F2 → Guardar → archivo.pcap

# Luego abrir con:
wireshark archivo.pcap
```

### P5: ¿Puedo analizar tráfico TLS en Wireshark?

**R:** Sí, pero:
- Solo verás "TLS Application Data" (cifrado)
- NO verás contenido SIP
- Para debugging, usar logs de Kamailio en lugar de captura

### P6: ¿Cómo identifico un ataque de fuerza bruta en progreso?

**R:**
```bash
# Ver intentos recientes (últimos 5 min)
sudo grep "401 Unauthorized" /var/log/syslog | tail -100

# Si ves MUCHOS de misma IP = ataque
# Banear manualmente:
sudo fail2ban-client set kamailio banip IP_ATACANTE
```

### P7: Mi captura .pcap es muy grande, ¿cómo filtrarla?

**R:**
```bash
# Filtrar solo SIP:
tshark -r grande.pcap -Y sip -w solo-sip.pcap

# Filtrar por IP:
tshark -r grande.pcap -Y "ip.addr == 192.168.1.100" -w filtrada.pcap
```

### P8: ¿Qué significa MOS en análisis de audio?

**R:** Mean Opinion Score: calificación subjetiva de calidad
- 5 = Excelente
- 4 = Buena
- 3 = Aceptable
- 2 = Pobre
- 1 = Mala

### P9: ¿Cómo automatizo análisis de calidad?

**R:** Usar tshark con scripts:
```bash
#!/bin/bash
tshark -r captura.pcap -q -z rtp,streams > analisis.txt
grep "Lost" analisis.txt
```

### P10: ¿fail2ban protege contra DDoS?

**R:** Parcialmente. fail2ban es efectivo contra:
- ✓ Brute force desde pocas IPs
- ✗ DDoS masivo (miles de IPs)

Para DDoS necesitas soluciones más robustas (CloudFlare, firewall hardware).

---

## 11. Checklist de Verificación Lab 2.4

### Instalación de Herramientas
- [ ] Wireshark instalado (GUI o tshark)
- [ ] sngrep instalado
- [ ] fail2ban instalado y corriendo
- [ ] tcpdump disponible

### Configuración fail2ban
- [ ] Jail kamailio creado en jail.local
- [ ] Filtro kamailio creado en filter.d/
- [ ] Regex testeado con fail2ban-regex
- [ ] fail2ban habilitado y corriendo
- [ ] Jail kamailio activo

### Captura y Análisis
- [ ] Captura SIP realizada con sngrep
- [ ] Captura SIP+RTP realizada con tcpdump
- [ ] Archivo .pcap analizado en Wireshark
- [ ] Flujo de llamada visualizado
- [ ] Estadísticas RTP revisadas
- [ ] Calidad de audio evaluada

### Logs y Monitoreo
- [ ] Logs de Kamailio accesibles
- [ ] Logging level apropiado (debug=3)
- [ ] xlog statements útiles agregados
- [ ] Logrotate configurado

### Seguridad
- [ ] Intentos de autenticación fallidos detectados
- [ ] IP sospechosa identificada y baneada
- [ ] fail2ban baneó IPs automáticamente
- [ ] Logs de fail2ban revisados

---

## 12. Ejercicios Adicionales

### Ejercicio 1: Simular Ataque y Defensa

1. Desde otra máquina, intenta REGISTER con credenciales incorrectas 5 veces
2. Observa logs: `sudo tail -f /var/log/syslog | grep kamailio`
3. Verifica que fail2ban banee la IP
4. Intenta REGISTER de nuevo (debe fallar)
5. Desbanea manualmente: `sudo fail2ban-client set kamailio unbanip IP`

### Ejercicio 2: Análisis de Calidad Completo

1. Hacer llamada de 2 minutos
2. Capturar con: `sudo tcpdump -i any -n 'portrange 10000-20000' -w call.pcap`
3. Abrir en Wireshark
4. Analizar RTP streams
5. Documentar:
   - Packet Loss %
   - Max/Mean Jitter
   - Problemas detectados
   - MOS score

### Ejercicio 3: Crear Filtro Personalizado fail2ban

Crea filtro para detectar escaneo de puertos (OPTIONS flood):

```ini
# /etc/fail2ban/filter.d/kamailio-scan.conf
[Definition]
failregex = ^.* kamailio.*OPTIONS.*<HOST>
maxretry = 20   # Permitir algunos OPTIONS, pero no flood
findtime = 60
bantime = 1800
```

### Ejercicio 4: Automatizar Reportes de Seguridad

Script para reporte diario:
```bash
#!/bin/bash
echo "=== Reporte de Seguridad VoIP ==="
echo "Fecha: $(date)"
echo ""
echo "IPs baneadas:"
sudo fail2ban-client status kamailio | grep "Banned IP"
echo ""
echo "Top 10 IPs con intentos fallidos:"
sudo grep "401" /var/log/syslog | \
  grep -oP '\d+\.\d+\.\d+\.\d+' | \
  sort | uniq -c | sort -rn | head -10
```

---

## 13. Caso de Estudio

### Escenario: Detección de Fraude VoIP

**Contexto:**
- Empresa "GlobalCom" ofrece servicio VoIP
- Detectan llamadas internacionales anómalas
- Factura inesperada de $5,000 USD
- Sospechan de cuenta comprometida

**Evidencia:**
```
Call logs muestran:
- 500 llamadas a números premium (zona 900)
- Todas desde misma cuenta (ext 2045)
- En horario nocturno (2AM - 5AM)
- Usuario legítimo estaba de vacaciones
```

**Tu misión:**
1. Analizar logs para encontrar el vector de ataque
2. Identificar si fue brute force o credential leak
3. Proponer controles preventivos
4. Diseñar sistema de alertas tempranas

**Preguntas:**
- ¿Qué patrón buscarías en los logs?
- ¿Cómo detectarías esto en tiempo real?
- ¿Qué reglas fail2ban implementarías?
- ¿Cómo prevendrías llamadas a números premium?

---

## 14. Herramientas de Análisis Avanzado

### VoIPmonitor

Open source call monitoring:
```bash
# Características:
- Grabación de llamadas
- Análisis de calidad (MOS)
- Detección de fraude
- Dashboard web
```

### Homer SIP Capture

Plataforma de captura y análisis:
```bash
# Características:
- Captura distribuida
- Correlación de llamadas
- Búsqueda avanzada
- Visualización
```

### Kamailio Stats

Built-in statistics:
```bash
# Ver estadísticas en tiempo real
kamcmd stats.get_statistics all

# Métricas útiles:
- core:rcv_requests  # Requests recibidos
- core:fwd_requests  # Requests reenviados
- tm:2xx_transactions # Transacciones exitosas
- tm:4xx_transactions # Errores cliente
- tm:5xx_transactions # Errores servidor
```

---

## 15. Mejores Prácticas de Seguridad

### Checklist de Hardening

**A nivel de Kamailio:**
- [ ] Deshabilitar métodos SIP innecesarios (INFO, MESSAGE)
- [ ] Implementar rate limiting (pike module)
- [ ] Filtrar User-Agent sospechosos
- [ ] Validar formato de Request-URI
- [ ] Implementar IP whitelist para admin
- [ ] Ocultar versión de Kamailio

**A nivel de Red:**
- [ ] Firewall configurado (solo puertos necesarios)
- [ ] fail2ban activo y monitoreado
- [ ] IPs públicas documentadas
- [ ] VPN para acceso administrativo
- [ ] Segmentación de red (DMZ para SBC)

**A nivel de Sistema:**
- [ ] Actualizaciones de seguridad automáticas
- [ ] Passwords complejos y rotados
- [ ] Logs centralizados
- [ ] Backups regulares
- [ ] Monitoreo proactivo (alertas)

### Ejemplo de Rate Limiting

```python
# Limitar REGISTER a 5 por minuto por IP
loadmodule "htable.so"

modparam("htable", "htable", "reg=>size=8;")

route {
    if (is_method("REGISTER")) {
        $var(key) = $si;
        
        if ($sht(reg=>$var(key)) == $null) {
            $sht(reg=>$var(key)) = 1;
        } else {
            $sht(reg=>$var(key)) = $sht(reg=>$var(key)) + 1;
        }
        
        if ($sht(reg=>$var(key)) > 5) {
            xlog("L_WARN", "Rate limit exceeded: $si\n");
            sl_send_reply("503", "Too Many Requests");
            exit;
        }
    }
}
```

---

## 16. Recursos Adicionales

### Documentación
- [Wireshark Display Filters](https://wiki.wireshark.org/DisplayFilters)
- [sngrep Documentation](https://github.com/irontec/sngrep/wiki)
- [fail2ban Manual](https://fail2ban.readthedocs.io/)

### Herramientas Online
- [PacketLife Cheat Sheets](https://packetlife.net/library/cheat-sheets/)
- [VoIP Security Checklist](https://www.voip-info.org/voip-security-checklist/)

### Comunidades
- [Wireshark Q&A](https://ask.wireshark.org/)
- [Kamailio Users List](https://lists.kamailio.org/)
- [VoIP Security Alliance](https://voipsecurityalliance.org/)

---

**Última actualización:** 2024  
**Versión:** 1.0
