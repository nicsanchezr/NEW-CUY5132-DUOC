# NEW-CUY5132-DUOC

Scripts de instalación y documentación técnica para el curso **CUY5132 - Comunicaciones Unificadas** de DUOC UC.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2024.04-orange.svg)](https://ubuntu.com/)
[![AWS](https://img.shields.io/badge/Cloud-AWS%20Academy-orange.svg)](https://aws.amazon.com/training/awsacademy/)

---

## 📋 Descripción

Este repositorio contiene **scripts de instalación automática**, **material complementario** y **documentación técnica** para los laboratorios de VoIP del curso CUY5132.

### ⚠️ Importante

Este repositorio contiene **SOLO**:
- ✅ Scripts de instalación (`.sh`)
- ✅ Material complementario (cheat sheets, FAQs)
- ✅ Documentación técnica

**NO contiene:**
- ❌ Guías de laboratorio (se distribuyen por plataforma DUOC)
- ❌ Presentaciones PowerPoint
- ❌ Material didáctico principal
- ❌ Evaluaciones

---

## 🎯 Tecnologías

Los laboratorios implementan una arquitectura VoIP empresarial con:

- **[Kamailio](https://www.kamailio.org/)** - Session Border Controller (SBC)
- **[Asterisk](https://www.asterisk.org/)** - Private Branch Exchange (PBX)
- **[RTPProxy](http://www.rtpproxy.org/)** - Relay de medios RTP/SRTP
- **[sngrep](https://github.com/irontec/sngrep)** - Análisis de tráfico SIP
- **[fail2ban](https://www.fail2ban.org/)** - Sistema de prevención de intrusiones

**Plataforma:** Ubuntu 24.04 LTS en AWS Academy

---

## 📁 Estructura del Repositorio

```
NEW-CUY5132-DUOC/
│
├── README.md                          # Este archivo
├── LICENSE                            # Licencia MIT
│
├── Experiencia-1/                     # (Pendiente)
│   └── README.md
│
├── Experiencia-2/                     # Laboratorios VoIP
│   ├── README.md                      # Descripción de EA2
│   │
│   ├── estudiantes/                   # Scripts para estudiantes
│   │   ├── README.md
│   │   ├── install-asterisk.sh        # Instalación Asterisk
│   │   └── install-rtpproxy.sh        # Instalación RTPProxy
│   │
│   ├── docentes/                      # Scripts para docentes
│   │   └── README.md
│   │
│   └── material-complementario/       # Material de apoyo
│       ├── Material-Complementario-Act-2.1.md
│       ├── Material-Complementario-Act-2.2.md
│       ├── Material-Complementario-Act-2.3.md
│       └── Material-Complementario-Act-2.4.md
│
├── Experiencia-3/                     # (Pendiente)
│   └── README.md
│
└── docs/                              # Documentación técnica
    ├── arquitectura-general.md        # Arquitectura del sistema
    ├── troubleshooting-aws.md         # Solución problemas AWS
    ├── troubleshooting-voip.md        # Solución problemas VoIP
    ├── referencias.md                 # Referencias y recursos
    └── Bibliografias-APA7-Presentaciones-EA2.md
```

---

## 🚀 Inicio Rápido

### Para Estudiantes

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/nicsanchezr/NEW-CUY5132-DUOC.git
   cd NEW-CUY5132-DUOC
   ```

2. **Navegar a scripts de estudiantes:**
   ```bash
   cd Experiencia-2/estudiantes
   ```

3. **Ejecutar scripts de instalación:**
   ```bash
   # Instalar Asterisk (PBX)
   sudo bash install-asterisk.sh
   
   # Instalar RTPProxy (Lab 2.2+)
   sudo bash install-rtpproxy.sh
   ```

4. **Consultar material complementario:**
   ```bash
   cd ../material-complementario
   # Ver cheat sheets, FAQs y ejercicios
   ```

### Para Docentes

Ver instrucciones específicas en [`Experiencia-2/docentes/README.md`](Experiencia-2/docentes/README.md)

---

## 📚 Experiencia de Aprendizaje 2: VoIP

La EA2 consta de 4 laboratorios progresivos que construyen una arquitectura VoIP empresarial completa:

### Lab 2.1: SBC Básico
**Objetivo:** Implementar Session Border Controller con Kamailio

- Arquitectura SBC básica
- Routing SIP
- Separación SBC vs PBX
- Llamadas básicas

**Tecnologías:** Kamailio, Asterisk

### Lab 2.2: Gestión NAT
**Objetivo:** Ocultar Asterisk y permitir usuarios remotos

- RTPProxy para relay de medios
- NAT traversal
- Ocultación de topología
- Asterisk en red privada

**Tecnologías:** Kamailio, Asterisk, RTPProxy

### Lab 2.3: Cifrado TLS/SRTP
**Objetivo:** Cifrado end-to-end de comunicaciones

- TLS para señalización (puerto 5061)
- SRTP para medios
- Certificados digitales
- Verificación con Wireshark

**Tecnologías:** Kamailio, Asterisk, RTPProxy, OpenSSL

**⚠️ CRÍTICO:** Este laboratorio es requerido para evaluación sumativa

### Lab 2.4: Monitoreo y Defensa
**Objetivo:** Completar arquitectura de producción

- sngrep para análisis tiempo real
- fail2ban para defensa activa
- Detección de ataques
- Hardening del sistema

**Tecnologías:** Kamailio, Asterisk, RTPProxy, sngrep, fail2ban

---

## 🛠️ Scripts Disponibles

### Estudiantes

| Script | Descripción | Lab |
|--------|-------------|-----|
| `install-asterisk.sh` | Instalación completa de Asterisk con 3 extensiones | 2.1+ |
| `install-rtpproxy.sh` | Instalación de RTPProxy para NAT traversal | 2.2+ |

### Características de los Scripts

✅ Instalación automatizada  
✅ Configuración pre-cargada  
✅ Detección automática de IPs  
✅ Verificación de instalación  
✅ Logs detallados  
✅ Manejo de errores  
✅ Backup de configuraciones  

---

## 📖 Documentación

### Material Complementario

Cheat sheets, FAQs y ejercicios para cada laboratorio:

- **[Lab 2.1](Experiencia-2/material-complementario/Material-Complementario-Act-2.1.md)** - SBC Básico
- **[Lab 2.2](Experiencia-2/material-complementario/Material-Complementario-Act-2.2.md)** - NAT/RTPProxy
- **[Lab 2.3](Experiencia-2/material-complementario/Material-Complementario-Act-2.3.md)** - TLS/SRTP
- **[Lab 2.4](Experiencia-2/material-complementario/Material-Complementario-Act-2.4.md)** - Monitoreo/Defensa

### Documentación Técnica

- **[Arquitectura General](docs/arquitectura-general.md)** - Arquitectura de los laboratorios
- **[Troubleshooting AWS](docs/troubleshooting-aws.md)** - Solución de problemas AWS Academy
- **[Troubleshooting VoIP](docs/troubleshooting-voip.md)** - Diagnóstico de problemas VoIP
- **[Referencias](docs/referencias.md)** - Enlaces y recursos útiles
- **[Bibliografías APA7](docs/Bibliografias-APA7-Presentaciones-EA2.md)** - Referencias bibliográficas

---

## 💻 Requisitos

### Requisitos AWS Academy

- Cuenta AWS Academy Learner Lab activa
- Instancias EC2 Ubuntu 24.04 LTS
- Security Groups correctamente configurados
- Presupuesto disponible (~$50 USD para todo el semestre)

### Tipos de Instancia Recomendados

- **Kamailio:** t2.micro (1 vCPU, 1 GB RAM)
- **Asterisk:** t2.micro (1 vCPU, 1 GB RAM)

**Total estimado:** ~$0.023/hora (ambas instancias)

### Softphones Recomendados

#### ⭐ Linphone (Multiplataforma)
- **Descarga:** https://www.linphone.org/
- **Características:** Open Source, TLS/SRTP completo
- **Plataformas:** Windows, Mac, Linux, Android, iOS

#### ⭐ MicroSIP (Windows)
- **Descarga:** https://www.microsip.org/
- **Características:** Portable, ligero (~3 MB)
- **Plataforma:** Windows

❌ **NO usar Zoiper** - Requiere versión PRO para TLS/SRTP

---

## 🔐 Security Groups AWS

### Lab 2.1: Configuración Inicial

**SG-Kamailio:**
```
22   TCP  0.0.0.0/0      # SSH
5060 UDP  0.0.0.0/0      # SIP
10000-20000 UDP 0.0.0.0/0  # RTP
```

**SG-Asterisk (temporal):**
```
22   TCP  0.0.0.0/0      # SSH
5060 UDP  0.0.0.0/0      # SIP
10000-20000 UDP 0.0.0.0/0  # RTP
```

### Lab 2.2+: Producción

**SG-Kamailio:**
```
22   TCP  Tu-IP          # SSH
5060 UDP  0.0.0.0/0      # SIP
10000-20000 UDP 0.0.0.0/0  # RTP
```

**SG-Asterisk (privado):**
```
22   TCP  Tu-IP              # SSH
5060 UDP  sg-kamailio        # SIP solo desde Kamailio
10000-20000 UDP sg-kamailio  # RTP solo desde Kamailio
```

### Lab 2.3+: Con TLS

Agregar a ambos Security Groups:
```
5061 TCP  0.0.0.0/0 (Kamailio)    # SIPS/TLS
5061 TCP  sg-kamailio (Asterisk)  # SIPS/TLS
```

---

## 🆘 Troubleshooting

### Problema: Softphone no registra

**Verificar:**
1. Security Groups correctos
2. Kamailio corriendo: `systemctl status kamailio`
3. Puerto 5060 escuchando: `netstat -tulpn | grep 5060`
4. IP correcta en softphone (IP pública de Kamailio)

**Más información:** [Troubleshooting VoIP](docs/troubleshooting-voip.md)

### Problema: No hay audio en llamadas

**Verificar:**
1. RTPProxy corriendo (Lab 2.2+): `systemctl status rtpproxy`
2. Puertos 10000-20000 abiertos en Security Groups
3. RTPProxy configurado con IPs correctas

**Más información:** [Troubleshooting VoIP](docs/troubleshooting-voip.md#problemas-de-audio)

### Problema: IP pública cambió

**Solución:**
1. Obtener nueva IP: `curl ifconfig.me`
2. Actualizar softphone con nueva IP
3. Reiniciar servicios: `systemctl restart kamailio asterisk rtpproxy`

**Más información:** [Troubleshooting AWS](docs/troubleshooting-aws.md#ip-pública-cambia-constantemente)

---

## 🤝 Contribuciones

Este repositorio es mantenido por el equipo docente de CUY5132.

### Reportar Problemas

Si encuentras un problema con los scripts o documentación:

1. Verifica que no esté ya reportado en [Issues](https://github.com/nicsanchezr/NEW-CUY5132-DUOC/issues)
2. Crea un nuevo Issue con:
   - Descripción clara del problema
   - Pasos para reproducir
   - Logs relevantes
   - Sistema operativo y versiones

### Sugerir Mejoras

Las sugerencias son bienvenidas! Abre un Issue con la etiqueta "enhancement".

---

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

## 👥 Equipo Docente

**Profesor:** Nicolas Sanchez  
**Institución:** DUOC UC  
**Curso:** CUY5132 - Comunicaciones Unificadas  
**GitHub:** [@nicsanchezr](https://github.com/nicsanchezr)

---

## 📞 Soporte

### Para Estudiantes

1. **Consultar documentación:**
   - [Material Complementario](Experiencia-2/material-complementario/)
   - [Troubleshooting](docs/)

2. **Revisar Issues existentes:**
   - [GitHub Issues](https://github.com/nicsanchezr/NEW-CUY5132-DUOC/issues)

3. **Contactar al profesor:**
   - Durante horario de clases
   - Oficina virtual (según calendario)

### Para Docentes

Ver [Documentación para Docentes](Experiencia-2/docentes/README.md)

---

## 🔗 Enlaces Útiles

### Documentación Oficial

- [Kamailio Documentation](https://www.kamailio.org/wikidocs/)
- [Asterisk Wiki](https://wiki.asterisk.org/)
- [RTPProxy GitHub](https://github.com/sippy/rtpproxy)
- [AWS Academy](https://awsacademy.instructure.com/)

### Herramientas

- [Linphone](https://www.linphone.org/) - Softphone recomendado
- [MicroSIP](https://www.microsip.org/) - Softphone Windows
- [Wireshark](https://www.wireshark.org/) - Análisis de tráfico
- [PuTTY](https://www.putty.org/) - Cliente SSH Windows

### Recursos Adicionales

- [SIP RFC 3261](https://tools.ietf.org/html/rfc3261)
- [RTP RFC 3550](https://tools.ietf.org/html/rfc3550)
- [SRTP RFC 3711](https://tools.ietf.org/html/rfc3711)

---

## 📊 Estadísticas del Repositorio

![GitHub repo size](https://img.shields.io/github/repo-size/nicsanchezr/NEW-CUY5132-DUOC)
![GitHub contributors](https://img.shields.io/github/contributors/nicsanchezr/NEW-CUY5132-DUOC)
![GitHub last commit](https://img.shields.io/github/last-commit/nicsanchezr/NEW-CUY5132-DUOC)

---

## 🎓 Competencias Desarrolladas

Al completar los laboratorios de este curso, los estudiantes habrán desarrollado competencias en:

**Técnicas:**
- Configuración de Session Border Controllers
- Implementación de PBX en la nube
- Gestión de NAT traversal
- Configuración de cifrado TLS/SRTP
- Análisis de tráfico VoIP
- Hardening de sistemas

**Conceptuales:**
- Arquitectura VoIP empresarial
- Protocolos SIP, RTP, SRTP
- Defensa en profundidad
- Troubleshooting sistemático

---

## 📅 Actualizaciones

**Última actualización:** Diciembre 2025  
**Versión:** 2.0

### Changelog

- **v2.0** (Dic 2025): Actualización completa para semestre 2024-2
  - Scripts mejorados con detección automática de IPs
  - Material complementario agregado
  - Documentación expandida
  - Lab 2.4 (sngrep + fail2ban) agregado

- **v1.0** (2025): Versión inicial

---

<div align="center">

**⭐ Si este repositorio te fue útil, dale una estrella! ⭐**

[![GitHub stars](https://img.shields.io/github/stars/nicsanchezr/NEW-CUY5132-DUOC?style=social)](https://github.com/nicsanchezr/NEW-CUY5132-DUOC)

---

Hecho con ❤️ para estudiantes de DUOC UC

</div>
