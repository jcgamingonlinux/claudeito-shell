# Barra Quickshell para Hyprland

Misma barra que las versiones de niri y sway, adaptada al IPC de
[Hyprland](https://hyprland.org/): workspaces, ventana activa, monitor
enfocado y el visor de atajos de teclado hablan con `hyprctl` y el socket
de eventos de Hyprland en vez del IPC de niri/sway. El resto de los
módulos (launcher, power menu, notificaciones nativas vía
`NotificationServer`, systray, wallpaper picker, CPU/RAM/TEMP/VOL/red,
etc.) es idéntico, porque no depende del compositor sino de protocolos
estándar de Wayland (layer-shell) y D-Bus.

## 1. Requisitos

```bash
# Arch
sudo pacman -S quickshell hyprland socat wireplumber

# Debian/Ubuntu (quickshell normalmente hay que compilarlo o usar un repo aparte)
sudo apt install hyprland socat wireplumber
```

`socat` es necesario para suscribirse en vivo al socket de eventos de
Hyprland (`.socket2.sock`) — sin él, los módulos de workspaces/ventana
activa/monitor enfocado igual funcionan, pero solo se actualizan con el
sondeo de respaldo cada 2 segundos en vez de instantáneamente.

## 2. Instalar la barra

```bash
mkdir -p ~/.config/quickshell
cp -r quickshell-hyprland-bar/* ~/.config/quickshell/
```

Esto la deja como la config *por defecto* de quickshell (sin nombre de
subcarpeta) — así que se lanza con `quickshell` a secas, y todos los
comandos IPC del snippet de abajo (`quickshell ipc call ...`) funcionan
tal cual, sin `-c <nombre>`.

## 3. Configurar Hyprland

**Hyprland 0.55 (abril 2026) reemplazó la config clásica por Lua real**
(`hyprland.lua`, con `hl.bind(...)`, `hl.dsp...`). Si tu Hyprland es
0.55+, copia el contenido de `hyprland-config-snippet.lua` dentro de tu
`~/.config/hypr/hyprland.lua`. Si todavía estás en la config clásica
(`hyprland.conf`, hyprlang, versiones anteriores a 0.55), usá en cambio
`hyprland-config-snippet-legacy.conf` (mismo contenido, sintaxis vieja) y
cambiá `configPath` en `KeybindsPopup.qml` de vuelta a
`hyprland.conf` — ver más abajo.

Incluye:

- Autostart de quickshell al iniciar Hyprland.
- Los binds para abrir/cerrar el launcher, el menú de energía, el
  selector de fondo de pantalla, el visor de atajos, el Dock de
  Configuración, el listado de ventanas, Ajustes de la barra y
  auto-ocultar (ver tabla completa más abajo).
- Las teclas multimedia de volumen/micrófono (usan `wpctl`).

Hyprland no trae una barra propia que haya que deshabilitar.

### Atajos de teclado

| Acción                                     | Atajo             |
| ------------------------------------------- | ----------------- |
| Abrir/cerrar el launcher                    | `SUPER + ALT + D`  |
| Abrir/cerrar el menú de energía             | `SUPER + SHIFT + X` |
| Abrir/cerrar el selector de fondo de pantalla | `SUPER + ALT + W`  |
| Abrir/cerrar el visor de atajos             | `SUPER + ALT + K`  |
| Listado de ventanas abiertas                | `SUPER + ALT + TAB` |
| Abrir/cerrar Ajustes de la barra            | `SUPER + ALT + COMMA` |
| Activar/desactivar auto-ocultar la barra    | `SUPER + ALT + B`  |
| Abrir/cerrar el Dock de Configuración ("Config") | `SUPER + ALT + C` |

Todos estos vienen ya cargados en `hyprland-config-snippet.lua` /
`hyprland-config-snippet-legacy.conf` — si querés otra combinación,
cambiala ahí (y en el snippet del resto de tus compositores, si usás más
de uno, para mantenerlos iguales).

## 4. Diferencias respecto a niri/sway

- **Workspaces**: `hyprctl -j workspaces` + `hyprctl -j monitors`
  (Hyprland no marca "activo/enfocado" dentro de la lista de workspaces
  en sí, hay que cruzarlo con el monitor). Cambiar de workspace al hacer
  click usa `hyprctl dispatch workspace <id>` (esto no cambió con la
  config Lua — `dispatch <nombre-simple>` sigue andando para los
  dispatchers "de sistema" que no vienen de tu config).
- **Ventana activa**: `hyprctl -j activewindow`.
- **Monitor enfocado**: `hyprctl -j monitors`, buscando el que tiene
  `"focused": true`.
- **Actualización en vivo**: se conecta a
  `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock` vía
  `socat` y refresca ante cualquier evento; además hay un sondeo de
  respaldo cada 2s por si falta `socat` o el socket no está disponible.
- **Cerrar sesión**: intenta primero `hyprctl dispatch "hl.dsp.exit()"`
  (sintaxis Lua de 0.55+) y si falla cae a `hyprctl dispatch exit`
  (sintaxis clásica), así funciona en ambas versiones sin que tengas que
  tocar nada. Igual que antes, esto cierra Hyprland directamente
  (Hyprland no separa "sesión" de "compositor" como sí lo hacen otros
  entornos). Si usás **uwsm** para lanzar la sesión, la wiki de Hyprland
  recomienda `uwsm stop` en vez del dispatcher `exit` para un apagado
  ordenado — si es tu caso, cambiá el comando en `PowerMenuPopup.qml` y
  `LauncherPopup.qml`.
- **Visor de atajos**: parsea `~/.config/hypr/hyprland.lua`. A diferencia
  de niri/sway (config de texto plano), esto es Lua real — el parser NO
  ejecuta el archivo, solo reconoce los patrones de `hl.bind(...)` más
  comunes (ver sección 5). También sigue, de forma best-effort, los
  `require("archivo")` de nivel superior que encuentre.

## 5. Visor de atajos: dos modos de listado

**Modo curado (acá, más recomendado todavía que en niri/sway):** anota
los binds que quieras que aparezcan con comentarios `-- @category ...` y
`-- @title ...` justo antes de cada `hl.bind(...)`:

```lua
local mainMod = "SUPER"

-- @category Aplicaciones

-- @title Abrir terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))

-- @title Abrir lanzador
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))

-- @category Ventanas

-- @title Cerrar ventana
hl.bind(mainMod .. " + C", hl.dsp.window.close())
```

Si el visor encuentra al menos un `-- @title` resoluble, muestra
**solo** esos binds, agrupados por el `@category` más reciente. Ya dejé
anotado `hyprland-config-snippet.lua` como ejemplo funcional.

**Modo automático (respaldo, más limitado que en niri/sway):** si no hay
ninguna anotación `@title`, el visor intenta listar los `hl.bind(...)`
que pueda interpretar solo — reconoce el primer argumento (la
combinación) cuando es un string literal o una concatenación simple con
`..` de un string y una variable `local NOMBRE = "valor"` (como
`mainMod`), y reconoce `hl.dsp.exec_cmd(...)` y otros `hl.dsp.*`
conocidos como segundo argumento. **No puede resolver binds generados
dinámicamente** (por ejemplo, los que arma un `for i = 1, 10 do ... end`
para los workspaces 1-9, como en la config de ejemplo oficial de
Hyprland) ni dispatchers pasados como función anónima
(`hl.bind("...", function() ... end)`) — esos se omiten en silencio, en
vez de mostrar algo incorrecto. Por eso acá conviene anotar con
`@title` los binds que realmente te importa ver en la lista, en vez de
depender del modo automático.

## 6. Notas

- **Bloqueo de pantalla**: el botón "Bloquear" usa `swaylock`, que
  funciona igual en Hyprland (es un bloqueador standalone compatible con
  cualquier compositor wlroots) — no hace falta cambiarlo a `hyprlock`,
  aunque también podés usar ese si lo preferís, cambiando el comando en
  `PowerMenuPopup.qml`.
- No probé esto en un Hyprland real, así que probablemente haya que
  ajustar algo al primer intento — contame qué sale cuando lo pruebes,
  sobre todo la parte de workspaces/monitor enfocado con más de una
  pantalla, si tu versión de `hyprctl` devuelve nombres de campo JSON
  distintos, y sobre todo el parser de `hyprland.lua`: es el módulo más
  frágil de todo el paquete porque intenta entender Lua sin un
  intérprete real — si tenés binds con una forma que no reconoce, avisame
  y lo ajustamos.

## Escalado proporcional a la resolución

Se agregó `Scaling.qml`, un singleton que calcula un factor de escala a
partir de la altura del monitor con foco (ver `FocusedScreen.qml`)
comparada contra una resolución de referencia de 1920x1080. A esa
resolución el factor es 1.0 (los tamaños quedan igual que antes); en un
monitor más chico todo se ve proporcionalmente más chico, y en uno más
grande, más grande — acotado entre 0.75x y 1.6x para que nunca quede
ilegible ni descomunal.

Se aplicó `Scaling.px(N)` a los tamaños fijos de casi todos los módulos:
alto de la barra (y su `exclusiveZone`, para que siga reservando el
espacio correcto), fuentes, íconos, radios, márgenes/spacing, y el ancho
y alto de cada popup. El factor se recalcula solo cuando cambia el
monitor con foco (reutiliza `FocusedScreen`), así que si movés el mouse o
una ventana a un monitor de otra resolución, la interfaz se reajusta
sola.

**Importante — esto es un eje distinto al escalado HiDPI de Wayland**:
si ya configuraste `scale` en tu compositor para un monitor de alta
densidad de píxeles, eso sigue aplicando igual y se combina con esto
(no lo reemplaza). `Scaling.qml` resuelve el otro problema: que la
barra se vea proporcionalmente parecida entre pantallas de distinta
**resolución lógica** (por ejemplo, tu laptop 1366x768 vs. un monitor
externo 1920x1080), no el de pantallas físicamente densas.

Si querés ajustar la resolución de referencia o los límites, están como
propiedades al principio de `modules/Scaling.qml`
(`referenceHeight`, `minFactor`, `maxFactor`).


## Módulo Ajustes movible + auto-ocultar barra + popups siguen la posición

Tres novedades de esta tanda:

**1. Los popups ya seguían la posición de la barra.** Al revisar el
código, `launcher`, `power menu`, `keybinds`, `calendario`, `red`, `CPU`,
`RAM`, `temperatura`, `volumen` y `notificaciones` ya usan
`BarConfig.barAtBottom` para anclarse arriba o abajo según corresponda.
Si en tu instancia seguían apareciendo arriba con la barra abajo, probá
con esta versión — puede que estuvieras corriendo una copia previa a ese
ajuste. Lo único que sigue fijo siempre arriba-derecha (a propósito, es
el comportamiento habitual de este tipo de notificaciones) son los
*toasts* de notificaciones nuevas; avisame si preferís que también sigan
la posición de la barra.

**2. El módulo "Ajustes" ahora es un módulo más.** Se agregó `config` a
`BarConfig.modules`, así que aparece en la lista del propio panel de
Ajustes y se puede reordenar u ocultar como cualquier otro (antes estaba
fijo al extremo izquierdo, fuera del sistema). Si ocultás **tanto**
"Ajustes" **como** "Config" (el Dock de accesos rápidos, que también
abre Ajustes — ver más abajo), el panel muestra una advertencia
recordando cómo volver a abrirlo: con el atajo `SUPER+ALT+COMMA` o
corriendo `quickshell ipc call bar-config toggle` desde una terminal —
ambos funcionan estén o no visibles esos módulos en la barra.

**3. Auto-ocultar barra (opción nueva en Ajustes).** Con el toggle
"Auto-ocultar" activado, la barra se repliega sola tras ~1.2s sin mouse
encima y sin popups abiertos, deslizándose fuera de pantalla hacia el
borde correspondiente (arriba o abajo). Reaparece acercando el mouse a
ese borde — queda reservada una franja mínima de 2px para poder
detectarlo incluso oculta. Es la primera versión de esta función: el
comportamiento de "franja detectora" depende un poco de cómo tu
compositor maneja el input de superficies layer-shell no exclusivas, así
que probala y contame si el hover no despierta la barra de forma
confiable — hay variantes de implementación (por ejemplo una ventana
"sensor" separada, más delgada) si esta no anda bien en tu setup.

## Íconos que no cargan (display, preferences-system-network, etc.) aunque el tema esté instalado

Si rofi/GTK sí muestran esos íconos pero la barra no, el tema está bien
instalado — el problema es que Quickshell (basado en Qt) no sabe qué tema
usar, porque en niri/sway/Hyprland sin `qt5ct`/`qt6ct` normalmente nadie le
informa a Qt cuál es el "platform icon theme" (rofi, al ser GTK, lo resuelve
por su cuenta y por eso a él sí le funciona).

Arreglo: usá `launch-with-icon-theme.sh` (en esta misma carpeta) en vez de
llamar a `quickshell -c hyprland-bar` directamente en tu autostart. El script
detecta el tema de íconos GTK activo (leyendo `gtk-3.0/settings.ini` o
`gsettings`) y lo exporta como `QS_ICON_THEME` antes de arrancar quickshell
— así usa el mismo tema que ya ves en tus apps GTK.

También queda un pragma alternativo (inerte) al principio de `shell.qml`
por si preferís fijar el nombre del tema a mano en vez de autodetectarlo:
```
// pragma IconTheme NOMBRE-DE-TU-TEMA
```
Agregale el `@` que le falta (`//@ pragma IconTheme ...`) con el nombre
exacto de la carpeta en `/usr/share/icons`, y reiniciá quickshell.

## Auto-ocultar: quedaba una franja opaca y el espacio no se liberaba

Dos bugs relacionados con auto-ocultar, ya corregidos:

- **Franja oscura tapando ventanas.** El contenido de la barra (íconos,
  texto) se deslizaba fuera de vista, pero la ventana contenedora seguía
  pintando su fondo oscuro a tamaño completo -- quedaba una franja opaca
  en el borde tapando la parte superior de lo que hubiera debajo. Ahora
  el fondo se vuelve transparente cuando la barra está oculta.
- **El espacio no se liberaba para nuevas ventanas.** Al ocultarse
  todavía se reservaban 2px (`exclusiveZone`) para el detector de hover.
  Ahora baja a 0 -- el hover se sigue detectando igual porque no depende
  de eso -- así que una ventana nueva (ej. una terminal) sí puede usar
  todo el alto de pantalla. Si tu compositor no reacomoda ventanas ya
  abiertas al cambiar el `exclusiveZone` en caliente (algunos wlroots no
  lo hacen para ventanas ya en tiling), esa es una limitación del propio
  compositor, no de la barra -- para las ventanas nuevas sí debería andar.

## Hyprland: la barra queda por encima de ventanas en pantalla completa

Es un comportamiento conocido/inconsistente de Hyprland con layer-surfaces
en capa "Top" (ver hyprwm/Hyprland discussions #8757 e issue #3970): según
versión y configuración, a veces no oculta el Top layer al entrar a
fullscreen real. Se agregó un respaldo explícito:

- Nuevo comando IPC `bar-visibility` (`hide` / `show` / `toggle`), que
  fuerza a ocultarse/mostrarse en todas las pantallas sin tocar la
  preferencia de auto-ocultado.
- `hide-on-fullscreen.sh` (en esta carpeta): escucha los eventos de
  fullscreen de Hyprland y llama a ese IPC automáticamente. Necesita
  `socat` instalado. Agregalo a tu `hyprland.conf`, ADEMÁS de la línea que
  ya lanza quickshell:
  ```
  exec-once = sh ~/.config/quickshell/hyprland-bar/hide-on-fullscreen.sh
  ```
  Reiniciá Hyprland (o corré esa línea a mano) para probarlo.

## Wallpaper picker: panel de tags/filtros de Wallhaven

La pestaña Wallhaven del selector de fondo de pantalla ahora tiene un
panel lateral derecho con tags relacionados a la búsqueda actual. Se
pueden seleccionar varios a la vez (se combinan con `+tag` en la
búsqueda, la sintaxis real de la API de wallhaven para "debe tener este
tag"), sacarlos individualmente desde "Filtros activos", o limpiarlos
todos de un click sin perder el texto buscado ni las categorías.

Los tags se derivan de los resultados de la página actual (wallhaven no
tiene un endpoint de "tags populares" ni los incluye en `/search` — solo
en el detalle de cada wallpaper), pidiendo el detalle de una muestra
chica (8 por defecto, `tagSampleSize` en `WallpaperPicker.qml`) para no
gastar de más la cuota de 45 peticiones/minuto de la API. Es asíncrono y
no bloquea la grilla — si falla, el panel simplemente queda vacío.

El ancho del popup subió de 720 a 900px para que el panel de tags no le
quite columnas a la grilla de miniaturas.

También se corrigió que el selector se cerrara al hacer click afuera,
como si fuera un launcher — ahora, igual que Ajustes, solo se cierra con
`Escape` o su botón X.

## Barra: el grupo del centro ahora se centra en toda la pantalla

Antes, un módulo puesto en la zona "center" de la barra se estiraba para
ocupar todo el hueco entre `leftGroup` y `rightGroup`, y su contenido se
alineaba desde el borde izquierdo de ESE hueco — con un solo módulo,
quedaba pegado al final del grupo izquierdo en vez de centrado en la
pantalla. Ahora `centerGroup` se centra en el ancho total de la barra
(`root.width`), con los bordes de los otros dos grupos como límites para
no superponerse si el contenido crece (por ejemplo un título de ventana
largo en `activeWindow`).

## Nuevo módulo "Config": Dock de accesos rápidos

Módulo de barra nuevo (`configDock`, zona `center` por defecto, convive
con `activeWindow`) que al hacer click —o con su atajo `SUPER+ALT+C`—
despliega un Dock horizontal con 3 accesos: **Keybinds**, **Ajustes** y
**Wallpaper**, cada uno abriendo el popup que ya existía (no duplica
nada). Se navega con `←`/`→` y se acepta con `Enter` (`Esc` cierra).

Se ancla debajo del módulo Config igual que las cajas de info de
CPU/RAM/etc. (`BarPositions.configDockX/Width`) — si movés "Config" de
zona, o la barra de arriba a abajo, el Dock lo sigue automáticamente.

Archivos nuevos: `ConfigDockButton.qml`, `ConfigDockPopup.qml`.

## Suspender/Reiniciar/Apagar: ya no asumen systemd

Los 2 power menus y los botones de abajo del launcher ahora prueban, en
un solo comando de shell encadenado con `||`: `systemctl` → `loginctl`
(sistemas sin systemd pero con `elogind`, como Alpine) → el comando
directo (`reboot`/`poweroff`/`pm-suspend`, último recurso para SysV puro
sin elogind). Centralizado en el singleton nuevo `PowerCommands.qml`.

**Nota sobre el último recurso ("raw"):** a diferencia de
systemctl/loginctl (que pasan por polkit), `reboot`/`poweroff` directos
normalmente necesitan privilegios — si tu sistema no tiene sudo/doas sin
contraseña configurado para esos comandos (o setuid), van a fallar. Y no
hay un comando de suspender universal sin systemd/elogind: se usa
`pm-suspend` (paquete `pm-utils`) como el más parecido a un estándar en
sistemas SysV/OpenRC tradicionales, pero no está garantizado en todos
lados.

(Una primera versión de esto detectaba una sola vez al arrancar y
guardaba el resultado, pero tenía una condición de carrera real: un
click justo después de abrir la barra podía capturar el valor por
defecto `systemctl` antes de que la detección terminara. En sistemas con
systemd nunca se notaba porque el valor por defecto coincidía con la
realidad, pero en Alpine el primer click fallaba en silencio. El diseño
actual, con `||` en un solo comando, no depende de ningún estado
guardado.)

"Cerrar sesión" y "Bloquear" no cambiaron: cerrar sesión ya es
específico de cada compositor (no tiene que ver con systemd) y bloquear
usa `swaylock`.

## Ícono de Bluetooth en su azul característico

El glyph de Bluetooth en la barra ahora usa `#0082FC` (el azul de marca
más citado para Bluetooth — no hay un hex oficial publicado, esto sale
de las guías de marca no oficiales a partir del Pantone 2925 C) cuando
el adaptador está habilitado, y gris cuando está apagado. El nombre del
dispositivo conectado (cuando hay uno) sigue con el azul de acento de la
paleta, sin cambios.

## Atajos de teclado: se agregó ALT a la mayoría

Para dejar más margen contra choques con atajos de tus apps o del propio
compositor, casi todos los atajos de Quickshell pasaron a llevar
`ALT` además de `SUPER` (el menú de energía es la excepción: pasó a
`SUPER+SHIFT+X`). Ver la tabla completa en la sección 3, más arriba.
Si venías de una instalación anterior, actualizá tu
`hyprland.lua`/`hyprland.conf` con el snippet nuevo — los atajos viejos
(`SUPER+D`, `SUPER+W`, etc.) ya no están en el snippet.

