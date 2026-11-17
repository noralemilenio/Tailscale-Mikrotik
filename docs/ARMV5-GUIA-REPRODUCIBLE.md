# Compilación, instalación y validación de Tailscale ARMv5 en MikroTik hEX S

> Guía genérica, sin configuraciones, credenciales, direcciones ni inventario de instalaciones particulares.
> Prueba comunitaria reproducible: hardware hEX S E60iUGS/EN7562CT, RouterOS 7.25.1, Tailscale v1.104.7, Go 1.27.4. **No es una distribución oficial ni un instalador universal.**

## 1. Por qué compilar

El E60iUGS usa CPU **ARMv5**. La imagen oficial de Tailscale y el paquete Fluent Networks `latest` anuncian ARMv7 o superior; no sirven directamente para ARMv5. Al probar una compilación con Go 1.26.5, Tailscale v1.104.7 exigió Go >=1.27.4. Se utilizó Go **1.27.4**.

Compilación equivalente a la usada, en Linux x86_64 con Docker:

```bash
mkdir -p dist
docker run --rm -v "$PWD/dist:/out" golang:1.27.4 sh -ec '
  CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 \
  GOBIN=/out go install \
    tailscale.com/cmd/tailscaled@v1.104.7 \
    tailscale.com/cmd/tailscale@v1.104.7
'
file dist/tailscale dist/tailscaled
docker run --rm -v "$PWD/dist:/out:ro" golang:1.27.4 \
  go version -m /out/tailscaled
sha256sum dist/tailscale dist/tailscaled
```

La información Go del ejecutable debe mostrar `GOARCH=arm`, `GOARM=5`, `CGO_ENABLED=0`. El resultado son ejecutables estáticos ELF ARM32; `EABI5` por sí solo no demuestra ARMv5, verificar metadatos de Go.

Para empaquetar desde este repositorio, ejecutar `bash scripts/build.sh`. El script utiliza Docker clásico (`create/cp/commit/save`) porque el builder heredado tuvo problemas al copiar capas cross-platform. **No necesita ejecutar instrucciones ARM en el host x86**. Archivo de salida: `dist/tailscale-mikrotik-armv5-1.104.7.tar` con SHA256. La imagen utiliza BusyBox ARMv5, los dos binarios, certificados CA y [entrypoint.sh](../container/entrypoint.sh).

## 2. RouterOS

Antes de tocar el router: exportación y backup, acceso físico, almacenamiento externo EXT4, comprobar versión exacta de RouterOS e instalar el paquete opcional **`container` de esa misma versión y arquitectura**. RouterOS necesita permitir contenedores mediante:

```routeros
/system device-mode update container=yes
```

**Confirmación física obligatoria** dentro de la ventana indicada: pulsación breve del botón correspondiente o corte real de alimentación y reconexión. Un reboot por WinBox no confirma el cambio. Comprobar `/system device-mode print` y `/system package print`.

**Ejemplo de red** — sustituye por tus rangos reales antes de ejecutar:

- LAN de ejemplo: `192.168.88.0/24`.
- Puente LAN existente: `bridge-LAN`.
- Puente del contenedor aislado: `ts-bridge`.
- RouterOS veth gateway: `172.30.254.1/30`; contenedor: `172.30.254.2/30`.
- Disco externo de ejemplo: `disk1`. No ejecutar este ejemplo sobre sistemas con nombres diferentes.

```routeros
/interface veth add name=ts-veth address=172.30.254.2/30 gateway=172.30.254.1
/interface bridge add name=ts-bridge
/ip address add address=172.30.254.1/30 interface=ts-bridge
/interface bridge port add bridge=ts-bridge interface=ts-veth
/ip firewall nat add chain=srcnat src-address=172.30.254.2/32 out-interface=bridge-LAN action=masquerade comment="ts-container-egress"
/ip route add dst-address=100.64.0.0/10 gateway=172.30.254.2 comment="ts-tailnet-return"
```

Si los equipos de la LAN usan otra puerta de enlace distinta del MikroTik, se necesita SNAT limitado para las conexiones desde Tailscale hacia la LAN. Revisar la política firewall existente antes de activar reglas. Ejemplo **conservador**, no copiar sin adaptar:

```routeros
/ip firewall nat add chain=srcnat src-address=100.64.0.0/10 dst-address=192.168.88.0/24 out-interface=bridge-LAN action=src-nat to-addresses=192.168.88.1 comment="ts-to-lan-snat-review"
```

**Importante:** el último valor `to-addresses` debe ser la IP real del MikroTik en esa LAN. Para segmentación adicional, limitar el forwarding a las direcciones autorizadas y bloquear tráfico no deseado. La ruta `100.64.0.0/10` puede coincidir con otra infraestructura CGNAT: comprobar solapamientos antes de instalarla. Las IPs del túnel deben alcanzarse por el contenedor; el filtro input del propio router puede bloquear la gestión o ICMP sin que falle el acceso a otros equipos de la LAN.

## 3. Imagen, almacenamiento y arranque

Ejemplo: copiar TAR al USB por WinBox, SCP o herramienta de administración. El USB debe estar montado y permitir escribir; usar su *mount-point* real. El formato `ext4` se confirmó con `/disk print detail`. La instalación probada usó una imagen mínima ARMv5 y el **script de entrada sin iptables**; `tailscale up` establece `--netfilter-mode=off`, por lo que el firewall/NAT se gobierna en RouterOS.

```routeros
/container config set tmpdir=disk1/tmp
/container mounts add list=ts-state src=disk1/ts-state dst=/var/lib/tailscale
/container envs add list=ts key=TS_ROUTES value=192.168.88.0/24
/container envs add list=ts key=TS_TEST_USERSPACE value=1
/container add file=disk1/tailscale-mikrotik-armv5-1.104.7.tar interface=ts-veth root-dir=disk1/containers/ts envlist=ts mountlists=ts-state cmd=/bin/entrypoint.sh start-on-boot=no logging=yes
```

En modo `TS_TEST_USERSPACE=1`, el daemon arranca **sin autenticación ni anuncio de rutas**. Verificar logs, estabilidad y consumo. Luego detener contenedor, cambiar `TS_TEST_USERSPACE=0` y volver a arrancar. El TUN `tailscale0` y el daemon deben funcionar.

Autenticar mediante **URL de login generada por Tailscale** o una clave de registro efímera, nunca incrustada en GitHub ni la imagen. Verificar registro y aprobar `192.168.88.0/24` en la consola Tailscale. El estado de identidad debe persistir bajo `/var/lib/tailscale` en el USB.

Tras las pruebas reales, `/container set [find where name="<nombre>"] start-on-boot=yes` y efectuar un reinicio controlado. El contenedor debe volver a estado RUNNING, autenticado, con la misma IP Tailscale.

## 4. Resultados de una validación real

En un **hEX S ARMv5 E60iUGS**, con RouterOS **7.25.1**, se comprobó:

- `tailscaled` v1.104.7 compilado Go 1.27.4, `GOARM=5`: arranque correcto.
- Imagen importada desde USB EXT4; interfaz veth separada y estado persistente.
- Prueba sin login/userspace completada.
- Modo TUN real: Tailscale se autentica, nodo visible en tailnet, anuncia una subred /24, ruta aprobada.
- Prueba desde un servidor remoto con aceptación de rutas temporal: tráfico ICMP llega a un equipo LAN a través del subnet router (3/3 antes de reinicio; 2/3 después, sin fallos de ruta).
- Reinicio RouterOS: paquete container, USB, Tailscale y sus datos persisten; `start-on-boot=yes`.
- DNS interno y conectividad local del router permanecieron operativos.

**No se han probado todas las políticas firewall, caídas prolongadas, rendimiento sostenido, recuperación automática ante fallos del proceso ni actualización de la imagen**. No publicar imágenes como `stable` sin esas pruebas.

## 5. Migrar desde un NAS u otro subnet router

1. Autorizar y probar el nuevo router como dispositivo Tailscale independiente.
2. Aprobar su anuncio de subred.
3. Verificar acceso desde una red verdaderamente remota a un equipo LAN; un ping al nodo Tailscale por sí solo es insuficiente.
4. Configurar arranque y probar reinicio.
5. Deshabilitar la **ruta del router antiguo** en el panel de administración de Tailscale.
6. Si se desea eliminar el anuncio local, ejecutar **en el dispositivo antiguo** `tailscale set --advertise-routes=` usando el CLI o interfaz que soporte su paquete. En Synology puede requerir ruta de paquete y permisos administrativos; comprobar primero. Esto **no equivale a `tailscale down` ni a eliminar el dispositivo**.
7. Verificar que el dispositivo antiguo conserva su IP individual y está accesible; el nuevo mantiene la única ruta habilitada.

## 6. Seguridad y recuperación

No publicar en GitHub claves, tokens, exports de RouterOS, direcciones reales, tailnet, seriales, MAC, IPs públicas, capturas con usuarios ni logs sin sanear. Respaldar RouterOS, mantener la posibilidad de volver a aprobar la ruta antigua y revisar reglas firewall/NAT por separado. Los certificados y archivos de estado contienen identidad y nunca deben incluirse en releases.

Proyecto experimental independiente; Tailscale, Go, BusyBox y RouterOS conservan sus licencias y condiciones respectivas.
