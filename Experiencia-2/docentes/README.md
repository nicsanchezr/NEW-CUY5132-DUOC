# Scripts para Docentes - Experiencia 2

⚠️ **Solo para uso docente** - Scripts de instalación rápida para demostración en clase

---

## 📋 Contenido

Scripts automatizados para configurar rápidamente ambientes de demostración:

| Script | Lab | Tiempo | Descripción |
|--------|-----|--------|-------------|
| `install-kamailio-sbc-quick.sh` | 2.1 | ~10 min | Kamailio SBC básico |
| `install-nat-rtpproxy-quick.sh` | 2.2 | ~10 min | RTPProxy + configuración NAT |
| `install-tls-srtp-quick.sh` | 2.3 | ~15 min | TLS en Kamailio + certificados |
| `configure-asterisk-tls-srtp.sh` | 2.3 | ~5 min | TLS/SRTP en Asterisk |

**Tiempo total para ambiente completo:** ~40 minutos

---

## 🎯 Propósito

Estos scripts están diseñados para:

- ✅ **Demostración en clase:** Mostrar configuraciones funcionando rápidamente
- ✅ **Troubleshooting:** Verificar configuraciones de referencia
- ✅ **Preparación de clase:** Tener ambientes listos antes de la sesión
- ❌ **NO para estudiantes:** Ellos deben seguir las guías paso a paso

---

## 🚀 Uso Rápido

### Instalación Completa (Labs 2.1 + 2.2 + 2.3)

```bash
# 1. Clonar repositorio
git clone https://github.com/nicsanchezr/NEW-CUY5132-DUOC.git
cd NEW-CUY5132-DUOC/Experiencia-2/docentes/

# 2. Lab 2.1 - SBC Básico (en instancia Kamailio)
chmod +x install-kamailio-sbc-quick.sh
sudo ./install-kamailio-sbc-quick.sh
# Ingresar IP privada de Asterisk cuando lo solicite

# 3. Lab 2.2 - NAT/RTPProxy (misma instancia Kamailio)
chmod +x install-nat-rtpproxy-quick.sh
sudo ./install-nat-rtpproxy-quick.sh

# 4. Lab 2.3 - TLS/SRTP Kamailio (misma instancia)
chmod +x install-tls-srtp-quick.sh
sudo ./install-tls-srtp-quick.sh

# 5. Lab 2.3 - TLS/SRTP Asterisk (en instancia Asterisk)
chmod +x configure-asterisk-tls-srtp.sh
sudo ./configure-asterisk-tls-srtp.sh
```

---

### Instalación por Lab Individual

#### Lab 2.1 únicamente
```bash
sudo ./install-kamailio-sbc-quick.sh
```

#### Lab 2.2 únicamente (requiere Lab 2.1 previo)
```bash
sudo ./install-nat-rtpproxy-quick.sh
```

#### Lab 2.3 únicamente (requiere Labs 2.1 y 2.2 previos)
```bash
# En Kamailio:
sudo ./install-tls-srtp-quick.sh

# En Asterisk:
sudo ./configure-asterisk-tls-srtp.sh
```

---

## 📐 Arquitectura de Referencia

```
┌─────────────────────┐
│  Internet/Clientes  │
│   (Softphones)      │
└──────────┬──────────┘
           │ SIP/RTP
           ↓
┌──────────────────────────────┐
│   Instancia EC2 Kamailio     │
│                              │
│  ┌────────────────────────┐  │
│  │   Kamailio SBC         │  │
│  │   - Puerto 5060 (SIP)  │  │
│  │   - Puerto 5061 (TLS)  │  │
│  └───────────┬────────────┘  │
│              │                │
│  ┌───────────┴────────────┐  │
│  │   RTPProxy             │  │
│  │   - Puerto 7722        │  │
│  │   - Puertos 10000-20k  │  │
│  └────────────────────────┘  │
└──────────────┬───────────────┘
               │ SIP interno
               ↓
┌──────────────────────────────┐
│   Instancia EC2 Asterisk     │
│                              │
│  ┌────────────────────────┐  │
│  │   Asterisk PBX         │  │
│  │   - Puerto 5060        │  │
│  │   - Puerto 5061 (TLS)  │  │
│  │   - TLS/SRTP           │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

---

## ⚙️ Configuraciones Aplicadas

### Lab 2.1: SBC Básico
- ✅ Kamailio como proxy SIP
- ✅ Routing entre clientes y Asterisk
- ✅ Record-Route para diálogos
- ✅ Location service (REGISTER)
- ✅ Logs detallados

### Lab 2.2: NAT/RTPProxy
- ✅ Detección automática de NAT
- ✅ RTPProxy para relay de medios
- ✅ Fix Contact y Via headers
- ✅ Manejo de clientes tras NAT
- ✅ Keepalive para clientes NAT
- ✅ RTPProxy con IPs pública/privada

### Lab 2.3: TLS/SRTP
- ✅ Certificados autofirmados generados
- ✅ TLS en puerto 5061 (Kamailio)
- ✅ Transport TLS en Asterisk
- ✅ SRTP para cifrado de medios (SDES)
- ✅ Verificación de cifrado
- ✅ TLS 1.2+ configurado

---

## 🔍 Verificación Post-Instalación

### Verificar Servicios

```bash
# Estado de servicios
sudo systemctl status kamailio
sudo systemctl status rtpproxy
sudo systemctl status asterisk

# Puertos abiertos
sudo netstat -tulpn | grep -E '5060|5061|7722'

# Logs en tiempo real
sudo tail -f /var/log/syslog | grep -E 'kamailio|rtpproxy'
```

---

### Pruebas por Lab

**Lab 2.1:**
```bash
# Verificar routing básico
sudo kamailio -c

# Ver registros
kamcmd ul.dump
```

**Lab 2.2:**
```bash
# Verificar RTPProxy
sudo systemctl status rtpproxy

# Ver sesiones RTP activas
sudo netstat -tunap | grep rtpproxy
```

**Lab 2.3:**
```bash
# Verificar TLS en Kamailio
openssl s_client -connect localhost:5061 -showcerts

# Verificar TLS en Asterisk
openssl s_client -connect localhost:5061

# Ver endpoints SRTP
asterisk -rx "pjsip show endpoints"
```

---

## 🆘 Troubleshooting Rápido

### Problema: Kamailio no inicia

```bash
# Ver logs de error
sudo journalctl -u kamailio -n 50

# Verificar sintaxis
sudo kamailio -c

# Revisar permisos
sudo chown -R kamailio:kamailio /etc/kamailio/
```

---

### Problema: No hay audio

```bash
# Verificar RTPProxy
sudo systemctl status rtpproxy

# Ver puertos RTP
sudo netstat -tulpn | grep rtpproxy

# Revisar Security Groups AWS
# Verificar que puertos 10000-20000 UDP estén abiertos
```

---

### Problema: TLS no funciona

```bash
# Verificar certificados
ls -l /etc/kamailio/tls/
ls -l /etc/asterisk/keys/

# Ver si puerto 5061 está escuchando
sudo netstat -tulpn | grep 5061

# Probar conexión TLS
openssl s_client -connect IP_PUBLICA:5061
```

---

### Problema: SRTP no funciona

```bash
# En Asterisk, verificar endpoints
asterisk -rx "pjsip show endpoint 1001"

# Debe mostrar: media_encryption : sdes

# En Wireshark, verificar SDP
# Debe contener líneas: a=crypto:
```

---

## 📊 Diferencias con Scripts de Estudiantes

| Aspecto | Estudiantes | Docentes |
|---------|-------------|----------|
| **Propósito** | Aprendizaje paso a paso | Demostración rápida |
| **Instalación** | Solo Asterisk automatizado | Todo automatizado |
| **Configuración** | Manual (Kamailio) | Automática |
| **Tiempo** | 3-4 horas por lab | 10-15 min por lab |
| **Explicaciones** | Detalladas en guías | Mínimas en scripts |
| **Backups** | Manual | Automático |

---

## ⚠️ Advertencias Importantes

### ❌ NO Compartir con Estudiantes

Estos scripts automatizan el proceso de aprendizaje que los estudiantes deben realizar manualmente. Compartirlos:
- Reduce el aprendizaje práctico
- Impide desarrollar habilidades de troubleshooting
- Invalida los objetivos de las guías de laboratorio

---

### ⚠️ Solo para Ambientes de Prueba

Estas configuraciones usan:
- Certificados autofirmados
- Configuraciones simplificadas
- Sin hardening de seguridad
- NO aptas para producción

---

### ⏱️ Caducidad de Instancias AWS

Recordar que AWS Academy Learner Lab:
- Las instancias se detienen al terminar sesión
- El presupuesto es limitado (~$50 USD)
- Preparar ambientes poco antes de clase
- IPs públicas cambian al reiniciar

---

## 🔐 Security Groups por Lab

### Lab 2.1

**SG-Kamailio:**
```
22   TCP  Tu-IP        # SSH
5060 UDP  0.0.0.0/0    # SIP
```

**SG-Asterisk (temporal):**
```
22   TCP  Tu-IP            # SSH
5060 UDP  0.0.0.0/0        # SIP (temporal)
10000-20000 UDP 0.0.0.0/0  # RTP (temporal)
```

---

### Lab 2.2

**SG-Kamailio:**
```
22   TCP  Tu-IP        # SSH
5060 UDP  0.0.0.0/0    # SIP
10000-20000 UDP 0.0.0.0/0  # RTP
```

**SG-Asterisk (PRIVADO):**
```
22   TCP  Tu-IP              # SSH
5060 UDP  sg-kamailio        # SIP solo desde Kamailio
10000-20000 UDP sg-kamailio  # RTP solo desde Kamailio
```

---

### Lab 2.3

**SG-Kamailio:**
```
22   TCP  Tu-IP        # SSH
5060 UDP  0.0.0.0/0    # SIP
5061 TCP  0.0.0.0/0    # TLS
10000-20000 UDP 0.0.0.0/0  # RTP
```

**SG-Asterisk:**
```
22   TCP  Tu-IP              # SSH
5060 UDP  sg-kamailio        # SIP
5061 TCP  sg-kamailio        # TLS
10000-20000 UDP sg-kamailio  # RTP
```

---

## 📚 Recursos Adicionales

- **Guías de laboratorio:** Disponibles en plataforma educativa
- **Troubleshooting general:** Ver `/docs/troubleshooting-voip.md`
- **Problemas AWS:** Ver `/docs/troubleshooting-aws.md`
- **Arquitectura:** Ver `/docs/arquitectura-general.md`
- **Material complementario:** Ver `/material-complementario/`

---

## 📋 Checklist Pre-Clase

```
Lab 2.1:
☐ Instancias EC2 creadas (Kamailio + Asterisk)
☐ Security Groups configurados
☐ Script Lab 2.1 ejecutado sin errores
☐ Kamailio escuchando puerto 5060
☐ Asterisk con extensiones configuradas
☐ Softphone de prueba registra
☐ Llamada de prueba exitosa

Lab 2.2:
☐ Lab 2.1 funcionando
☐ Security Groups actualizados (Asterisk privado)
☐ Script Lab 2.2 ejecutado sin errores
☐ RTPProxy corriendo (puerto 7722)
☐ Audio funciona con cliente NAT
☐ RTPProxy relay visible en netstat

Lab 2.3:
☐ Labs 2.1 y 2.2 funcionando
☐ Security Groups con puerto 5061 TCP
☐ Scripts Lab 2.3 ejecutados (Kamailio + Asterisk)
☐ Puertos 5061 escuchando
☐ Certificados generados
☐ Softphone con TLS registra
☐ Wireshark muestra TLS y SRTP
```

---

## 📄 Actualización de Scripts

Para actualizar a la última versión:

```bash
cd NEW-CUY5132-DUOC/
git pull origin main
cd Experiencia-2/docentes/
# Scripts actualizados disponibles
```

---

## 💡 Tips Pedagógicos

### Demostración en Clase

**Flujo recomendado:**
1. Mostrar arquitectura en diagrama
2. Ejecutar script Lab 2.1 explicando componentes
3. Mostrar registro de softphone
4. Capturar tráfico con sngrep
5. Explicar flujo SIP visible en logs
6. Repetir para Labs 2.2 y 2.3

**Herramientas para demo:**
- `sngrep` - Mostrar flujo SIP en tiempo real
- `wireshark` - Análisis detallado (TLS, SRTP)
- `tail -f /var/log/syslog` - Logs en vivo

---

### Puntos Clave a Destacar

**Lab 2.1:**
- Separación SBC vs PBX
- Record-Route para diálogos
- Forwarding transparente

**Lab 2.2:**
- NAT detection automática
- RTPProxy como relay
- Ocultación de Asterisk

**Lab 2.3:**
- TLS para señalización
- SRTP para medios
- Verificación con Wireshark

---

## 📞 Soporte

**Si encuentras problemas con los scripts:**

1. Revisar logs: `sudo journalctl -u kamailio -n 100`
2. Verificar requisitos previos (Ubuntu 24.04, Security Groups)
3. Consultar troubleshooting en `/docs/`
4. Reportar issue en GitHub con logs completos

---

## 🔄 Changelog

**Versión 2.0** (Diciembre 2024)
- Scripts reorganizados por lab individual
- Backups automáticos en cada paso
- Verificación automática de requisitos
- Logs más detallados
- Soporte TLS 1.2+

**Versión 1.0** (2024)
- Versión inicial

---

**Última actualización:** Diciembre 2024  
**Versión:** 2.0  
**Mantenedor:** Nicolas Sanchez (nicsanchezr)  
**GitHub:** https://github.com/nicsanchezr/NEW-CUY5132-DUOC
