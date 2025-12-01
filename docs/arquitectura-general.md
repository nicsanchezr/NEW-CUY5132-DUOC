# Arquitectura General - Laboratorios VoIP
## Experiencia de Aprendizaje 2 - CUY5132 Comunicaciones Unificadas

Este documento describe las arquitecturas implementadas progresivamente en los laboratorios de la EA2.

---

## 🎯 Escenario General

**Empresa:** TechCorp  
**Problema:** Empleados trabajando desde casa necesitan sistema de telefonía VoIP  
**Desafío:** Usuarios remotos detrás de NAT, seguridad, privacidad

**Solución progresiva:**
- **Lab 2.1:** Implementar SBC básico (señalización)
- **Lab 2.2:** Ocultar Asterisk + Gestión NAT (relay de medios)
- **Lab 2.3:** Cifrado completo TLS/SRTP (privacidad)
- **Lab 2.4:** Monitoreo y defensa activa (producción)

---

## 🏗️ Componentes Principales

1. **Session Border Controller (SBC)** - Kamailio
2. **PBX Interno** - Asterisk  
3. **Gestión de Medios** - RTPProxy
4. **Monitoreo** - sngrep
5. **Defensa Activa** - fail2ban

---

## 📐 Arquitectura por Laboratorio

### Lab 2.1: SBC Básico

**Objetivo:** Separar funciones SBC (perímetro) vs PBX (lógica)

```
                     INTERNET
                        │
                        │ SIP (5060 UDP)
                        ↓
            ┌───────────────────────┐
            │  Security Group AWS   │
            │  - 5060 UDP (SIP)     │
            │  - 22 TCP (SSH)       │
            └───────────┬───────────┘
                        │
            ┌───────────▼───────────┐
            │  EC2: Kamailio-SBC    │
            │  IP Pública: X.X.X.X  │
            │  IP Privada: 10.0.1.10│
            │                       │
            │  ┌─────────────────┐  │
            │  │  Kamailio       │  │
            │  │  - Puerto 5060  │  │
            │  │  - Proxy SIP    │  │
            │  │  - Routing      │  │
            │  └────────┬────────┘  │
            └───────────┼───────────┘
                        │ SIP
                        ↓
            ┌───────────────────────┐
            │  EC2: Asterisk-PBX    │
            │  IP Pública: Y.Y.Y.Y  │ ⚠️ Temporal
            │  IP Privada: 10.0.2.10│
            │                       │
            │  ┌─────────────────┐  │
            │  │  Asterisk PBX   │  │
            │  │  - Puerto 5060  │  │
            │  │  - RTP 10k-20k  │  │ ⚠️ Expuesto
            │  │  - Extensions   │  │
            │  └─────────────────┘  │
            └───────────────────────┘

Señalización: Cliente → Kamailio → Asterisk ✓
Medios (RTP): Cliente ←→ Asterisk (DIRECTO) ⚠️
```

**Security Groups Lab 2.1:**

**SG-Kamailio:**
```
22   TCP  0.0.0.0/0     (SSH admin)
5060 UDP  0.0.0.0/0     (SIP)
```

**SG-Asterisk (TEMPORAL - Lab 2.1):**
```
22          TCP  0.0.0.0/0     (SSH admin)
5060        UDP  0.0.0.0/0     (SIP) ⚠️
10000-20000 UDP  0.0.0.0/0     (RTP) ⚠️
```

**Características:**
- ✅ Kamailio actúa como proxy SIP
- ✅ Asterisk procesa lógica de llamadas
- ✅ Separación de funciones
- ⚠️ Asterisk AÚN expuesto (se arregla en Lab 2.2)
- ⚠️ RTP fluye directo (sin relay)
- ❌ Sin soporte NAT
- ❌ Sin cifrado

**Limitaciones:**
- Usuarios NAT pueden tener problemas de audio
- Asterisk visible desde Internet
- Comunicaciones en texto plano

---

### Lab 2.2: Ocultación y Gestión NAT

**Objetivo:** Ocultar Asterisk completamente + Permitir usuarios NAT

```
    INTERNET (Usuarios tras NAT)
            │
            │ SIP (5060 UDP)
            ↓
┌───────────────────────────────┐
│     Security Group AWS        │
│  - 5060 UDP (SIP)            │
│  - 10000-20000 UDP (RTP)     │
└───────────┬───────────────────┘
            │
┌───────────▼───────────────────┐
│    EC2: Kamailio-SBC          │
│    IP Pública: X.X.X.X        │
│    IP Privada: 10.0.1.10      │
│                               │
│  ┌─────────────────────────┐  │
│  │    Kamailio SBC         │  │
│  │    - Puerto 5060        │  │
│  │    - NAT Detection      │  │
│  │    - fix_nated_contact  │  │
│  │    - rtpproxy_manage    │  │
│  └──────────┬──────────────┘  │
│             │                 │
│  ┌──────────▼──────────────┐  │
│  │    RTPProxy             │  │
│  │    - Socket: 7722       │  │
│  │    - Relay RTP          │  │
│  │    - Puertos 10k-20k    │  │
│  │    - PUBLIC_IP/PRIVATE  │  │
│  └─────────────────────────┘  │
└───────────┬───────────────────┘
            │ SIP (red privada)
            ↓
┌───────────────────────────────┐
│    EC2: Asterisk-PBX          │
│    IP Privada: 10.0.2.10      │ ✓ OCULTO
│    SIN IP Pública             │ ✓ SEGURO
│                               │
│  ┌─────────────────────────┐  │
│  │    Asterisk PBX         │  │
│  │    - Puerto 5060        │  │
│  │    - RTP 10k-20k        │  │
│  │    - Solo desde Kamailio│  │
│  └─────────────────────────┘  │
└───────────────────────────────┘

Señalización: Cliente → Kamailio → Asterisk ✓
Medios (RTP):  Cliente ←→ RTPProxy ←→ Asterisk ✓
```

**Security Groups Lab 2.2 (ACTUALIZADOS):**

**SG-Kamailio:**
```
22          TCP  0.0.0.0/0     (SSH admin)
5060        UDP  0.0.0.0/0     (SIP)
10000-20000 UDP  0.0.0.0/0     (RTP para RTPProxy)
```

**SG-Asterisk (RESTRINGIDO):**
```
22          TCP  Mi IP              (SSH admin)
5060        UDP  SG-Kamailio        (SIP solo desde Kamailio)
10000-20000 UDP  SG-Kamailio        (RTP solo desde RTPProxy)
```

**Componentes Nuevos:**
- **RTPProxy:** Relay de medios en Kamailio
- **Módulo nathelper:** Detección NAT
- **Módulo rtpproxy:** Gestión de relay

**Flujo de Tráfico:**

1. **Señalización (SIP):**
   - Cliente → Kamailio (detecta NAT con nat_uac_test)
   - Kamailio → Asterisk (SIP interno)

2. **Medios (RTP):**
   - Cliente → RTPProxy IP pública
   - RTPProxy → Asterisk IP privada
   - Audio bidireccional relay

**Soluciones Implementadas:**
- ✅ Asterisk completamente oculto (IP privada)
- ✅ Clientes NAT pueden llamar sin problemas
- ✅ Audio bidireccional funcional
- ✅ Detección automática de NAT
- ✅ Relay transparente de medios
- ✅ Security Groups restrictivos

**Mejoras sobre Lab 2.1:**
- Seguridad: Asterisk ya no accesible desde Internet
- NAT: Usuarios remotos funcionan perfectamente
- Topología: Completamente oculta

---

### Lab 2.3: Cifrado TLS/SRTP

**Objetivo:** Cifrado end-to-end de señalización y medios

```
        INTERNET (Usuarios)
                │
                │ SIPS (5061 TLS) 🔒
                ↓
    ┌───────────────────────────┐
    │   Security Group AWS      │
    │   - 5060 UDP (SIP)        │
    │   - 5061 TCP (TLS)        │ ← NUEVO
    │   - 10000-20000 UDP       │
    └───────────┬───────────────┘
                │
    ┌───────────▼───────────────┐
    │   EC2: Kamailio-SBC       │
    │   IP Pública: X.X.X.X     │
    │                           │
    │  ┌─────────────────────┐  │
    │  │  Kamailio SBC       │  │
    │  │  Puerto 5060 (UDP)  │  │
    │  │  Puerto 5061 (TLS)  │  │ 🔒
    │  │                     │  │
    │  │  Certificados:      │  │
    │  │  - kamailio-cert.pem│  │
    │  │  - kamailio-key.pem │  │
    │  │  - CN: IP_PUBLICA   │  │
    │  └──────────┬──────────┘  │
    │             │              │
    │  ┌──────────▼──────────┐  │
    │  │    RTPProxy         │  │
    │  │    (relay SRTP)     │  │ 🔒
    │  └─────────────────────┘  │
    └───────────┬───────────────┘
                │ TLS 🔒
                ↓
    ┌───────────────────────────┐
    │   EC2: Asterisk-PBX       │
    │   IP Privada: 10.0.2.10   │
    │                           │
    │  ┌─────────────────────┐  │
    │  │  Asterisk PBX       │  │
    │  │                     │  │
    │  │  Transports:        │  │
    │  │  - UDP: 5060        │  │
    │  │  - TLS: 5061        │  │ 🔒
    │  │                     │  │
    │  │  SRTP:              │  │
    │  │  - media_encryption │  │
    │  │  - SDES negotiation │  │
    │  └─────────────────────┘  │
    └───────────────────────────┘

Señalización: Cliente ←TLS→ Kamailio ←TLS→ Asterisk 🔒
Medios (Audio): Cliente ←SRTP→ RTPProxy ←SRTP→ Asterisk 🔒
```

**Security Groups Lab 2.3 (AGREGAR):**

**SG-Kamailio:**
```
22          TCP  0.0.0.0/0     (SSH admin)
5060        UDP  0.0.0.0/0     (SIP)
5061        TCP  0.0.0.0/0     (SIPS/TLS) ← NUEVO
10000-20000 UDP  0.0.0.0/0     (RTP/SRTP)
```

**SG-Asterisk:**
```
22          TCP  Mi IP              (SSH admin)
5060        UDP  SG-Kamailio        (SIP)
5061        TCP  SG-Kamailio        (SIPS/TLS) ← NUEVO
10000-20000 UDP  SG-Kamailio        (RTP/SRTP)
```

**Componentes de Seguridad:**

1. **Certificados TLS:**
   - Generados con OpenSSL
   - Autofirmados (para laboratorio)
   - CN = IP Pública
   - Validez: 365 días

2. **TLS (Señalización):**
   - Protocolo: TLS 1.2+
   - Puerto: 5061 TCP
   - Cipher suites seguros
   - Archivo: `/etc/kamailio/tls.cfg`

3. **SRTP (Medios):**
   - Cifrado: AES-128
   - Negociación: SDES (RFC 4568)
   - En SDP: `a=crypto:...`
   - Parámetro Asterisk: `media_encryption=sdes`

**Softphones Recomendados:**
- **Linphone** ⭐ (Multiplataforma, Open Source)
- **MicroSIP** ⭐ (Windows, portable)

**Flujos Cifrados:**

| Segmento | Protocolo | Puerto | Cifrado |
|----------|-----------|--------|---------|
| Cliente → Kamailio | TLS | 5061 | ✅ SIP cifrado |
| Kamailio → Asterisk | TLS | 5061 | ✅ SIP cifrado |
| Cliente → RTPProxy | SRTP | 10k-20k | ✅ Audio cifrado |
| RTPProxy → Asterisk | SRTP | 10k-20k | ✅ Audio cifrado |

**Verificación Wireshark:**
- ✅ TLS Handshake visible
- ✅ Application Data (SIP NO legible)
- ✅ SDP con líneas `a=crypto`
- ✅ SRTP (RTP NO decodificable)

**⚠️ CRÍTICO:** Este laboratorio es REQUERIDO para evaluación sumativa

**Mejoras sobre Lab 2.2:**
- Privacidad: Señalización cifrada (TLS)
- Confidencialidad: Audio cifrado (SRTP)
- Autenticación: Certificados digitales
- Estándar: Listo para producción

---

### Lab 2.4: Monitoreo y Defensa Activa

**Objetivo:** Completar arquitectura de producción con análisis y defensa

```
            INTERNET
                │
    ┌───────────┼───────────┐
    │   Atacante│           │
    │           ↓           │
    │   ❌ BLOQUEADO       │
    │      (fail2ban)      │
    └──────────────────────┘
                │
    Usuario Legítimo
                ↓
    ┌───────────────────────────┐
    │   EC2: Kamailio-SBC       │
    │   IP Pública: X.X.X.X     │
    │                           │
    │  ┌─────────────────────┐  │
    │  │  Kamailio SBC       │  │
    │  │  - TLS/SRTP         │  │
    │  │  - RTPProxy         │  │
    │  │  - NAT helper       │  │
    │  └─────────────────────┘  │
    │                           │
    │  ┌─────────────────────┐  │
    │  │  sngrep             │  │ 📊
    │  │  - Análisis real    │  │
    │  │  - Diagnóstico SIP  │  │
    │  │  - Flow diagrams    │  │
    │  └─────────────────────┘  │
    │                           │
    │  ┌─────────────────────┐  │
    │  │  fail2ban           │  │ 🛡️
    │  │  - IPS/IDS          │  │
    │  │  - Ban automático   │  │
    │  │  - Log analysis     │  │
    │  │  - iptables rules   │  │
    │  └─────────────────────┘  │
    └───────────┬───────────────┘
                │
    ┌───────────▼───────────────┐
    │   EC2: Asterisk-PBX       │
    │   (Completamente oculto)  │
    └───────────────────────────┘

Capas de Seguridad:
1️⃣ Security Groups AWS (Firewall red)
2️⃣ fail2ban (IPS/IDS aplicación)
3️⃣ Kamailio SBC (Filtrado SIP)
4️⃣ TLS/SRTP (Cifrado)
5️⃣ Asterisk (Lógica protegida)
```

**Componentes Nuevos:**

**1. sngrep (Monitoreo y Diagnóstico):**
- Análisis de tráfico SIP en tiempo real
- Visualización de flujos de llamadas
- Inspección de headers SIP
- Guardado de capturas PCAP

**Uso:**
```bash
sudo sngrep                    # Análisis en vivo
sudo sngrep port 5060          # Puerto específico
```

**2. fail2ban (Defensa Activa):**
- Sistema de prevención de intrusiones (IPS)
- Detección automática de ataques
- Baneo de IPs maliciosas
- Integración con iptables

**Configuración:**
```ini
[kamailio-auth]
enabled = true
bantime = 3600      # 1 hora
findtime = 600      # 10 minutos
maxretry = 3        # 3 intentos
```

**Filtros detectan:**
- Brute force de autenticación
- Escaneo de extensiones
- Flooding de INVITE
- 401/407 repetidos

**Ataques Bloqueados:**
- ✅ Brute force registration
- ✅ SIP scanning
- ✅ INVITE flooding
- ✅ Fraud attempts

**Herramientas de Análisis:**

| Herramienta | Propósito | Uso |
|-------------|-----------|-----|
| **sngrep** | Análisis tiempo real | Diagnóstico rápido |
| **Wireshark** | Análisis forense | Investigación detallada |
| **fail2ban** | IPS automático | Defensa activa |
| **tcpdump** | Captura raw | Grabación tráfico |

**Arquitectura Final Completa:**
- ✅ SBC (Kamailio)
- ✅ PBX oculto (Asterisk)
- ✅ Relay medios (RTPProxy)
- ✅ NAT traversal
- ✅ Cifrado TLS/SRTP
- ✅ Monitoreo (sngrep)
- ✅ Defensa activa (fail2ban)

**Estado:** **PRODUCCIÓN-READY** ✅

---

## 🔄 Comparación Completa de Arquitecturas

| Característica | Lab 2.1 | Lab 2.2 | Lab 2.3 | Lab 2.4 |
|----------------|---------|---------|---------|---------|
| **SBC** | ✅ Kamailio | ✅ Kamailio | ✅ Kamailio | ✅ Kamailio |
| **PBX** | ✅ Asterisk | ✅ Asterisk | ✅ Asterisk | ✅ Asterisk |
| **Asterisk IP** | Pública ⚠️ | Privada ✅ | Privada ✅ | Privada ✅ |
| **Soporte NAT** | ❌ No | ✅ RTPProxy | ✅ RTPProxy | ✅ RTPProxy |
| **Cifrado Señal** | ❌ No | ❌ No | ✅ TLS | ✅ TLS |
| **Cifrado Medios** | ❌ No | ❌ No | ✅ SRTP | ✅ SRTP |
| **Monitoreo** | ❌ No | ❌ No | ❌ No | ✅ sngrep |
| **Defensa Activa** | ❌ No | ❌ No | ❌ No | ✅ fail2ban |
| **Security Groups** | Abiertos | Restrictivos | Restrictivos | Restrictivos |
| **Seguridad** | Baja | Media | Alta | Muy Alta |
| **Producción** | ❌ No | ❌ No | ⚠️ Casi | ✅ Sí |
| **Complejidad** | Baja | Media | Alta | Alta |

---

## 🌐 Topología de Red AWS

### Configuración Ideal (Labs 2.2+)

```
AWS Region
│
└─ VPC (10.0.0.0/16)
   │
   ├─ Subnet Pública (10.0.1.0/24)
   │  │
   │  └─ EC2 Kamailio-SBC
   │     ├─ IP Privada: 10.0.1.10
   │     ├─ IP Pública: X.X.X.X (Elastic IP)
   │     ├─ Security Group: SG-Kamailio
   │     ├─ Servicios: Kamailio, RTPProxy, sngrep, fail2ban
   │     └─ Función: DMZ / Perímetro
   │
   └─ Subnet Privada (10.0.2.0/24)
      │
      └─ EC2 Asterisk-PBX
         ├─ IP Privada: 10.0.2.10
         ├─ SIN IP Pública ✓
         ├─ Security Group: SG-Asterisk
         ├─ Servicios: Asterisk
         └─ Función: Core interno protegido

Internet Gateway
      │
      ↓
Kamailio (Zona DMZ)
      │
      ↓
Asterisk (Zona Interna - No accesible)
```

### Security Groups Finales (Lab 2.4)

**SG-Kamailio (Entrada):**
```
22          TCP  Tu-IP-Admin     ← SSH administración
5060        UDP  0.0.0.0/0       ← SIP clientes
5061        TCP  0.0.0.0/0       ← SIPS/TLS clientes
10000-20000 UDP  0.0.0.0/0       ← RTP/SRTP medios
```

**SG-Asterisk (Entrada):**
```
22          TCP  Tu-IP-Admin     ← SSH administración
5060        UDP  SG-Kamailio     ← SIP solo desde Kamailio
5061        TCP  SG-Kamailio     ← SIPS/TLS solo desde Kamailio
10000-20000 UDP  SG-Kamailio     ← RTP/SRTP solo desde Kamailio
```

**Principio de Seguridad:**
- Asterisk **NUNCA** accesible directamente desde Internet
- Solo Kamailio puede comunicarse con Asterisk
- Todo tráfico externo pasa por SBC

---

## 🔐 Principios de Seguridad Implementados

### 1. Defensa en Profundidad (Defense in Depth)

```
Capa 1: Internet
   │ ↓ Atacantes bloqueados por fail2ban
Capa 2: Firewall AWS (Security Groups)
   │ ↓ Solo puertos necesarios
Capa 3: DMZ (Kamailio SBC)
   │ ↓ Filtrado SIP, NAT handling, cifrado
Capa 4: Red Interna (Asterisk)
   │ ↓ Lógica de negocio protegida
Capa 5: Aplicación
   │ ↓ Autenticación, autorización
```

### 2. Principio de Mínimo Privilegio

- Asterisk: Solo accesible desde Kamailio
- Puertos: Solo los estrictamente necesarios
- SSH: Solo desde IPs de administración

### 3. Ocultamiento de Topología (Topology Hiding)

- Clientes solo ven IP de Kamailio
- Asterisk completamente invisible
- Headers SIP reescritos por SBC
- Dirección real de Asterisk nunca expuesta

### 4. Gestión de Zonas de Confianza

**Zonas definidas:**
```
No Confiable → Internet, Clientes
  ↓ Filtro: fail2ban, SBC
Perímetro → Kamailio (DMZ)
  ↓ Filtro: Security Groups
Confiable → Red interna con Asterisk
```

**Políticas:**
- Internet → Solo puede hablar con Kamailio
- Kamailio → Único que puede hablar con Asterisk
- Asterisk → NUNCA responde directamente a Internet

---

## 📊 Flujo Completo de Llamada (Lab 2.4)

### Fase 1: Registro (REGISTER)

```
1. Cliente → Kamailio (5061 TLS):
   REGISTER sips:domain.com
   
2. Kamailio (procesamiento):
   - Verificar Security Group ✓
   - fail2ban verifica IP ✓
   - Detectar NAT (nat_uac_test) ✓
   - Reescribir Contact (fix_nated_contact) ✓
   - sngrep captura flujo 📊
   
3. Kamailio → Asterisk (5061 TLS):
   REGISTER sips:domain.com
   (headers modificados)
   
4. Asterisk procesa:
   - Autenticación PJSIP ✓
   - Guardar ubicación ✓
   
5. Asterisk → Kamailio:
   200 OK
   
6. Kamailio → Cliente:
   200 OK
   (Contact corregido para NAT)
```

### Fase 2: Llamada (INVITE)

```
Señalización:
─────────────
Cliente A → Kamailio: INVITE sips:1002@domain (TLS 🔒)

Kamailio procesamiento:
  ├─ sngrep muestra flujo en tiempo real 📊
  ├─ Lookup(location) → Encuentra 1002
  ├─ NAT detection (nat_uac_test)
  ├─ rtpproxy_offer() → Prepara relay
  └─ Reescribe SDP (c= line con IP RTPProxy)
  
Kamailio → Asterisk: INVITE (TLS 🔒)
Asterisk → Ejecuta Dialplan
Asterisk → Cliente B (ring)

Cliente B → Answer (200 OK con SDP)
Asterisk → Kamailio: 200 OK

Kamailio procesamiento:
  ├─ rtpproxy_answer() → Completa relay
  └─ Reescribe SDP respuesta
  
Kamailio → Cliente A: 200 OK (SDP modificado)
Cliente A → ACK

Medios (RTP/SRTP):
─────────────────
Cliente A ←─SRTP 🔒─→ RTPProxy ←─SRTP 🔒─→ Cliente B
(Puertos dinámicos 10k-20k)

Terminación:
────────────
Cliente A → BYE → Kamailio → Asterisk → Cliente B
...respuestas 200 OK...
RTPProxy → Libera recursos (rtpproxy_destroy)
sngrep → Muestra llamada completa 📊
```

---

## 🎓 Conceptos Clave

### Session Border Controller (SBC)

**Funciones principales:**
1. **Señalización:** Proxy, routing, reescritura SIP
2. **Medios:** Control y relay de RTP/SRTP
3. **Seguridad:** Firewall SIP, validación headers
4. **NAT:** Traversal, detección, corrección
5. **Topología:** Ocultamiento de red interna
6. **Cifrado:** Terminación TLS, gestión SRTP
7. **Defensa:** Integración con IPS (fail2ban)

### Private Branch Exchange (PBX)

**Funciones principales:**
1. **Extensiones:** Gestión de usuarios internos
2. **Dialplan:** Lógica de enrutamiento de llamadas
3. **Codecs:** Transcodificación de audio
4. **IVR:** Respuesta interactiva de voz
5. **CDR:** Registro detallado de llamadas
6. **Voicemail:** Buzón de voz
7. **Conference:** Salas de conferencia

### RTP Proxy

**Funciones principales:**
1. **Relay:** Reenvío de paquetes RTP/SRTP
2. **NAT Handling:** Gestión de medios tras NAT
3. **Port Management:** Asignación dinámica de puertos
4. **Symmetric RTP:** Corrección de rutas
5. **Media Anchoring:** Forzar paso por proxy

---

## 🔧 Herramientas de Diagnóstico

### Análisis de Tráfico

**sngrep (Tiempo Real):**
```bash
sudo sngrep                    # Live analysis
sudo sngrep -d any port 5060   # Interfaz específica
```
- ✅ Diagrama de flujo visual
- ✅ Inspección de headers
- ✅ Filtros en tiempo real
- ✅ Exportar a PCAP

**Wireshark (Forense):**
```bash
sudo tcpdump -w capture.pcap
# Luego analizar en Wireshark
```
- ✅ Análisis profundo de protocolos
- ✅ Decodificación completa
- ✅ Estadísticas avanzadas
- ✅ Filtros complejos

### Monitoreo de Servicios

```bash
# Estado de servicios
systemctl status kamailio
systemctl status rtpproxy
systemctl status asterisk
systemctl status fail2ban

# Puertos y conexiones
netstat -tulpn | grep kamailio
netstat -tulpn | grep rtpproxy

# Logs en tiempo real
journalctl -u kamailio -f
tail -f /var/log/syslog | grep kamailio
```

### Debugging VoIP

**Kamailio:**
```bash
# CLI commands
kamcmd stats.get_statistics all
kamcmd dlg.list
kamcmd tm.stats

# Config check
kamailio -c
```

**Asterisk:**
```bash
# CLI
sudo asterisk -rvvv

# Comandos útiles
pjsip show endpoints
pjsip show contacts
core show channels
rtp show stats
```

**fail2ban:**
```bash
# Ver status
fail2ban-client status
fail2ban-client status kamailio-auth

# Gestión de bans
fail2ban-client set kamailio-auth unbanip IP
fail2ban-client get kamailio-auth banip
```

---

## 📚 Referencias Técnicas

### Protocolos Implementados

- **SIP (RFC 3261):** Señalización de sesiones VoIP
- **RTP (RFC 3550):** Transporte de medios en tiempo real
- **SRTP (RFC 3711):** RTP con cifrado
- **TLS (RFC 8446):** Transporte seguro capa aplicación
- **SDP (RFC 4566):** Descripción de sesiones multimedia
- **SDES (RFC 4568):** Negociación de claves SRTP

### Estándares de Seguridad

- **TLS 1.2/1.3 (RFC 5246/8446):** Cifrado señalización
- **X.509:** Certificados digitales PKI
- **AES-128:** Cifrado simétrico SRTP
- **SHA-256:** Funciones hash

### Software Utilizado

- **Kamailio:** SIP Server/SBC (https://www.kamailio.org)
- **Asterisk:** IP PBX (https://www.asterisk.org)
- **RTPProxy:** Media proxy (http://www.rtpproxy.org)
- **sngrep:** SIP analyzer (https://github.com/irontec/sngrep)
- **fail2ban:** IPS (https://www.fail2ban.org)

---

## 🎯 Progresión de Aprendizaje

### Lab 2.1: Fundamentos
**Aprendiste:**
- Arquitectura SBC vs PBX
- Routing SIP básico
- Separación de funciones

### Lab 2.2: Seguridad Perimetral
**Aprendiste:**
- Ocultación de topología
- NAT traversal
- Relay de medios

### Lab 2.3: Privacidad
**Aprendiste:**
- Criptografía aplicada (TLS/SRTP)
- Certificados digitales
- Verificación de cifrado

### Lab 2.4: Producción
**Aprendiste:**
- Monitoreo en tiempo real
- Defensa activa (IPS/IDS)
- Arquitectura completa empresarial

---

## ✅ Checklist Arquitectura Final

**Componentes:**
- [x] Kamailio SBC (perímetro)
- [x] Asterisk PBX (core interno)
- [x] RTPProxy (relay medios)
- [x] sngrep (monitoreo)
- [x] fail2ban (defensa)

**Seguridad:**
- [x] Asterisk con IP privada únicamente
- [x] Security Groups restrictivos
- [x] TLS 1.2+ en señalización
- [x] SRTP en medios
- [x] IPS configurado

**Funcionalidad:**
- [x] Usuarios NAT soportados
- [x] Audio bidireccional
- [x] Cifrado end-to-end
- [x] Monitoreo tiempo real
- [x] Defensa automática

**Documentación:**
- [x] Diagramas de arquitectura
- [x] Security Groups documentados
- [x] Flujos de tráfico descritos
- [x] Configuraciones comentadas

---

**Estado:** ARQUITECTURA COMPLETA DE NIVEL PRODUCCIÓN ✅

---

**Última actualización:** Diciembre 2025  
**Versión:** 2.0 (Actualizada - Labs 2.1 a 2.4 completos)  
**Autor:** CUY5132 - DUOC UC
