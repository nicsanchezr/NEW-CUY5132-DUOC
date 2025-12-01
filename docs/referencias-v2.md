# Referencias y Recursos
## Experiencia de Aprendizaje 2

Compilación de enlaces útiles, documentación oficial y recursos de aprendizaje.

---

## 📚 Documentación Oficial

### Kamailio

**Documentación Principal:**
- [Kamailio Wiki](https://www.kamailio.org/wiki/) - Wiki oficial
- [Kamailio Documentation](https://www.kamailio.org/wikidocs/) - Guías y tutoriales
- [Kamailio Cookbook 5.7](https://www.kamailio.org/wikidocs/cookbooks/5.7.x/) - Recetas de configuración

**Módulos Específicos:**
- [Module: tm](https://www.kamailio.org/docs/modules/stable/modules/tm.html) - Transaction Management
- [Module: sl](https://www.kamailio.org/docs/modules/stable/modules/sl.html) - Stateless replies
- [Module: rr](https://www.kamailio.org/docs/modules/stable/modules/rr.html) - Record-Route
- [Module: maxfwd](https://www.kamailio.org/docs/modules/stable/modules/maxfwd.html) - Loop detection
- [Module: usrloc](https://www.kamailio.org/docs/modules/stable/modules/usrloc.html) - User location
- [Module: registrar](https://www.kamailio.org/docs/modules/stable/modules/registrar.html) - Registration
- [Module: nathelper](https://www.kamailio.org/docs/modules/stable/modules/nathelper.html) - NAT traversal
- [Module: rtpproxy](https://www.kamailio.org/docs/modules/stable/modules/rtpproxy.html) - RTPProxy control
- [Module: tls](https://www.kamailio.org/docs/modules/stable/modules/tls.html) - TLS transport

**Funciones Core:**
- [Core Functions](https://www.kamailio.org/docs/modules/stable/modules/corex.html) - Funciones principales
- [Transformations](https://www.kamailio.org/wiki/cookbooks/5.7.x/transformations) - Manipulación de variables
- [Pseudo-Variables](https://www.kamailio.org/wikidocs/cookbooks/5.7.x/pseudovariables/) - Variables especiales

---

### Asterisk

**Documentación Principal:**
- [Asterisk Wiki](https://wiki.asterisk.org/) - Wiki oficial
- [Asterisk Documentation](https://docs.asterisk.org/) - Documentación completa
- [Asterisk 20 Guide](https://docs.asterisk.org/Asterisk_20_Documentation/) - Guía v20

**Configuración PJSIP:**
- [PJSIP Configuration](https://wiki.asterisk.org/wiki/display/AST/Configuring+res_pjsip) - Guía de configuración
- [PJSIP Endpoints](https://wiki.asterisk.org/wiki/display/AST/PJSIP+Configuration+Sections+and+Relationships) - Endpoints y relaciones
- [Transport Configuration](https://wiki.asterisk.org/wiki/display/AST/PJSIP+Transport) - Configuración de transporte

**Dialplan:**
- [Dialplan Basics](https://wiki.asterisk.org/wiki/display/AST/Dialplan) - Conceptos básicos
- [Dialplan Applications](https://wiki.asterisk.org/wiki/display/AST/Dialplan+Applications) - Aplicaciones disponibles
- [Pattern Matching](https://wiki.asterisk.org/wiki/display/AST/Pattern+Matching) - Patrones de extensiones

**Seguridad:**
- [Asterisk Security](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Security) - Prácticas de seguridad
- [TLS Configuration](https://wiki.asterisk.org/wiki/display/AST/Configuring+TLS) - Configuración TLS
- [SRTP](https://wiki.asterisk.org/wiki/display/AST/Secure+Calling+Tutorial) - Tutorial de llamadas seguras

---

### RTPProxy

**Documentación:**
- [RTPProxy GitHub](https://github.com/sippy/rtpproxy) - Repositorio oficial
- [RTPProxy Wiki](https://www.rtpproxy.org/) - Wiki y documentación
- [RTPProxy with Kamailio](https://www.kamailio.org/docs/modules/stable/modules/rtpproxy.html) - Integración con Kamailio

---

## 🌐 Protocolos y RFCs

### SIP (Session Initiation Protocol)

**RFCs Fundamentales:**
- [RFC 3261](https://tools.ietf.org/html/rfc3261) - SIP: Session Initiation Protocol (Base)
- [RFC 3262](https://tools.ietf.org/html/rfc3262) - Provisional responses (PRACK)
- [RFC 3263](https://tools.ietf.org/html/rfc3263) - SIP locating services
- [RFC 3264](https://tools.ietf.org/html/rfc3264) - Offer/Answer Model (SDP negotiation)
- [RFC 3265](https://tools.ietf.org/html/rfc3265) - SIP-Specific Event Notification (SUBSCRIBE/NOTIFY)

**Extensiones SIP:**
- [RFC 3581](https://tools.ietf.org/html/rfc3581) - Symmetric Response Routing (rport)
- [RFC 5626](https://tools.ietf.org/html/rfc5626) - Managing Client-Initiated Connections (Outbound)
- [RFC 6026](https://tools.ietf.org/html/rfc6026) - Correct Transaction Handling

**NAT Traversal:**
- [RFC 5389](https://tools.ietf.org/html/rfc5389) - STUN (Session Traversal Utilities for NAT)
- [RFC 5766](https://tools.ietf.org/html/rfc5766) - TURN (Traversal Using Relays around NAT)
- [RFC 5245](https://tools.ietf.org/html/rfc5245) - ICE (Interactive Connectivity Establishment)

---

### SDP (Session Description Protocol)

- [RFC 4566](https://tools.ietf.org/html/rfc4566) - SDP: Session Description Protocol
- [RFC 3264](https://tools.ietf.org/html/rfc3264) - Offer/Answer Model with SDP

---

### RTP (Real-time Transport Protocol)

- [RFC 3550](https://tools.ietf.org/html/rfc3550) - RTP: A Transport Protocol for Real-Time Applications
- [RFC 3551](https://tools.ietf.org/html/rfc3551) - RTP Profile for Audio and Video
- [RFC 4585](https://tools.ietf.org/html/rfc4585) - Extended RTP Profile (AVPF)

---

### Seguridad

**TLS:**
- [RFC 5246](https://tools.ietf.org/html/rfc5246) - TLS 1.2
- [RFC 8446](https://tools.ietf.org/html/rfc8446) - TLS 1.3
- [RFC 3261 §26.2.2](https://tools.ietf.org/html/rfc3261#section-26.2.2) - SIPS URI Scheme

**SRTP:**
- [RFC 3711](https://tools.ietf.org/html/rfc3711) - SRTP (Secure Real-time Transport Protocol)
- [RFC 4568](https://tools.ietf.org/html/rfc4568) - SDP Security Descriptions (SDES)
- [RFC 5763](https://tools.ietf.org/html/rfc5763) - DTLS-SRTP
- [RFC 5764](https://tools.ietf.org/html/rfc5764) - DTLS Extension for SRTP

**Certificados:**
- [RFC 5280](https://tools.ietf.org/html/rfc5280) - X.509 Public Key Infrastructure

---

## 🛠️ Herramientas

### Análisis de Tráfico

**Wireshark:**
- [Descarga](https://www.wireshark.org/download.html) - Descargar Wireshark
- [User Guide](https://www.wireshark.org/docs/wsug_html_chunked/) - Guía de usuario
- [Display Filters](https://wiki.wireshark.org/DisplayFilters) - Filtros de visualización
- [SIP Analysis](https://wiki.wireshark.org/SIP) - Análisis SIP en Wireshark

**Filtros útiles Wireshark:**
```
sip                           # Todo el tráfico SIP
sip.Method == "INVITE"        # Solo INVITEs
sip.Status-Code == 200        # Solo respuestas 200 OK
rtp                           # Tráfico RTP
srtp                          # Tráfico SRTP
tls.record.content_type == 22 # Handshake TLS
```

**sngrep:**
- [GitHub](https://github.com/irontec/sngrep) - Repositorio oficial
- [Documentation](https://github.com/irontec/sngrep/wiki) - Wiki y documentación

**fail2ban:**
- [Sitio Oficial](https://www.fail2ban.org/) - Página principal
- [GitHub](https://github.com/fail2ban/fail2ban) - Repositorio oficial
- [Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page) - Wiki completa
- [Configuration Manual](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8) - Manual de configuración

---

### Clientes SIP

**⭐ Linphone (RECOMENDADO para Labs):**
- [Descarga](https://www.linphone.org/technical-corner/linphone) - Cliente multiplataforma
- [GitHub](https://github.com/BelledonneCommunications/linphone-desktop) - Código fuente
- [User Guide](https://www.linphone.org/user-guide) - Guía de usuario
- **Características:** Open Source, TLS/SRTP completo, indicador visual de seguridad 🔒

**⭐ MicroSIP (RECOMENDADO para Windows):**
- [Descarga](https://www.microsip.org/downloads) - Cliente ligero Windows
- [Settings Guide](https://www.microsip.org/help) - Guía de configuración
- **Características:** Portable, 3 MB, excelente soporte TLS/SRTP

**Zoiper:**
- [Descarga](https://www.zoiper.com/en/voip-softphone/download/current) - Cliente multiplataforma
- [Manual](https://www.zoiper.com/en/support/home) - Documentación de soporte
- **Nota:** ⚠️ TLS/SRTP requiere versión PRO (pago) - NO recomendado para Lab 2.3

**Bria (Comercial):**
- [Sitio oficial](https://www.counterpath.com/bria-solo/) - Cliente profesional

---

### Acceso Remoto

**PuTTY (Windows):**
- [Descarga](https://www.putty.org/) - Cliente SSH para Windows
- [Documentation](https://the.earth.li/~sgtatham/putty/0.78/htmldoc/) - Documentación completa

**PuTTYgen:**
- Conversión de claves .pem a .ppk
- Incluido en instalador de PuTTY

**OpenSSH (Linux/Mac):**
```bash
# Pre-instalado en Linux/Mac
ssh -i key.pem ubuntu@host

# Transferencia de archivos:
scp -i key.pem file.txt ubuntu@host:/path/
```

---

### Generación de Certificados

**OpenSSL:**
- [Documentación](https://www.openssl.org/docs/) - Docs oficial OpenSSL
- [Cookbook](https://www.feistyduck.com/library/openssl-cookbook/) - OpenSSL Cookbook

**Comandos útiles:**
```bash
# Generar certificado autofirmado:
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Ver certificado:
openssl x509 -in cert.pem -text -noout

# Verificar clave privada:
openssl rsa -in key.pem -check

# Probar conexión TLS:
openssl s_client -connect host:5061 -showcerts
```

---

## ☁️ AWS y Cloud

**AWS Academy:**
- [AWS Academy Learner Lab](https://awsacademy.instructure.com/) - Plataforma de laboratorios
- [AWS Documentation](https://docs.aws.amazon.com/) - Documentación oficial AWS

**EC2:**
- [EC2 User Guide](https://docs.aws.amazon.com/ec2/) - Guía completa EC2
- [Instance Types](https://aws.amazon.com/ec2/instance-types/) - Tipos de instancias
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html) - Guía de Security Groups

**VPC:**
- [VPC User Guide](https://docs.aws.amazon.com/vpc/) - Amazon Virtual Private Cloud
- [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) - NAT Gateways

---

## 📖 Libros y Cursos

### Libros Recomendados

**SIP:**
- "SIP: Understanding the Session Initiation Protocol" - Alan B. Johnston
- "Internet Communications Using SIP" - Henry Sinnreich, Alan B. Johnston

**VoIP:**
- "VoIP and Unified Communications" - William A. Flanagan
- "Packet Guide to Voice over IP" - Bruce Hartpence

**Asterisk:**
- "Asterisk: The Definitive Guide" - Leif Madsen, Jim Van Meggelen, Russell Bryant
- [Disponible online](https://www.asteriskdocs.org/)

**Kamailio:**
- "Building Telephony Systems with Kamailio" - Flavio E. Goncalves

---

### Cursos Online

**Udemy:**
- "Asterisk Training - Build Cloud PBX"
- "VoIP Fundamentals"

**Coursera:**
- "Introduction to Computer Networking" - Stanford
- "Cloud Computing Basics" - University of Illinois

**YouTube Channels:**
- [Kamailio World](https://www.youtube.com/@kamailioproject) - Conferencias Kamailio
- [VoIP Tech Chat](https://www.youtube.com/@voiptechchat) - Tutoriales VoIP

---

## 🧪 Laboratorios y Práctica

### Ambientes de Prueba Online

**SIP Testers:**
- [SIPp](https://github.com/SIPp/sipp) - Herramienta de testing SIP
- [SIPVicious](https://github.com/EnableSecurity/sipvicious) - Security testing

**Online SIP Test:**
- [SIPTEST.io](https://www.siptest.io/) - Testing de clientes SIP online

---

### Datasets y Ejemplos

**Capturas SIP:**
- [Wireshark Sample Captures](https://wiki.wireshark.org/SampleCaptures) - PCAPs de ejemplo
- [VoIP-Info](https://www.voip-info.org/) - Recursos VoIP

---

## 🐛 Troubleshooting y Comunidad

### Foros y Comunidades

**Kamailio:**
- [Kamailio Mailing List](https://lists.kamailio.org/pipermail/sr-users/) - Lista oficial
- [Kamailio Community Forum](https://forum.kamailio.org/) - Foro de comunidad

**Asterisk:**
- [Asterisk Community](https://community.asterisk.org/) - Foro oficial
- [Asterisk Mailing Lists](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Mailing+Lists) - Listas de correo

**Stack Overflow:**
- Tag: [kamailio](https://stackoverflow.com/questions/tagged/kamailio)
- Tag: [asterisk](https://stackoverflow.com/questions/tagged/asterisk)
- Tag: [sip](https://stackoverflow.com/questions/tagged/sip)

**Reddit:**
- [r/VOIP](https://www.reddit.com/r/VOIP/)
- [r/asterisk](https://www.reddit.com/r/asterisk/)

---

### Blogs Técnicos

- [Kamailio Blog](https://www.kamailio.org/w/) - Blog oficial Kamailio
- [Sangoma Blog](https://www.sangoma.com/blog/) - Empresa detrás de Asterisk
- [VoIP Mechanic](https://www.voipmechanic.com/) - Blog técnico VoIP

---

## 🔍 Sitios de Referencia

**Especificaciones SIP:**
- [SIP RFC Directory](https://www.ietf.org/standards/rfcs/) - IETF RFCs
- [SIP Center](http://www.sipcenter.com/) - Recursos SIP

**Códecs:**
- [Codec Comparison](https://en.wikipedia.org/wiki/Comparison_of_audio_coding_formats) - Comparación de códecs
- [ITU-T Recommendations](https://www.itu.int/rec/T-REC/en) - Estándares ITU

**Números y Códigos:**
- [SIP Response Codes](https://en.wikipedia.org/wiki/List_of_SIP_response_codes) - Códigos de respuesta SIP
- [IANA SIP Parameters](https://www.iana.org/assignments/sip-parameters/) - Parámetros SIP oficiales

---

## 📊 Recursos del Curso

### Material Institucional

**Plataforma Educativa:**
- Guías de laboratorio (formato PDF)
- Presentaciones teóricas (formato PPTX)
- Orientaciones para docentes
- Rúbricas de evaluación

**Repositorio GitHub:**
- [NEW-CUY5132-DUOC](https://github.com/nicsanchezr/NEW-CUY5132-DUOC) - Scripts de instalación
- Ver: `/docs/` para documentación técnica adicional
- Ver: `/Experiencia-2/material-complementario/` para cheat sheets y FAQs

---

## 🎓 Certificaciones Relacionadas

**Cisco:**
- CCNA Collaboration
- CCNP Collaboration

**CompTIA:**
- Network+
- Security+

**Vendedor-específicas:**
- Asterisk: dCAP (Digium Certified Asterisk Professional)
- Kamailio: No hay certificación oficial

---

## 🔗 Enlaces Rápidos

### Descarga Rápida de Herramientas

| Herramienta | Sistema | Enlace |
|-------------|---------|--------|
| Wireshark | Windows/Mac/Linux | [Descargar](https://www.wireshark.org/download.html) |
| PuTTY | Windows | [Descargar](https://www.putty.org/) |
| Zoiper | Windows/Mac/Linux | [Descargar](https://www.zoiper.com/en/voip-softphone/download/current) |
| Linphone | Windows/Mac/Linux | [Descargar](https://www.linphone.org/technical-corner/linphone) |

### Cheat Sheets

- [SIP Methods](https://www.iana.org/assignments/sip-parameters/sip-parameters.xhtml#sip-parameters-1) - Métodos SIP oficiales
- [Kamailio Script Functions](https://www.kamailio.org/docs/modules/stable/) - Funciones disponibles
- [Asterisk CLI Commands](https://wiki.asterisk.org/wiki/display/AST/Asterisk+Command+Line+Interface) - Comandos CLI

---

## 💡 Tips de Búsqueda

Para encontrar información específica:

```
# Google:
"kamailio" + "error mensaje específico"
site:kamailio.org "término de búsqueda"

# Stack Overflow:
[kamailio] [nat] rtpproxy

# GitHub Issues:
repo:kamailio/kamailio is:issue "error"
```

---

**Última actualización:** 2024  
**Versión:** 1.0

**Contribuciones:** Si encuentras enlaces rotos o recursos útiles adicionales, reporta via GitHub Issues.
