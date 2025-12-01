# Material Complementario - Actividad 2.3
## Implementación de Cifrado (TLS/SRTP)

**Asignatura:** CUY5132 - Comunicaciones Unificadas  
**Experiencia de Aprendizaje:** EA 2 - Seguridad Perimetral e Integración de Servicios  
**Duración:** 3-4 horas pedagógicas

---

## 1. Cheat Sheet de Comandos

### Comandos de Certificados (OpenSSL)

```bash
# Generar certificado autofirmado
openssl req -x509 -newkey rsa:4096 -keyout kamailio-key.pem \
  -out kamailio-cert.pem -days 365 -nodes \
  -subj "/CN=IP_PUBLICA/O=DUOC/C=CL"

# Ver contenido de certificado
openssl x509 -in kamailio-cert.pem -text -noout

# Ver fechas de validez
openssl x509 -in kamailio-cert.pem -noout -dates

# Verificar certificado y clave coinciden
openssl x509 -noout -modulus -in kamailio-cert.pem | openssl md5
openssl rsa -noout -modulus -in kamailio-key.pem | openssl md5
# Si los hash MD5 coinciden = OK ✓

# Probar conexión TLS a servidor
openssl s_client -connect IP_PUBLICA:5061 -showcerts

# Verificar cipher suites soportados
openssl s_client -connect IP_PUBLICA:5061 -cipher 'HIGH:!aNULL:!MD5'
```

### Comandos de Verificación TLS

```bash
# Verificar que Kamailio escucha en 5061 TCP
sudo netstat -tulpn | grep 5061
sudo ss -tlpn | grep 5061

# Probar handshake TLS
echo | openssl s_client -connect IP_PUBLICA:5061 2>/dev/null | \
  grep -E 'subject=|issuer=|Verify'

# Ver cifrado negociado
echo | openssl s_client -connect IP_PUBLICA:5061 2>/dev/null | \
  grep "Cipher"

# Capturar tráfico TLS
sudo tcpdump -i any -n 'tcp port 5061' -w tls.pcap

# Verificar handshake TLS en logs
sudo tail -f /var/log/syslog | grep -i tls
```

### Comandos de Verificación SRTP

```bash
# En Asterisk CLI, verificar que endpoint tiene SRTP
sudo asterisk -rvvv
pjsip show endpoint 1001

# Debe mostrar:
#  media_encryption : sdes
#  media_encryption_optimistic : no

# Capturar tráfico cifrado (SRTP)
sudo tcpdump -i any -n 'portrange 10000-20000' -w srtp.pcap

# En Wireshark, verificar:
# - Paquetes aparecen como "RTP" pero contenido ilegible
# - NO se puede reproducir audio (está cifrado)
```

### Comandos de Diagnóstico de Seguridad

```bash
# Escanear puertos TLS abiertos
nmap -sT -p 5061 IP_PUBLICA

# Probar versiones TLS soportadas
nmap --script ssl-enum-ciphers -p 5061 IP_PUBLICA

# Verificar que NO acepta conexiones sin TLS
telnet IP_PUBLICA 5061
# Debería mostrar caracteres extraños (TLS) no SIP legible
```

---

## 2. Glosario Técnico TLS/SRTP

| Término | Español | Definición |
|---------|---------|------------|
| **TLS** | Transport Layer Security | Protocolo de seguridad para cifrar transporte |
| **SSL** | Secure Sockets Layer | Predecesor de TLS (obsoleto) |
| **SRTP** | Secure Real-time Transport Protocol | RTP con cifrado y autenticación |
| **SDES** | Security Descriptions | Método de intercambio de claves SRTP via SDP |
| **DTLS** | Datagram TLS | TLS sobre UDP (alternativa a SDES) |
| **Certificate** | Certificado digital | Documento que verifica identidad |
| **CA** | Certificate Authority | Autoridad que firma certificados |
| **Self-signed** | Autofirmado | Certificado firmado por sí mismo (no CA) |
| **CN** | Common Name | Nombre en certificado (IP o dominio) |
| **Handshake** | Apretón de manos | Negociación TLS inicial |
| **Cipher Suite** | Suite de cifrado | Conjunto de algoritmos para cifrado |
| **AES** | Advanced Encryption Standard | Algoritmo de cifrado simétrico |
| **RSA** | Rivest-Shamir-Adleman | Algoritmo de cifrado asimétrico |
| **SIPS** | SIP Secure | URI SIP sobre TLS (sips:) |
| **End-to-end** | Extremo a extremo | Cifrado desde origen hasta destino |

---

## 3. Fundamentos de Criptografía

### Cifrado Simétrico vs Asimétrico

**Cifrado Simétrico (AES):**
```
Emisor                                    Receptor
  |                                          |
  |-- Mensaje + Clave Secreta (K) -------->  |
  |   Texto cifrado con K                    |
  |                                          |
  |                Clave K debe ser          |
  |                compartida previamente    |
```
- **Ventaja:** Muy rápido
- **Desventaja:** Cómo compartir la clave de forma segura?

**Cifrado Asimétrico (RSA):**
```
Receptor genera par de claves:
  - Clave Pública (compartida con todos)
  - Clave Privada (secreta, nunca sale)

Emisor                                    Receptor
  |                                          |
  |<------- Clave Pública -----------------  |
  |                                          |
  |-- Cifrado con Clave Pública ---------->  |
  |   (solo Clave Privada puede descifrar)   |
  |                                          |
  |                                  Descifra con
  |                                  Clave Privada
```
- **Ventaja:** No necesita compartir secretos
- **Desventaja:** Más lento que simétrico

### ¿Cómo TLS Combina Ambos?

```
1. Handshake TLS (Asimétrico - RSA):
   - Cliente y servidor negocian
   - Usan certificados (RSA) para autenticarse
   - Generan clave de sesión compartida

2. Datos de Aplicación (Simétrico - AES):
   - Usan la clave de sesión (AES)
   - Cifrado rápido del contenido
```

**Resultado:** Seguridad de asimétrico + velocidad de simétrico.

---

## 4. Diagrama: Handshake TLS

```
Softphone                                    Kamailio (TLS Server)
    |                                              |
    |--------ClientHello-------------------------->|
    |  - Versiones TLS soportadas                  |
    |  - Cipher suites preferidos                  |
    |  - Número aleatorio                          |
    |                                              |
    |<-------ServerHello---------------------------|
    |  - Versión TLS elegida (TLS 1.2)             |
    |  - Cipher suite elegido                      |
    |  - Número aleatorio                          |
    |                                              |
    |<-------Certificate (kamailio-cert.pem)-------|
    |  - Certificado del servidor                  |
    |  - Clave pública incluida                    |
    |                                              |
    |<-------ServerHelloDone-----------------------|
    |  - Servidor termina su parte                 |
    |                                              |
    |--------ClientKeyExchange--------------------->|
    |  - Pre-master secret (cifrado con            |
    |    clave pública del servidor)               |
    |                                              |
    |--------ChangeCipherSpec--------------------->|
    |  - "A partir de ahora, todo cifrado"         |
    |                                              |
    |--------Finished (cifrado)-------------------->|
    |  - Hash de todos los mensajes previos        |
    |                                              |
    |<-------ChangeCipherSpec----------------------|
    |<-------Finished (cifrado)--------------------|
    |                                              |
    |============ CANAL CIFRADO ESTABLECIDO ======|
    |                                              |
    |<======== Tráfico SIP cifrado ===============>|
    |                                              |
```

**Resultado:** 
- Canal seguro
- Servidor autenticado
- Mensajes SIP cifrados con AES

---

## 5. Anatomía de un Certificado X.509

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 123456                        ← Número único
        Signature Algorithm: sha256WithRSAEncryption ← Algoritmo
    Validity
        Not Before: Jan  1 00:00:00 2024 GMT        ← Válido desde
        Not After : Jan  1 23:59:59 2025 GMT        ← Válido hasta
    Subject: CN=200.100.100.1, O=DUOC, C=CL         ← Identidad
        Common Name (CN): 200.100.100.1              ← ⚠️ CRÍTICO
        Organization (O): DUOC
        Country (C): CL
    Subject Public Key Info:                        ← Clave pública
        Public Key Algorithm: rsaEncryption
        RSA Public-Key: (4096 bit)
        Modulus: 00:a1:b2:c3... (512 bytes)
        Exponent: 65537 (0x10001)
    X509v3 extensions:
        X509v3 Subject Alternative Name:
            IP Address:200.100.100.1                 ← IPs alternativas
    Signature Algorithm: sha256WithRSAEncryption     ← Firma digital
        12:34:56:78:9a:bc... (512 bytes)
```

**Campo más importante:** `CN` (Common Name)
- **DEBE** coincidir con la IP/dominio al que te conectas
- Si te conectas a `200.100.100.1`, el CN debe ser `200.100.100.1`
- Si no coincide, cliente rechazará la conexión (o mostrará warning)

---

## 6. Flujo Completo: SIP con TLS + RTP con SRTP

```
Softphone         Kamailio (TLS+RTPProxy)         Asterisk (TLS+SRTP)
    |                      |                              |
    |--INVITE (TLS)------->|                              |
    | sips:1002@domain     |                              |
    | SDP: crypto SDES     |                              |
    |                      |--INVITE (TLS)--------------->|
    |                      | SDP modificado por RTPProxy  |
    |                      |    crypto SDES preservado    |
    |                      |                              |
    |                      |<------200 OK (TLS)-----------|
    |                      | SDP: crypto SDES             |
    |<-----200 OK (TLS)----|                              |
    | SDP modificado       |                              |
    |                      |                              |
    |===SRTP (AES cifrado)====>RTPProxy==SRTP (AES cifrado)====>
    |   (no legible)       |   (relay)   |  (no legible)  |
    |<==SRTP===============<==RTPProxy===<==SRTP=========|
    |                      |                              |
    |         ✅ COMUNICACIÓN COMPLETAMENTE CIFRADA ✅    |
    |         - Señalización: TLS (puerto 5061)           |
    |         - Medios: SRTP (AES-128)                    |
```

**Capas de seguridad:**
1. **TLS:** Cifra SIP (INVITE, 200 OK, etc.)
2. **SRTP:** Cifra audio (paquetes RTP)

---

## 7. Configuración TLS en Kamailio

### Archivo: kamailio.cfg - Sección TLS

```python
#!KAMAILIO

####### TLS Configuration #########

# Habilitar TLS
#!define WITH_TLS

# Directorio de certificados
#!define TLS_DIR "/etc/kamailio/tls"

####### Load TLS Module ########

loadmodule "tls.so"

# Parámetros TLS
modparam("tls", "config", "/etc/kamailio/tls.cfg")
modparam("tls", "tls_method", "TLSv1.2+")      # TLS 1.2 o superior
modparam("tls", "verify_certificate", 0)        # No verificar (autofirmado)
modparam("tls", "require_certificate", 0)       # No requerir cert de cliente

####### Listening Interfaces ########

# Escuchar en UDP (normal)
listen=udp:0.0.0.0:5060

# Escuchar en TLS
listen=tls:0.0.0.0:5061
```

### Archivo: /etc/kamailio/tls.cfg

```ini
[server:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
private_key = /etc/kamailio/tls/kamailio-key.pem
certificate = /etc/kamailio/tls/kamailio-cert.pem
ca_list = /etc/kamailio/tls/ca-cert.pem

# Cipher suites (solo seguros)
cipher_list = HIGH:!aNULL:!MD5:!RC4

[client:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
```

**Explicación:**
- `method = TLSv1.2+`: Acepta TLS 1.2 y 1.3 (NO TLS 1.0/1.1 inseguros)
- `verify_certificate = no`: Acepta cert autofirmados (solo para labs)
- `cipher_list`: Solo algoritmos seguros (no MD5, no RC4)

---

## 8. Configuración SRTP en Asterisk

### Archivo: pjsip.conf - Transport TLS

```ini
;========== TRANSPORT TLS ==========
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
ca_list_file=/etc/asterisk/keys/ca.crt
method=tlsv1_2        ; TLS 1.2 mínimo
cipher=HIGH:!aNULL    ; Solo ciphers seguros
verify_server=no      ; No verificar (autofirmado)
verify_client=no      ; No verificar cliente
```

### Archivo: pjsip.conf - Endpoint con SRTP

```ini
;========== PLANTILLA CON SRTP ==========
[endpoint_template](!)
type=endpoint
context=default
transport=transport-tls                  ; Usar transport TLS ⚠️
media_encryption=sdes                    ; SRTP via SDES ⚠️
media_encryption_optimistic=no           ; Requiere SRTP estricto
disallow=all
allow=ulaw
allow=alaw
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes

;========== EXTENSIONES ==========
[1001](endpoint_template)
type=endpoint
auth=auth1001
aors=1001
; Hereda media_encryption=sdes de template
```

**Parámetros clave:**
- `transport=transport-tls`: Fuerza TLS para señalización
- `media_encryption=sdes`: Activa SRTP con intercambio SDES
- `media_encryption_optimistic=no`: Rechaza llamadas sin SRTP

---

## 9. Intercambio de Claves SDES

### ¿Qué es SDES?

**SDES (Security Descriptions):**
- Método para intercambiar claves SRTP
- Claves viajan en SDP (dentro de mensajes SIP)
- **Requiere** que SIP esté cifrado con TLS

### SDP con crypto (SDES)

```
v=0
o=user 123 456 IN IP4 200.100.100.1
s=Call
c=IN IP4 200.100.100.1
t=0 0
m=audio 15000 RTP/SAVP 0 8                        ← SAVP (no AVP)
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=crypto:1 AES_CM_128_HMAC_SHA1_80 \              ← Línea crypto
  inline:aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789==|2^31
```

**Explicación línea crypto:**
- `1`: Tag (identificador)
- `AES_CM_128_HMAC_SHA1_80`: Suite de cifrado
  - AES_CM_128: Cifrado AES de 128 bits
  - HMAC_SHA1_80: Autenticación con SHA1 (80 bits)
- `inline:...`: Clave maestra (base64) y salt

### Flujo de Intercambio

```
1. Softphone genera clave SRTP aleatoria
2. Incluye clave en SDP (línea a=crypto)
3. Envía INVITE con SDP (dentro de TLS)
4. Asterisk recibe, genera su propia clave
5. Responde 200 OK con su clave SRTP (en TLS)
6. Ambos derivan claves de sesión
7. Audio cifrado con AES usando esas claves
```

**Crítico:** Sin TLS, las claves viajarían en texto plano = ✗ inseguro

---

## 10. Diferencias: RTP vs SRTP en Wireshark

### Paquete RTP (sin cifrar)

```
Real-Time Transport Protocol
    Version: 2
    Payload type: PCMU (0)
    Sequence number: 12345
    Timestamp: 160000
    SSRC: 0x12345678
    Payload: 0d 0e 0f 10 11 12... (audio legible)
                 ↑
            Puedes ver forma de onda
            Wireshark puede reproducir audio
```

### Paquete SRTP (cifrado)

```
Real-Time Transport Protocol
    Version: 2
    Payload type: PCMU (0)
    Sequence number: 12345
    Timestamp: 160000
    SSRC: 0x12345678
    Payload: 8a 7f 3c 9d 2e 1b... (CIFRADO - ilegible)
                 ↑
            Datos aleatorios
            NO se puede reproducir
            Wireshark muestra "[Encrypted]"
```

**Indicadores de SRTP:**
- Payload parece aleatorio (no patrones)
- Wireshark dice "Encrypted" o "SRTP"
- NO se puede reproducir audio

---

## 11. Preguntas Frecuentes (FAQ)

### P1: ¿Por qué usar TLS Y SRTP? ¿No basta con uno?

**R:** 
- **TLS** cifra señalización (SIP): quién llama, a quién, duración
- **SRTP** cifra medios (RTP): el audio/video en sí
- Necesitas ambos para seguridad completa

### P2: Mi softphone no acepta el certificado autofirmado

**R:** En el softphone:
- Desactivar verificación de certificados
- O importar el certificado manualmente
- O usar certificado de CA reconocida (ej: Let's Encrypt)

### P3: ¿Cómo sé si la llamada realmente está cifrada?

**R:** Varias formas:
1. Softphone muestra ícono de candado
2. Wireshark: SIP aparece como "TLS Application Data"
3. Wireshark: RTP aparece como "Encrypted"
4. En Asterisk CLI: `pjsip show channel` muestra "Encryption: SRTP"

### P4: Error "certificate verify failed", ¿qué hago?

**R:** 
```bash
# En kamailio.cfg o tls.cfg:
verify_certificate = no

# En pjsip.conf:
verify_server = no
verify_client = no
```
Esto es aceptable en labs con certs autofirmados.

### P5: ¿TLS hace más lenta la señalización?

**R:** Ligeramente sí, por el handshake inicial. Pero:
- Handshake solo ocurre al conectar (1 vez)
- Después, overhead es mínimo (< 5%)
- Beneficio de seguridad vale la pena

### P6: ¿SRTP usa más ancho de banda que RTP?

**R:** Muy poco más:
- RTP: 12 bytes de header
- SRTP: 12 bytes header + 10-14 bytes auth tag
- Overhead: ~10%

### P7: ¿Qué es mejor: SDES o DTLS-SRTP?

**R:** Depende:
- **SDES:** Más simple, requiere TLS para SIP
- **DTLS-SRTP:** Más complejo, no requiere TLS para SIP
- Para labs: SDES es más fácil

### P8: ¿RTPProxy puede inspeccionar audio con SRTP?

**R:** No. RTPProxy solo hace relay. No tiene las claves SRTP, así que no puede descifrar.

### P9: Mi certificado expiró, ¿qué hago?

**R:** Regenerar:
```bash
cd /etc/kamailio/tls/
openssl req -x509 -newkey rsa:4096 -keyout kamailio-key.pem \
  -out kamailio-cert.pem -days 365 -nodes \
  -subj "/CN=$(curl -s ifconfig.me)/O=DUOC/C=CL"
sudo systemctl restart kamailio
```

### P10: ¿Puedo mezclar llamadas TLS y no-TLS?

**R:** Sí, Kamailio puede escuchar en ambos:
- Puerto 5060 UDP (sin cifrado)
- Puerto 5061 TLS (cifrado)
Pero mejor forzar TLS siempre en producción.

---

## 12. Checklist de Verificación Lab 2.3

### Certificados
- [ ] Certificado Kamailio generado
- [ ] Clave privada Kamailio generada
- [ ] Certificado Asterisk generado
- [ ] Clave privada Asterisk generada
- [ ] CN coincide con IP pública
- [ ] Permisos correctos (600 para .key)

### Configuración Kamailio
- [ ] Módulo TLS cargado
- [ ] Puerto 5061 TCP en listen
- [ ] Archivo tls.cfg creado
- [ ] Rutas a certificados correctas
- [ ] Sintaxis verificada: `sudo kamailio -c`
- [ ] Kamailio escucha en 5061: `netstat -tlpn | grep 5061`

### Configuración Asterisk
- [ ] Transport TLS configurado en pjsip.conf
- [ ] Certificados en /etc/asterisk/keys/
- [ ] `media_encryption=sdes` en endpoint
- [ ] `media_encryption_optimistic=no`
- [ ] Asterisk cargó config: `pjsip reload`

### Configuración de Red
- [ ] Security Group permite 5061 TCP
- [ ] Security Group permite 5060 UDP (opcional)
- [ ] Security Group permite 10000-20000 UDP (RTP)

### Configuración Softphone
- [ ] Transport = TLS (no UDP)
- [ ] Puerto = 5061 (no 5060)
- [ ] URI = sips: (no sip:)
- [ ] SRTP activado (Mandatory/Required)
- [ ] Verificación de certificado desactivada (si autofirmado)

### Pruebas Funcionales
- [ ] Softphone registra vía TLS
- [ ] `pjsip show endpoints` muestra "Avail"
- [ ] Llamada se establece
- [ ] Audio bidireccional funciona
- [ ] Softphone muestra ícono de seguridad/candado

### Verificación con Herramientas
- [ ] OpenSSL s_client se conecta exitosamente
- [ ] Wireshark muestra "TLS Application Data" para SIP
- [ ] Wireshark muestra paquetes cifrados para RTP
- [ ] sngrep muestra "Encrypted: Yes"

---

## 13. Ejercicios Adicionales

### Ejercicio 1: Análisis de Handshake TLS

1. Captura handshake TLS:
```bash
sudo tcpdump -i any -n 'tcp port 5061' -w tls-handshake.pcap
```
2. Registra tu softphone
3. Abre captura en Wireshark
4. Filtra: `tls.handshake`
5. Identifica: ClientHello, ServerHello, Certificate, Finished

**Preguntas:**
- ¿Cuántos paquetes tiene el handshake?
- ¿Qué cipher suite se negoció?
- ¿Qué versión de TLS se usó?

### Ejercicio 2: Comparar RTP vs SRTP

1. Hacer llamada SIN cifrado (puerto 5060)
2. Capturar: `sudo tcpdump -i any -n 'portrange 10000-20000' -w rtp.pcap`
3. Hacer llamada CON cifrado (puerto 5061)
4. Capturar: `sudo tcpdump -i any -n 'portrange 10000-20000' -w srtp.pcap`
5. Comparar ambas capturas en Wireshark

**Observar:**
- ¿Puedes reproducir audio en alguna?
- ¿Qué diferencias ves en el payload?

### Ejercicio 3: Generar Certificado con SAN

Crea certificado con Subject Alternative Names:
```bash
# Crear archivo de configuración
cat > cert.conf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 200.100.100.1
O = DUOC UC
C = CL

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = 200.100.100.1
DNS.1 = kamailio.example.com
EOF

# Generar con SAN
openssl req -x509 -newkey rsa:4096 -keyout key.pem \
  -out cert.pem -days 365 -nodes -config cert.conf

# Ver SANs
openssl x509 -in cert.pem -text -noout | grep -A 2 "Subject Alternative"
```

### Ejercicio 4: Implementar Certificate Pinning

Modifica tls.cfg para aceptar solo certificados específicos:
```ini
[client:default]
verify_certificate = yes
ca_list = /path/to/trusted-ca.pem
```

---

## 14. Caso de Estudio

### Escenario: Clínica Médica (HIPAA Compliance)

**Contexto:**
- Clínica "MediPlus" maneja información médica sensible (HIPAA)
- 50 empleados (doctores, enfermeras, administrativos)
- Necesitan VoIP para teleconsultas
- Regulación exige cifrado extremo a extremo

**Requisitos:**
- Todo el tráfico debe estar cifrado (señalización + medios)
- Logs de auditoría de llamadas
- Certificados válidos (no autofirmados)
- Alta disponibilidad (99.9% uptime)

**Tu misión:**
1. Diseñar arquitectura VoIP segura
2. Especificar tipo de certificados necesarios
3. Proponer mecanismo de logging
4. Estimar costos (certificados, hardware, ancho de banda)

**Preguntas:**
- ¿Usarías SDES o DTLS-SRTP? ¿Por qué?
- ¿Cómo obtendrías certificados de CA reconocida?
- ¿Qué información auditarías?

---

## 15. Tabla Comparativa de Métodos de Cifrado

| Aspecto | SDES | DTLS-SRTP | ZRTP |
|---------|------|-----------|------|
| **Tipo** | Inline en SDP | Handshake separado | P2P |
| **Requiere TLS** | Sí ⚠️ | No | No |
| **Complejidad** | Baja | Media-Alta | Media |
| **Estandarización** | RFC 4568 | RFC 5764 | RFC 6189 |
| **Soporte** | Amplio | Creciente | Limitado |
| **Intercambio claves** | Via SIP (SDP) | Handshake DTLS | Diffie-Hellman |
| **Man-in-the-middle** | Vulnerable sin TLS | Resistente | Muy resistente |
| **Ideal para** | Empresa (SBC) | WebRTC | P2P seguro |

**Recomendación lab:** SDES (más simple, bien soportado)

---

## 16. Cipher Suites Explicados

### ¿Qué es un Cipher Suite?

Conjunto de algoritmos para:
1. **Key Exchange:** Cómo intercambiar claves
2. **Authentication:** Cómo autenticar
3. **Encryption:** Cómo cifrar
4. **MAC:** Cómo verificar integridad

### Ejemplo: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

```
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
│   │     │       │       │   │
│   │     │       │       │   └─ SHA256: Hash para MAC
│   │     │       │       └───── GCM: Modo de cifrado
│   │     │       └─────────────  AES_128: Cifrado (128 bits)
│   │     └─────────────────────  RSA: Autenticación
│   └───────────────────────────  ECDHE: Intercambio de claves
└───────────────────────────────  TLS: Protocolo
```

### Cipher Suites Seguros (Recomendados)

```bash
# En tls.cfg:
cipher_list = ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DES
```

**Evitar:**
- `!aNULL`: Sin autenticación
- `!MD5`: Hash débil
- `!RC4`: Cifrado débil
- `!DES`: Cifrado obsoleto

---

## 17. Recursos Adicionales

### Documentación Oficial
- [RFC 5246 - TLS 1.2](https://tools.ietf.org/html/rfc5246)
- [RFC 3711 - SRTP](https://tools.ietf.org/html/rfc3711)
- [RFC 4568 - SDES](https://tools.ietf.org/html/rfc4568)
- [Kamailio TLS Module](https://www.kamailio.org/docs/modules/stable/modules/tls.html)

### Herramientas Online
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/)
- [Cipher Suite Info](https://ciphersuite.info/)
- [TLS Version Check](https://www.howsmyssl.com/)

### Tutoriales
- [OpenSSL Cookbook](https://www.feistyduck.com/books/openssl-cookbook/)
- [SRTP in Asterisk](https://wiki.asterisk.org/wiki/display/AST/Secure+Calling+Tutorial)

---

**Última actualización:** 2024  
**Versión:** 1.0
