# Troubleshooting AWS
## Problemas Comunes y Soluciones

Guía de solución de problemas específicos de AWS Academy para los laboratorios VoIP.

---

## 🔧 Problemas de Conectividad

### No puedo conectarme por SSH

#### Síntoma
```
ssh: connect to host X.X.X.X port 22: Connection timed out
```

#### Causas Comunes

**1. Security Group no permite SSH**

Verificar:
```
AWS Console → EC2 → Security Groups → [Tu SG] → Inbound rules
```

Debe tener:
```
Type: SSH
Protocol: TCP
Port: 22
Source: 0.0.0.0/0 (o tu IP específica)
```

**Solución:**
```
1. Ir a EC2 → Security Groups
2. Seleccionar el SG de tu instancia
3. Editar Inbound Rules
4. Agregar regla SSH si no existe
5. Save rules
```

**2. Instancia detenida**

Verificar:
```
AWS Console → EC2 → Instances
Estado debe ser: "Running" (verde)
```

**Solución:**
```
1. Seleccionar instancia
2. Instance State → Start Instance
3. Esperar a que estado = Running
4. Verificar nueva IP pública (cambia al reiniciar)
```

**3. IP Pública cambió**

AWS Academy asigna IPs públicas dinámicas. Al detener/iniciar, la IP cambia.

**Solución:**
```
1. Ir a EC2 → Instances
2. Seleccionar tu instancia
3. Copiar nueva "Public IPv4 address"
4. Actualizar conexión SSH con nueva IP
```

**4. Par de claves incorrecto**

**Solución:**
```
# Windows (PuTTY):
1. Descargar nuevo .ppk desde AWS Academy
2. PuTTY → Connection → SSH → Auth
3. Seleccionar archivo .ppk correcto

# Linux/Mac:
1. Descargar nuevo .pem desde AWS Academy
2. chmod 400 labsuser.pem
3. ssh -i labsuser.pem ubuntu@X.X.X.X
```

---

### No puedo acceder a puertos SIP/RTP

#### Síntoma
```
- Softphone no registra
- No hay audio en llamadas
- tcpdump no muestra tráfico SIP
```

#### Verificación

**1. Revisar Security Groups por Laboratorio**

**SG-Kamailio (Todos los Labs):**
```
EC2 → Security Groups → SG-Kamailio → Inbound Rules

┌──────────────────────────────────┐
│ Type       Port Range   Source   │
├──────────────────────────────────┤
│ SSH        22           0.0.0.0/0│ ← Administración
│ Custom UDP 5060         0.0.0.0/0│ ← SIP
│ Custom TCP 5061         0.0.0.0/0│ ← TLS (Lab 2.3+)
│ Custom UDP 10000-20000  0.0.0.0/0│ ← RTP/SRTP
└──────────────────────────────────┘
```

**SG-Asterisk (Lab 2.1 - CONFIGURACIÓN INICIAL):**
```
⚠️ En Lab 2.1, Asterisk temporalmente expuesto para aprendizaje:

┌──────────────────────────────────┐
│ Type       Port Range   Source   │
├──────────────────────────────────┤
│ SSH        22           0.0.0.0/0│ ← Admin
│ Custom UDP 5060         0.0.0.0/0│ ← SIP ⚠️ TEMPORAL
│ Custom UDP 10000-20000  0.0.0.0/0│ ← RTP ⚠️ TEMPORAL
└──────────────────────────────────┘
```

**SG-Asterisk (Lab 2.2+ - PRODUCCIÓN):**
```
✅ A partir de Lab 2.2, Asterisk se OCULTA completamente:

┌──────────────────────────────────────────┐
│ Type       Port Range   Source           │
├──────────────────────────────────────────┤
│ SSH        22           Tu-IP-Admin      │ ← Admin restringida
│ Custom UDP 5060         sg-XXXXX (SBC)   │ ← SIP solo desde Kamailio
│ Custom TCP 5061         sg-XXXXX (SBC)   │ ← TLS solo desde Kamailio (Lab 2.3+)
│ Custom UDP 10000-20000  sg-XXXXX (SBC)   │ ← RTP solo desde Kamailio
└──────────────────────────────────────────┘

IMPORTANTE: sg-XXXXX es el ID del Security Group de Kamailio
```

**Progresión de Seguridad:**
```
Lab 2.1: Asterisk público (aprendizaje) → ⚠️ NO producción
Lab 2.2: Asterisk privado (Kamailio relay) → ✓ Arquitectura correcta
Lab 2.3: + Cifrado TLS/SRTP → ✓ Producción
Lab 2.4: + Monitoreo/Defensa → ✓ Producción completa
```

**2. Verificar Outbound Rules**

Por defecto AWS permite todo tráfico saliente, pero verificar:
```
Outbound Rules → All traffic → 0.0.0.0/0 ✓
```

**Solución - Crear Security Groups Correctos:**

**Para Kamailio (SBC):**
```
1. EC2 → Security Groups → Create Security Group
   Name: SG-Kamailio-VoIP
   Description: Security group for VoIP SBC
   VPC: [Seleccionar el VPC de tu lab]

2. Agregar Inbound Rules:
   [Add Rule] → SSH → 22 → 0.0.0.0/0
   [Add Rule] → Custom UDP → 5060 → 0.0.0.0/0
   [Add Rule] → Custom TCP → 5061 → 0.0.0.0/0
   [Add Rule] → Custom UDP → 10000-20000 → 0.0.0.0/0

3. Asociar a instancia Kamailio:
   EC2 → Instances → [Kamailio] → Actions
   → Security → Change Security Groups
   → Seleccionar SG-Kamailio-VoIP
   → Save
```

**Para Asterisk (PBX) - Lab 2.2+:**
```
1. EC2 → Security Groups → Create Security Group
   Name: SG-Asterisk-PBX
   Description: Security group for Asterisk PBX (internal)
   VPC: [Mismo VPC de Kamailio]

2. Agregar Inbound Rules:
   [Add Rule] → SSH → 22 → [Tu IP pública]
   [Add Rule] → Custom UDP → 5060 → [SG-Kamailio-VoIP]
   [Add Rule] → Custom TCP → 5061 → [SG-Kamailio-VoIP]
   [Add Rule] → Custom UDP → 10000-20000 → [SG-Kamailio-VoIP]

   IMPORTANTE: En "Source" seleccionar el Security Group de Kamailio,
   NO poner 0.0.0.0/0

3. Asociar a instancia Asterisk:
   EC2 → Instances → [Asterisk] → Actions
   → Security → Change Security Groups
   → Seleccionar SG-Asterisk-PBX
   → Save
```

---

## 📱 Problemas con Softphones

### Softphone recomendado no funciona

**Softphones recomendados para los laboratorios:**

**Linphone (RECOMENDADO):**
- ✅ Multiplataforma (Windows, Mac, Linux, Android, iOS)
- ✅ Open Source
- ✅ Soporta TLS/SRTP (Lab 2.3)
- ✅ Interfaz simple
- 🔗 https://www.linphone.org/

**MicroSIP (Alternativa Windows):**
- ✅ Solo Windows
- ✅ Muy ligero (~3 MB)
- ✅ Soporta TLS/SRTP
- ✅ Portable (no requiere instalación)
- 🔗 https://www.microsip.org/

**Verificar configuración:**
```
Lab 2.1-2.2:
- Server: IP_PUBLICA_KAMAILIO
- Transport: UDP
- Port: 5060

Lab 2.3+:
- Server: IP_PUBLICA_KAMAILIO
- Transport: TLS
- Port: 5061
- Media encryption: SRTP (Mandatory)
```

---

## 💰 Problemas de Presupuesto

### "You have exceeded your lab budget"

#### Síntoma
```
No puedes iniciar instancias
Mensaje: Budget exceeded
```

#### Causas
- Instancias corriendo por mucho tiempo
- Instancias de tipo grande (t3.medium, etc.)
- Volúmenes EBS sin usar

#### Soluciones

**1. Detener instancias cuando no se usan**

```bash
# SIEMPRE detener al terminar sesión:
EC2 → Instances → [Seleccionar] → Instance State → Stop
```

**2. Usar instancias t2.micro/t3.micro**

Para labs VoIP, t2.micro es suficiente:
```
vCPU: 1
RAM: 1 GB
Costo: ~$0.0116/hora
```

**3. Eliminar recursos innecesarios**

```
# Snapshots antiguos:
EC2 → Snapshots → [Seleccionar] → Delete

# Volúmenes sin asociar:
EC2 → Volumes → [Available] → Delete

# IPs Elásticas sin usar:
EC2 → Elastic IPs → [No asociadas] → Release
```

**4. Monitorear uso**

```
AWS Academy Learner Lab → [Ver presupuesto]
Revisar diariamente el consumo
```

**5. Recrear Lab si es necesario**

Si el presupuesto se agotó:
```
1. Terminar todas las instancias
2. Esperar reset mensual (AWS Academy)
3. O solicitar nuevo Lab a instructor
```

---

## ⏱️ Problemas de Sesión

### "Your session has expired"

#### Causa
AWS Academy cierra la sesión después de 4 horas de inactividad.

#### Impacto
- ❌ Instancias se DETIENEN automáticamente
- ❌ IPs públicas cambian
- ✅ Datos en volúmenes EBS se conservan

#### Solución

**Para reanudar trabajo:**

```
1. Reiniciar sesión en AWS Academy
2. Ir a EC2 → Instances
3. Seleccionar instancias → Start
4. Esperar a Running
5. Anotar NUEVAS IPs públicas
6. Reconectar por SSH con nuevas IPs
7. Servicios se inician automáticamente (si están enabled)
```

**Para evitar pérdida de sesión:**

```
# En instancia, habilitar inicio automático de servicios:
sudo systemctl enable kamailio
sudo systemctl enable asterisk
sudo systemctl enable rtpproxy

# Cuando la instancia reinicie, servicios inician solos
```

---

## 🔄 Problemas con IPs

### IP pública cambia constantemente

#### Causa
AWS Academy no permite Elastic IPs permanentes. Las IPs públicas son dinámicas.

#### Impacto
- Configuraciones hardcodeadas dejan de funcionar
- Softphones pierden conexión
- Scripts necesitan actualizarse

#### Soluciones

**1. Usar IPs privadas para comunicación interna**

```bash
# En kamailio.cfg, usar IP PRIVADA de Asterisk:
#!define ASTERISK_IP "10.0.X.X"  # ← Privada, NO cambia

# NO usar:
#!define ASTERISK_IP "X.X.X.X"   # ← Pública, cambia
```

**2. Verificar IP actual**

```bash
# IP pública (vista desde Internet):
curl ifconfig.me

# IP privada (red AWS):
hostname -I

# Ambas IPs:
ip addr show
```

**3. Configurar RTPProxy con variable**

```bash
# Obtener IPs actuales en script:
PUBLIC_IP=$(curl -s ifconfig.me)
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Usar en RTPProxy:
rtpproxy -l $PRIVATE_IP -A $PUBLIC_IP
```

**4. Documentar IPs en cada sesión**

```
Crear archivo: /home/ubuntu/current_ips.txt

Contenido:
Fecha: 2024-XX-XX
IP Pública Kamailio: X.X.X.X
IP Privada Kamailio: 10.0.1.10
IP Privada Asterisk: 10.0.2.10
```

**5. Actualizar softphone con nueva IP**

```
Cada vez que cambien IPs:
1. Obtener nueva IP pública de Kamailio
2. Actualizar configuración del softphone
3. Eliminar cuenta antigua
4. Crear nueva con IP actualizada
```

---

## 🌐 Problemas de Red

### No hay comunicación entre instancias

#### Síntoma
```
- Kamailio no puede contactar Asterisk
- Ping falla entre instancias
- SIP timeout en comunicación interna
```

#### Verificaciones

**1. Mismo VPC y Subnet**

```bash
# En AWS Console:
EC2 → Instances → Seleccionar ambas

Verificar:
- VPC: Deben estar en el mismo VPC
- Subnet: Pueden estar en diferentes subnets del mismo VPC
```

**2. Security Groups permiten tráfico interno**

```
Security Group de Asterisk debe permitir:
- Source: Security Group de Kamailio (sg-XXXXX)
- O Source: IP privada de Kamailio (10.0.X.X/32)
```

**3. Route Tables correctas**

```
VPC → Route Tables → [Tu RT]

Debe tener ruta local:
Destination: 10.0.0.0/16
Target: local
Status: Active
```

#### Solución

**Configurar Security Group de Asterisk:**

```
Inbound Rules:
┌────────────────────────────────────────┐
│ Type       Port    Source              │
├────────────────────────────────────────┤
│ Custom UDP 5060    sg-XXXXX (Kamailio) │← SIP desde Kamailio
│ Custom TCP 5061    sg-XXXXX (Kamailio) │← TLS desde Kamailio
│ Custom UDP 10000-  sg-XXXXX (Kamailio) │← RTP desde Kamailio
│            20000                        │
│ SSH        22      Mi IP               │← Admin
└────────────────────────────────────────┘
```

**Verificar conectividad:**

```bash
# Desde Kamailio:
ping -c 3 10.0.2.10  # IP privada de Asterisk

# Debe responder:
64 bytes from 10.0.2.10: icmp_seq=1 ttl=64 time=0.3 ms
```

---

## 🖥️ Problemas con Instancias

### Instancia "Impaired" o "Failed"

#### Síntoma
```
Status checks: 1/2 checks passed
System Status: Impaired
```

#### Causa
Problema de hardware subyacente en AWS.

#### Solución

**1. Detener y reiniciar (NO reboot)**

```
EC2 → Instances → [Tu instancia]
→ Instance State → Stop
→ Esperar que se detenga completamente
→ Instance State → Start
```

Esto mueve la instancia a nuevo hardware.

**2. Si persiste: Crear nuevo AMI**

```
1. Create Image de la instancia actual
2. Launch nueva instancia desde ese AMI
3. Terminar instancia problemática
```

---

### Instancia muy lenta

#### Causas

**1. Tipo de instancia muy pequeño**

```bash
# Verificar recursos:
htop

# Si RAM o CPU al 100%, considerar:
t2.micro → t3.small (más RAM)
```

**2. Disco lleno**

```bash
# Verificar espacio:
df -h

# Limpiar logs si es necesario:
sudo journalctl --vacuum-time=2d
sudo apt clean
```

**3. Procesos colgados**

```bash
# Ver procesos consumiendo CPU:
top

# Matar procesos problemáticos:
sudo kill -9 <PID>
```

---

## 📦 Problemas de Almacenamiento

### "No space left on device"

#### Síntoma
```
E: Write error - write (28: No space left on device)
```

#### Verificación

```bash
# Ver uso de disco:
df -h

# Resultado problemático:
/dev/xvda1      8.0G  7.8G     0  100% /
```

#### Solución

**1. Limpiar archivos temporales**

```bash
# Limpiar cache de apt:
sudo apt clean
sudo apt autoclean

# Limpiar logs antiguos:
sudo journalctl --vacuum-time=3d

# Limpiar archivos temporales:
sudo rm -rf /tmp/*

# Verificar mejora:
df -h
```

**2. Identificar archivos grandes**

```bash
# Encontrar directorios grandes:
sudo du -sh /* 2>/dev/null | sort -hr | head -10

# Encontrar archivos grandes:
sudo find / -type f -size +100M 2>/dev/null
```

**3. Aumentar tamaño del volumen**

```
EC2 → Volumes → [Tu volumen] → Modify Volume
→ Aumentar Size (ej: 8 → 16 GB)
→ Modify

# Luego en la instancia:
sudo growpart /dev/xvda 1
sudo resize2fs /dev/xvda1

# Verificar:
df -h
```

---

## 🔐 Problemas de Permisos

### "Permission denied" al ejecutar scripts

#### Solución

```bash
# Dar permisos de ejecución:
chmod +x script.sh

# Si necesitas sudo:
sudo chmod +x script.sh
```

### No puedo editar archivos de configuración

#### Solución

```bash
# Usar sudo para editar:
sudo nano /etc/kamailio/kamailio.cfg

# O cambiar owner (no recomendado en producción):
sudo chown ubuntu:ubuntu /etc/kamailio/kamailio.cfg
```

---

## ⚡ Quick Checks

### Checklist rápido de problemas AWS

```bash
# 1. ¿Instancia corriendo?
EC2 → Instances → Estado = Running ✓

# 2. ¿Security Groups correctos?
EC2 → Security Groups → Verificar puertos según Lab ✓

# 3. ¿IP pública correcta?
curl ifconfig.me  # Anotar y verificar

# 4. ¿Puedo hacer SSH?
ssh -i key.pem ubuntu@IP_PUBLICA ✓

# 5. ¿Servicios corriendo?
sudo systemctl status kamailio asterisk ✓

# 6. ¿Puertos escuchando?
sudo netstat -tulpn | grep -E '5060|5061' ✓

# 7. ¿Hay espacio en disco?
df -h  # Debe tener >10% libre ✓

# 8. ¿Presupuesto disponible?
AWS Academy → Ver budget ✓
```

---

## 📞 Escenarios Específicos

### Scenario: "Todo funcionaba ayer, hoy no"

**Causa más probable:** IP pública cambió

**Solución:**
```bash
# 1. Obtener nueva IP pública
curl ifconfig.me

# 2. Actualizar softphone con nueva IP

# 3. Verificar servicios
sudo systemctl status kamailio asterisk

# 4. Si servicios down:
sudo systemctl restart kamailio asterisk rtpproxy
```

---

### Scenario: "Funcionó en clase, no en casa"

**Causa más probable:** Firewall local/ISP

**Solución:**
```bash
# 1. Verificar desde otra red (datos móviles)

# 2. Si funciona con móvil → Problema es tu red local:
   - Router bloqueando puertos SIP
   - ISP bloqueando VoIP
   - Firewall Windows

# 3. Soluciones:
   - Probar con VPN
   - Usar WiFi de universidad
   - Configurar Port Forwarding en router
   - Desactivar temporalmente firewall para probar
```

---

### Scenario: "Lab 2.2 funcionó, Lab 2.3 no registra"

**Causa más probable:** Puerto TLS 5061 no configurado

**Solución:**
```bash
# 1. Verificar Security Group tiene puerto 5061 TCP
EC2 → Security Groups → SG-Kamailio → Inbound Rules
   → Debe tener: Custom TCP 5061 0.0.0.0/0

# 2. Verificar Kamailio escucha en 5061
sudo netstat -tulpn | grep 5061

# 3. Verificar certificados existen
ls -l /etc/kamailio/tls/

# 4. Softphone debe usar:
   - Transport: TLS (NO UDP)
   - Port: 5061 (NO 5060)
```

---

## 📚 Recursos Adicionales

### Documentación AWS
- [AWS Academy](https://awsacademy.instructure.com/)
- [EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [VPC User Guide](https://docs.aws.amazon.com/vpc/)
- [Security Groups Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)

### Monitoreo
```bash
# CloudWatch (AWS Console):
EC2 → Instances → Monitoring → View in CloudWatch

# Métricas útiles:
- CPU Utilization
- Network In/Out
- Disk Read/Write
- Status Check Failed
```

---

## 🎯 Progresión de Laboratorios

### Lab 2.1: Configuración Inicial
```
✓ Kamailio con IP pública
⚠️ Asterisk con IP pública (TEMPORAL)
❌ Sin RTPProxy
❌ Sin TLS/SRTP
```

### Lab 2.2: Producción Básica
```
✓ Kamailio con IP pública
✓ Asterisk con IP PRIVADA (oculto)
✓ RTPProxy relay de medios
❌ Sin TLS/SRTP
```

### Lab 2.3: Producción Segura
```
✓ Kamailio con IP pública
✓ Asterisk IP privada
✓ RTPProxy
✓ TLS/SRTP (cifrado)
```

### Lab 2.4: Producción Completa
```
✓ Kamailio con IP pública
✓ Asterisk IP privada
✓ RTPProxy
✓ TLS/SRTP
✓ sngrep (monitoreo)
✓ fail2ban (defensa)
```

---

**Última actualización:** Diciembre 2025 
**Versión:** 2.0

**💡 Tip:** Documenta cada sesión de lab con las IPs actuales, configuraciones aplicadas, y Security Groups utilizados. Esto te ahorrará mucho tiempo en troubleshooting.
