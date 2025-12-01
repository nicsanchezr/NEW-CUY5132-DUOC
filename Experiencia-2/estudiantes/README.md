# Scripts de Instalación para Estudiantes

Esta carpeta contiene scripts de instalación automatizada para los laboratorios de VoIP.

---

## 📜 Scripts Disponibles

### install-asterisk.sh

**Descripción:** Instalación completa de Asterisk PBX con configuración básica.

**Uso:**
```bash
sudo bash install-asterisk.sh
```

**Qué hace:**
- ✅ Instala Asterisk
- ✅ Configura 3 extensiones (1001, 1002, 1003)
- ✅ Configura extensión de test (9999 - echo)
- ✅ Configura transporte UDP en puerto 5060
- ✅ Configura RTP (puertos 10000-20000)
- ✅ Detecta IPs automáticamente
- ✅ Habilita inicio automático
- ✅ Verifica instalación

**Tiempo:** ~3-5 minutos

**Labs:** 2.1, 2.2, 2.3, 2.4

---

### install-rtpproxy.sh

**Descripción:** Instalación de RTPProxy para relay de medios y NAT traversal.

**Uso:**
```bash
sudo bash install-rtpproxy.sh
```

**Qué hace:**
- ✅ Instala RTPProxy
- ✅ Configura socket de control (7722)
- ✅ Configura puertos RTP (10000-20000)
- ✅ Detecta IPs pública/privada automáticamente
- ✅ Configura modo NAT
- ✅ Habilita inicio automático
- ✅ Verifica instalación

**Tiempo:** ~2-3 minutos

**Labs:** 2.2, 2.3, 2.4

---

## 🚀 Guía de Uso

### Laboratorio 2.1: SBC Básico

**En instancia de Asterisk:**
```bash
cd ~/
git clone https://github.com/nicsanchezr/NEW-CUY5132-DUOC.git
cd NEW-CUY5132-DUOC/Experiencia-2/estudiantes
sudo bash install-asterisk.sh
```

**En instancia de Kamailio:**
- Seguir guía de laboratorio para configuración manual

---

### Laboratorio 2.2: NAT + RTPProxy

**En instancia de Kamailio:**
```bash
cd ~/NEW-CUY5132-DUOC/Experiencia-2/estudiantes
sudo bash install-rtpproxy.sh
```

Luego configurar Kamailio manualmente según guía.

---

### Laboratorio 2.3: TLS/SRTP

Usar mismos scripts, luego:
1. Generar certificados con OpenSSL
2. Editar `/etc/asterisk/pjsip.conf`
3. Descomentar secciones TLS/SRTP
4. Reiniciar servicios

---

## ⚠️ Requisitos Previos

### Antes de Ejecutar Scripts

1. **Instancia EC2 corriendo:**
   - Ubuntu 24.04 LTS
   - t2.micro (mínimo)
   - Conectada a Internet

2. **Security Groups configurados:**
   - Ver guía de laboratorio correspondiente
   - Configurar ANTES de ejecutar scripts

3. **Acceso SSH:**
   - Archivo `.pem` (Linux/Mac) o `.ppk` (Windows)
   - Conectado como usuario `ubuntu`

4. **Permisos sudo:**
   - Scripts requieren root (`sudo`)

---

## 🔐 Security Groups AWS

### Para Asterisk (Lab 2.1):
```
22   TCP  0.0.0.0/0      # SSH
5060 UDP  0.0.0.0/0      # SIP
10000-20000 UDP 0.0.0.0/0  # RTP
```

### Para Asterisk (Lab 2.2+):
```
22   TCP  Tu-IP              # SSH
5060 UDP  sg-kamailio        # SIP solo desde Kamailio
10000-20000 UDP sg-kamailio  # RTP solo desde Kamailio
```

### Para Kamailio (Lab 2.2+):
```
22   TCP  Tu-IP          # SSH
5060 UDP  0.0.0.0/0      # SIP
10000-20000 UDP 0.0.0.0/0  # RTP (para RTPProxy)
```

---

## 📊 Verificación Post-Instalación

### Verificar Asterisk

```bash
# Estado del servicio
sudo systemctl status asterisk

# CLI de Asterisk
sudo asterisk -rvvv

# Ver endpoints
asterisk -rx "pjsip show endpoints"

# Ver contactos registrados
asterisk -rx "pjsip show contacts"
```

**Salida esperada:**
```
Endpoint:  1001/1001                                 Not in use    0 of inf
Endpoint:  1002/1002                                 Not in use    0 of inf
Endpoint:  1003/1003                                 Not in use    0 of inf
```

---

### Verificar RTPProxy

```bash
# Estado del servicio
sudo systemctl status rtpproxy

# Ver socket de control
sudo ss -ulpn | grep 7722

# Ver logs
sudo tail -f /var/log/syslog | grep rtpproxy
```

**Salida esperada:**
```
udp   UNCONN 0   0   127.0.0.1:7722   0.0.0.0:*
```

---

## 🆘 Troubleshooting

### Asterisk no inicia

```bash
# Ver error específico
sudo journalctl -u asterisk -n 50

# Verificar configuración
sudo asterisk -cvvv

# Probar en foreground
sudo asterisk -cvvv
```

**Soluciones comunes:**
- Verificar IP en `pjsip.conf`
- Verificar permisos de archivos
- Verificar puerto 5060 no esté en uso

---

### RTPProxy no inicia

```bash
# Ver error específico
sudo journalctl -u rtpproxy -n 50

# Verificar configuración
cat /etc/default/rtpproxy

# Verificar IPs
curl ifconfig.me  # IP pública
hostname -I       # IP privada
```

**Soluciones comunes:**
- Verificar IPs en `/etc/default/rtpproxy`
- Verificar que puertos 10000-20000 estén libres
- Reiniciar servicio: `sudo systemctl restart rtpproxy`

---

### Script falla al ejecutar

**Error:** "Permission denied"
```bash
# Dar permisos de ejecución
chmod +x install-asterisk.sh
chmod +x install-rtpproxy.sh
```

**Error:** "Command not found"
```bash
# Actualizar sistema primero
sudo apt update
sudo apt upgrade -y
```

---

## 📖 Documentación Adicional

- **[Arquitectura General](../../docs/arquitectura-general.md)** - Cómo funciona todo
- **[Troubleshooting VoIP](../../docs/troubleshooting-voip.md)** - Solución de problemas
- **[Troubleshooting AWS](../../docs/troubleshooting-aws.md)** - Problemas AWS Academy
- **[Material Complementario](../material-complementario/)** - Cheat sheets y FAQs

---

## 💡 Tips

### Guardar IPs en Archivo

```bash
# Crear archivo con IPs actuales
echo "IP Pública: $(curl -s ifconfig.me)" > ~/current-ips.txt
echo "IP Privada: $(hostname -I | awk '{print $1}')" >> ~/current-ips.txt
cat ~/current-ips.txt
```

### Logs en Tiempo Real

```bash
# Ver todos los logs VoIP
sudo tail -f /var/log/syslog | grep -E 'asterisk|rtpproxy'
```

### Reiniciar Todo

```bash
# Reiniciar servicios VoIP
sudo systemctl restart asterisk rtpproxy
```

---

## 🔄 Actualizar Scripts

```bash
# Actualizar repositorio
cd ~/NEW-CUY5132-DUOC
git pull origin main

# Ver cambios
git log --oneline -5
```

---

## 📞 Soporte

**Problemas con scripts:**
1. Consultar [Troubleshooting](../../docs/troubleshooting-voip.md)
2. Revisar [Issues en GitHub](https://github.com/nicsanchezr/NEW-CUY5132-DUOC/issues)
3. Contactar al profesor

**Problemas de laboratorio:**
- Consultar guía de laboratorio correspondiente
- Ver material complementario
- Horario de consultas del profesor

---

**Última actualización:** Diciembre 2025  
**Versión:** 2.0
