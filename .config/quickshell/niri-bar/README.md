# Barra Quickshell para niri

Misma barra que la versión de sway, adaptada al IPC de [niri](https://github.com/YaLTeR/niri):

- Espacios de trabajo (vía `niri msg -j workspaces` / `event-stream`)
- Botón **Menu** → launcher de apps propio, hecho en QML (sin depender de wofi/rofi)
- Reloj con calendario desplegable
- System tray
- Botón de energía (bloquear / cerrar sesión / suspender / reiniciar / apagar)
- Red / WiFi (vía `nmcli`)
- Batería (auto-oculta en equipos de escritorio, vía UPower)
- Volumen (vía Pipewire), rueda del mouse para subir/bajar, click derecho para mute
- Teclas multimedia de volumen configuradas en niri (usan `wpctl`)
- Uso de CPU y RAM (leídos de `/proc`)

## Qué cambia respecto a la versión de sway

niri no habla el protocolo IPC de i3/sway, así que lo único que cambió de
fondo es `modules/Workspaces.qml`:

- Lista de workspaces: `niri msg -j workspaces` (en vez de `swaymsg -t get_workspaces`).
  Cada workspace trae `id`, `idx`, `name` (opcional), `is_active` (activo en
  su output) e `is_focused` (el que tiene foco global).
- Actualización en vivo: nos suscribimos a `niri msg -j event-stream` y
  refrescamos ante cualquier línea que llegue (niri no permite filtrar el
  stream solo por eventos de workspace como sway, así que se simplifica así).
- Cambiar de workspace al hacer click: `niri msg action focus-workspace-by-id <id>`.
- El botón "Cerrar sesión" del power menu ahora ejecuta
  `niri msg action quit --skip-confirmation` en vez de `swaymsg exit`.

Todo lo demás (launcher, reloj/calendario, systray, red, batería, volumen,
CPU/RAM) es idéntico, porque no depende de sway ni de niri sino de
`Process`, `nmcli`, `/proc`, Pipewire y UPower — y el layer-shell
(`Quickshell.Wayland`) funciona igual en ambos compositores porque los dos
implementan el protocolo `wlr-layer-shell`.

## 1. Dependencias (Arch Linux)

```bash
yay -S quickshell-git niri
yay -S ttf-jetbrains-mono-nerd     # fuente con íconos, opcional

sudo pacman -S wofi                # o rofi / fuzzel, cambiando MenuButton.qml
sudo pacman -S networkmanager upower pipewire pipewire-pulse wireplumber
```

## 2. Instalación de la config

```bash
mkdir -p ~/.config/quickshell
cp -r quickshell-niri-bar ~/.config/quickshell/niri-bar
```

Se lanza con:

```bash
quickshell -c niri-bar
```

## 3. Configurar niri

niri usa KDL (`~/.config/niri/config.kdl`), no el mismo formato que sway.
Copia el contenido de `niri-config-snippet.kdl` dentro de tu config: agrega
el `spawn-at-startup` para lanzar quickshell al iniciar sesión, y los binds
de teclas multimedia dentro del bloque `binds { ... }` (si ya tienes un
bloque `binds`, fusiona las líneas ahí en vez de duplicar el bloque).

niri no tiene una barra propia que haya que deshabilitar, así que no hace
falta tocar nada más.

### Atajos de teclado

| Acción                                     | Atajo             |
| ------------------------------------------- | ----------------- |
| Abrir/cerrar el launcher                    | `Mod+Alt+D`  |
| Abrir/cerrar el menú de energía             | `Mod+Shift+X` |
| Abrir/cerrar el selector de fondo de pantalla | `Mod+Alt+W`  |
| Abrir/cerrar el visor de atajos             | `Mod+Alt+K`  |
| Listado de ventanas abiertas                | `Mod+Alt+Tab` |
| Abrir/cerrar Ajustes de la barra            | `Mod+Alt+Comma` |
| Activar/desactivar auto-ocultar la barra    | `Mod+Alt+B`  |
| Abrir/cerrar el Dock de Configuración ("Config") | `Mod+Alt+C` |

Todos estos vienen ya cargados en `niri-config-snippet.kdl` — si querés
otra combinación, cambiala ahí (y en el snippet del resto de tus
compositores, si usás más de uno, para mantenerlos iguales).

## 4. Notas importantes

- Igual que en la versión de sway: los módulos que usan "servicios" de
  Quickshell (`SystemTray`, `UPower`, `Pipewire`) son los más sensibles a
  cambios de versión de quickshell — revisa quickshell.outfoxxed.me si algo
  no compila.
- `niri msg action focus-workspace-by-id` requiere una versión de niri
  razonablemente reciente; si tu versión es más vieja y ese action no
  existe, usa `niri msg action focus-workspace <idx+1>` en su lugar
  (niri numera visualmente desde 1).

## 5. Sobre el launcher (`modules/LauncherPopup.qml`)

Es 100% QML/Quickshell, igual que en la versión de sway: escanea los
`.desktop` de `~/.local/share/applications`, `/usr/local/share/applications`
y `/usr/share/applications` con un script `sh` vía `Process`, filtra
`NoDisplay`/`Hidden`, permite buscar por nombre y lanza con `Exec=`
limpiado de códigos de campo (`%f %F %u %U %i %c %k`). No depende de
wofi/rofi/fuzzel ni de niri en particular.

## 6. Personalización rápida

Igual que en la versión de sway: colores en cada módulo (paleta Catppuccin
Mocha), formato de hora en `modules/Clock.qml`.

## Cambios recientes

- **Orden de módulos**: izquierda → Menu, espacios de trabajo, ventana
  activa. Derecha → CPU, RAM, volumen, red, systray, batería, hora, Power.
  Se define en `modules/Bar.qml`.
- **Ventana activa** (`modules/ActiveWindow.qml`, nuevo): muestra el título
  de la ventana con foco, con elipsis si es muy largo.
- **Reloj**: ahora solo muestra `hh:mm` (sin segundos ni fecha), ya que la
  fecha está en el calendario desplegable.
- **Botón de energía**: ahora muestra el ícono junto a la palabra "Power".
- **Numeración de workspaces**: se corrigió un desfase de +1 — niri ya
  numera sus workspaces desde 1 en el campo `idx`, así que ahora se muestra
  `idx` directamente en vez de `idx + 1`.
- **CPU/RAM**: se separaron en `modules/Cpu.qml` y `modules/Ram.qml` (antes
  era un solo `CpuRam.qml`) para poder ordenarlos de forma independiente.

## Notificaciones nativas (sin mako/dunst)

Se agregó `modules/Notifications.qml`: un singleton que instancia un
`Quickshell.Services.Notifications.NotificationServer` y por lo tanto
**registra a Quickshell como el demonio de notificaciones de D-Bus**
(`org.freedesktop.Notifications`).

- **IMPORTANTE**: solo una app puede tener ese rol a la vez. Si tienes
  `mako`, `dunst`, `swaync`, etc. corriendo (o en el autostart de sway/niri),
  quítalos — si no, habrá conflicto por quién recibe las notificaciones
  (típicamente gana quien arrancó primero, y el otro simplemente no
  recibe nada, sin error visible).
- Los toasts aparecen arriba a la derecha (`modules/NotificationToasts.qml`),
  se autocierran según el timeout de la notificación (o 5s por defecto),
  y se pueden descartar con un click. Si tienen botones de acción, se
  muestran como chips debajo del cuerpo.
- El botón 🔔 en la barra (junto al tray, `modules/NotificationCenterButton.qml`)
  muestra el conteo del historial y abre un desplegable
  (`modules/NotificationCenterPopup.qml`) con las últimas 50 notificaciones
  y un botón "Limpiar".
- **Aviso de estabilidad de API**: de todo lo construido hasta ahora, esta
  es la pieza más nueva y sensible a la versión instalada de Quickshell.
  Los nombres usados (`NotificationServer`, `onNotification`, `appName`,
  `summary`, `body`, `urgency`, `expireTimeout`, `actions[].identifier/.text`,
  `tracked`, `closed`, `dismiss`) son los más comunes entre shells reales de
  Quickshell, pero si algo no compila, el propio error de quickshell suele
  señalar exactamente qué propiedad/señal falta — compara contra la
  documentación de `Quickshell.Services.Notifications` en tu versión
  instalada (quickshell.outfoxxed.me).

## Correcciones adicionales

- **Click en workspaces**: en la versión niri, el click no cambiaba de
  espacio de trabajo porque usaba una acción inexistente
  (`focus-workspace-by-id`). Se corrigió a la acción real `focus-workspace`,
  referenciando el workspace por nombre (si lo tiene) o por índice. Además
  ahora se captura `stderr` del proceso de cambio de workspace y se loguea
  en la consola donde corre quickshell — si en tu versión de niri/sway el
  nombre de la acción vuelve a no coincidir, ahí debería aparecer el error.
- **Volumen**: el indicador ahora es un texto simple `VOL 45%` / `VOL mute`
  en vez de íconos, en `modules/VolumeIndicator.qml`.

## Corrección: el launcher se "bloqueaba" con apps abiertas

`modules/LauncherPopup.qml` reutilizaba un único `Process` para lanzar
cualquier app (`sh -c app.exec`). Ese wrapper de shell se queda en primer
plano mientras la app sigue corriendo (no se desliga solo), así que el
`Process` quedaba "ocupado" — la siguiente app no se abría hasta que
cerrabas alguna ventana existente y ese `Process` quedaba libre.

Ahora cada lanzamiento crea su propio `Process` desechable, con
`setsid ... & disown` para desligarlo por completo de quickshell. El
wrapper de shell termina casi de inmediato (independientemente de cuánto
tiempo quede abierta la app), así que nunca bloquea el siguiente
lanzamiento.

## Íconos, apps de Flatpak, atajo de teclado y launcher centrado

- **Íconos**: `modules/LauncherPopup.qml` ahora resuelve el ícono de cada
  app con `Quickshell.iconPath(nombre)` (de `Quickshell.Widgets`/`Quickshell`
  base). Si no se resuelve (tema de íconos, nombre raro, etc.), se ve un
  cuadro con la inicial del nombre como respaldo — nunca queda un hueco en
  blanco. **Aviso de versión**: `Quickshell.iconPath` es, junto con las
  notificaciones, de lo más nuevo/sensible a la versión instalada — si no
  compila, el error debería señalar el nombre correcto en tu versión.
- **Apps de Flatpak**: se agregaron `~/.local/share/flatpak/exports/share/applications`
  y `/var/lib/flatpak/exports/share/applications` a los directorios
  escaneados (además de `/usr/share/applications/*/*.desktop`, donde
  algunas distros/flatpak-remotes anidan subcarpetas). También se limpian
  los tokens `@@u %u @@` que usan algunos `.desktop` de Flatpak. Si sigues
  sin ver alguna app de Flatpak, corre `flatpak list --app` y
  `find ~/.local/share/flatpak /var/lib/flatpak -name '*.desktop'` para
  confirmar dónde quedó instalado el `.desktop` real.
- **Atajo de teclado**: se agregó un `IpcHandler` en `shell.qml` (target
  `"launcher"`, función `toggle()`). `Mod+Alt+D` en `niri-config-snippet.kdl`
  ahora llama a `quickshell -c niri-bar ipc call launcher toggle` para
  abrir/cerrar el launcher sin usar el mouse. **Aviso de versión**: el
  orden exacto de flags de `quickshell ipc call` ha cambiado entre
  versiones — si el bind no hace nada, corre `quickshell ipc call --help`
  (o `quickshell --help`) para confirmar la sintaxis de tu versión
  instalada, y ajusta el snippet/bind.
- **Launcher centrado**: se le quitaron las anclas (`top`/`left`) a su
  `PanelWindow` en `shell.qml` — sin anclas, wlr-layer-shell centra la
  superficie en la pantalla por defecto. También se agrandó a 520×600.

## Dos launchers independientes + navegación + cierre al hacer click afuera

- **Dos instancias separadas**: `Bridge.menuLauncherOpen` (botón Menu →
  arriba a la izquierda, como estaba al principio) y
  `Bridge.shortcutLauncherOpen` (atajo de teclado → centrado). Ambas usan
  el mismo componente `modules/LauncherPopup.qml`, que ahora es reutilizable:
  recibe `open` (bool) y emite `closeRequested()` en vez de leer/escribir
  `Bridge` directamente — así cada instancia en `shell.qml` controla su
  propio flag.
- **Navegación por teclado**: flechas ↑/↓ mueven la selección (resaltada en
  la lista), Enter lanza la app seleccionada, Esc cierra. El buscador
  recibe el foco automáticamente al abrir cualquiera de los dos launchers.
- **Cerrar con click afuera**: cada launcher ahora vive dentro de una
  ventana a pantalla completa (transparente) con un `MouseArea` de fondo
  que lo cierra; el propio `LauncherPopup` tiene su propio `MouseArea` que
  absorbe los clicks internos para que no se propaguen hacia ese fondo
  (si no, cualquier click en un espacio vacío del launcher lo cerraría
  por accidente).

## Si el atajo de teclado no hace nada

`quickshell ipc call` es de las partes de la CLI de Quickshell que más ha
cambiado entre versiones. Para diagnosticarlo:

1. Abre una terminal (no uses el bind todavía) y con quickshell corriendo,
   ejecuta exactamente:
   ```bash
   quickshell -c niri-bar ipc call launcher toggle
   ```
   (cambia `niri-bar` por `sway-bar` si usas esa versión). Si el launcher
   centrado se abre/cierra, el problema está en el bind del compositor, no
   en Quickshell — revisa que el `Mod+Alt+D` no choque con otro atajo ya usado
   por niri/sway.
2. Si el comando de arriba da error, prueba:
   ```bash
   quickshell ipc call launcher toggle
   ```
   (sin `-c`, por si tu versión detecta sola la instancia corriendo), o
   revisa `quickshell ipc call --help` y `quickshell --help` para ver el
   orden de argumentos exacto que espera tu versión instalada, y ajusta el
   bind en `niri-config-snippet.kdl` / `sway-config-snippet.conf` según
   corresponda.
3. Confirma también que el `IpcHandler { target: "launcher" }` en
   `shell.qml` se haya cargado sin error (revisa la salida de quickshell
   en la terminal al arrancar).

## "Sin conexión" con cable físico conectado

Esto pasa cuando tu red la maneja algo distinto a NetworkManager (p. ej.
`systemd-networkd`, `dhcpcd` directo, etc.) — en ese caso `nmcli dev status`
no reporta nada como "connected" aunque sí tengas conexión real.

`modules/NetworkIndicator.qml` ahora intenta `nmcli` primero y, si no
encuentra nada conectado, cae a revisar directamente
`/sys/class/net/*/operstate`: toma la primera interfaz (que no sea `lo`)
en estado `up` y la muestra como LAN o WiFi según tenga o no la carpeta
`wireless`. Si tu interfaz de red tiene otro nombre "raro" (contenedores,
VPNs, etc. también aparecen ahí), y no te agarra la correcta, dime el
nombre de tu interfaz (`ip link` te lo muestra) y le agregamos un filtro
más preciso.

## Aclaración: "-c niri-bar"/"-c sway-bar" solo si usas subcarpeta con nombre

Si copiaste el contenido de esta carpeta directo a `~/.config/quickshell/`
(o sea, `~/.config/quickshell/shell.qml` existe), quickshell corre como la
config *por defecto* — sin nombre — y **no** debes usar `-c niri-bar` /
`-c sway-bar` en ningún comando (ni en `spawn-at-startup`, ni en el bind
del atajo, ni al invocar `quickshell ipc call` a mano). Los snippets de
config ya se actualizaron para reflejar esto.

Si en cambio prefieres tener varias configs de quickshell en paralelo,
mueve los archivos a una subcarpeta con nombre
(`~/.config/quickshell/niri-bar/shell.qml`) y ahí sí agrega `-c niri-bar`
a todos los comandos.

## Menú de energía: mismo patrón que el launcher

`modules/PowerMenuPopup.qml` se rehízo siguiendo exactamente el mismo
patrón que el launcher:

- **Componente reutilizable**: recibe `open` (bool) y emite
  `closeRequested()`, en vez de leer/escribir `Bridge` directamente.
- **Dos instancias independientes** en `shell.qml`: `Bridge.menuPowerOpen`
  (botón "Power" de la barra → arriba a la derecha, como estaba) y
  `Bridge.shortcutPowerOpen` (atajo de teclado → centrado en pantalla,
  igual que el launcher centrado).
- **Navegación por teclado**: ↑/↓ mueven la selección resaltada, Enter
  ejecuta la opción seleccionada, Esc cierra. Como este menú no tiene
  cuadro de texto, el foco de teclado lo toma el propio `Rectangle` raíz
  (`focus: true` + `forceActiveFocus()` al abrir).
- **Cerrar con click afuera**: mismo mecanismo que el launcher — cada
  instancia vive en una ventana a pantalla completa con un `MouseArea` de
  fondo que cierra, y el propio `PowerMenuPopup` absorbe sus clicks
  internos para no cerrarse solo.
- **Íconos de JetBrainsMono Nerd Font**: Bloquear (`\uf023`), Cerrar sesión
  (`\uf08b`), Suspender (`\uf186`), Reiniciar (`\uf021`), Apagar (`\uf011`)
  — son códigos compatibles con Font Awesome, de los más estables entre
  versiones de Nerd Fonts. Si algún glifo no aparece (cuadro vacío), corre
  `fc-list | grep -i jetbrains` para confirmar que el nombre exacto de la
  familia coincide con `font.family: "JetBrainsMono Nerd Font"` — algunas
  variantes se instalan como "JetBrainsMono Nerd Font Mono" o similar, y
  habría que ajustar el nombre en el archivo.
- El botón "Power" de la barra (`modules/PowerMenu.qml`) también cambió su
  ícono al mismo glifo de apagado (`\uf011`) de Nerd Font, por consistencia.

Se agregó el atajo `Mod+Shift+X` (niri) / `$mod+shift+x` (sway) para el
menú de energía centrado, llamando a
`quickshell ipc call powermenu toggle`. Si el atajo del launcher (`Mod+Alt+D`)
ya te funciona sin `-c`, este debería funcionar igual; si no, aplica el
mismo diagnóstico que hicimos para el launcher.

## Cómo probar las notificaciones

La ventana de notificaciones solo muestra algo cuando llega una
notificación real por D-Bus — no hay nada que probar hasta que se dispare
una. Para probarla a mano:

```bash
sudo pacman -S libnotify   # si no lo tienes, trae el comando notify-send
notify-send "Título de prueba" "Este es el cuerpo de la notificación"
```

Si todo está bien conectado, debería aparecer un toast arriba a la
derecha por ~5 segundos, y quedar guardada en el historial (el botón 🔔
junto al tray).

Si **no aparece nada**, revisa en este orden:

1. **¿Hay otro demonio de notificaciones corriendo?** Ya vimos este
   warning antes:
   ```
   WARN quickshell.service.notifications: Could not register notification server...
   ```
   Si sigue ahí (revisa la salida de quickshell en la terminal), algo más
   —mako, dunst, swaync, o incluso `xfce4-notifyd`/`gnome-shell` si tienes
   sesión mixta— ya tomó el rol de demonio de notificaciones y Quickshell
   nunca pudo registrarse. Corre `busctl --user list | grep -i notif` o
   `ps aux | grep -iE "mako|dunst|swaync"` para ver quién lo tiene, y
   ciérralo (o quítalo del autostart).
2. **`notify-send` da error de conexión a D-Bus**: confirma que tu sesión
   tenga un bus de sesión activo (`echo $DBUS_SESSION_BUS_ADDRESS` no
   debería estar vacío).
3. Si `notify-send` no da error y el toast sigue sin aparecer, puede ser
   un problema de la propia integración de `NotificationServer` en tu
   versión de Quickshell (recuerda el aviso del README sobre esto): revisa
   la salida de quickshell en la terminal justo al correr `notify-send`,
   cualquier warning ahí normalmente apunta al problema exacto.

## Notificaciones: cierre al hacer click afuera

`modules/NotificationCenterPopup.qml` (el desplegable del historial, botón
🔔) ahora sigue el mismo patrón que el launcher y el power menu: su
ventana en `shell.qml` pasó a ser a pantalla completa con un `MouseArea`
de fondo que cierra `Bridge.notificationsOpen` al hacer click afuera, y el
propio popup absorbe sus clicks internos para no cerrarse solo.

## Apps más usadas arriba del launcher

Se agregó `modules/AppUsage.qml`: un singleton que cuenta cuántas veces se
lanzó cada app y lo persiste en
`~/.local/share/quickshell-launcher-usage.tsv` (formato simple
`cantidad<TAB>nombre`, una línea por app). Como es un singleton, lo
comparten los dos launchers (botón y atajo) y sobrevive a reinicios de
quickshell/la sesión.

- **Sin buscar nada**: el launcher muestra primero hasta 6 apps más usadas
  (ordenadas por cantidad de lanzamientos, de mayor a menor), luego una
  línea separadora, y después el resto en orden alfabético (sin repetir
  las de arriba). Si todavía no has lanzado ninguna app desde el launcher,
  no hay sección de "más usadas" ni separador — se ve la lista alfabética
  completa, como antes.
- **Buscando algo**: se mantiene el comportamiento anterior — lista
  filtrada y ordenada alfabéticamente, sin la sección de más usadas (no
  tendría sentido mezclarlas con una búsqueda de texto).
- La navegación con flechas ahora salta automáticamente la línea
  separadora (no es seleccionable ni lanzable).
- El conteo se guarda codificado en base64 al escribir el archivo, para
  evitar cualquier problema de comillas o caracteres especiales al pasarlo
  por el shell — es solo un detalle interno, no necesitas tocar nada.

Si en algún momento quieres resetear el conteo, simplemente borra el
archivo:
```bash
rm ~/.local/share/quickshell-launcher-usage.tsv
```

## Fondo de pantalla, manejado por Quickshell (sin swaybg)

Se agregaron dos piezas nuevas:

- **`modules/Wallpaper.qml`** (singleton): guarda la ruta del fondo actual
  y la persiste en `~/.config/quickshell/wallpaper-path.txt` (se lee al
  arrancar quickshell, así que el fondo elegido sobrevive a reinicios).
- **`modules/WallpaperPicker.qml`**: selector con miniaturas en grilla,
  buscando imágenes (`.jpg .jpeg .png .webp .bmp`) en
  `~/Pictures/Wallpapers`, `~/.local/share/backgrounds` y `~/Pictures`
  (hasta 2 niveles de profundidad). Click en una miniatura la aplica al
  instante; la que está activa se ve resaltada con un borde.
- En `shell.qml` se agregó una `PanelWindow` por cada monitor en la capa
  `Background` del layer-shell (la más al fondo posible, por debajo de
  todas las ventanas normales) mostrando `Wallpaper.current` — esto
  reemplaza por completo la necesidad de `swaybg` o similar.

**Decisión que tomé por ti**: como no especificaste desde dónde abrir el
selector, lo dejé solo con atajo de teclado (`Mod+Alt+W` en niri,
`$mod+w` en sway), centrado — igual que el launcher y el power menu
centrados. Si prefieres además un botón en la barra (por ejemplo junto al
tray), dímelo y lo agrego en dos líneas, ya que el componente ya soporta
múltiples instancias con el mismo patrón `open`/`closeRequested`.

Si `~/Pictures/Wallpapers` no existe todavía, créalo y copia ahí tus
imágenes:
```bash
mkdir -p ~/Pictures/Wallpapers
cp /ruta/a/tus/fotos/*.jpg ~/Pictures/Wallpapers/
```

## Más carpetas de fondos de pantalla

`modules/WallpaperPicker.qml` ahora también busca en:

- `~/Pictures/Wallpapers`
- `~/Imágenes/wallpapers`
- `~/wallpapers`
- `~/Wallpapers`
- `~/.local/share/backgrounds`
- `~/Pictures`

(en ese orden; se buscan todas, no es "la primera que exista"). Recuerda
que en Linux los nombres de carpeta distinguen mayúsculas de minúsculas,
así que `~/wallpapers` y `~/Wallpapers` son dos carpetas distintas — si
usas una sola, con que exista esa alcanza.

## Multi-monitor: los popups ahora siguen al monitor con foco

Antes, el launcher, el power menu, el calendario, las notificaciones y el
selector de fondo siempre usaban `Quickshell.screens[0]` — es decir,
siempre el primer monitor que detecta Quickshell (normalmente la pantalla
interna del portátil), sin importar en cuál estuvieras trabajando.

Se agregó `modules/FocusedScreen.qml` (singleton): mantiene el nombre del
monitor (output) que tiene el foco ahora mismo —niri: se saca del
workspace enfocado (`niri msg -j workspaces`, campo `output`); sway: de
`swaymsg -t get_outputs`, el que tenga `"focused": true`— actualizado en
vivo con eventos, igual que ya hacíamos con los workspaces.

Cada ventana overlay (launcher ×2, power menu ×2, calendario,
notificaciones ×2, selector de fondo) ahora se instancia una vez por cada
monitor conectado (`Variants { model: Quickshell.screens }`), pero solo se
hace `visible` la instancia cuyo `modelData.name` coincide con
`FocusedScreen.name` — así que aparece en el monitor donde tienes el foco,
no siempre en el mismo.

**Si después de probarlo en tus 2 pantallas algo sigue sin aparecer donde
esperas**, lo más probable es un desfase entre el nombre que reporta
niri/sway para cada output y el nombre que expone `Quickshell.screens[]`
internamente (debería coincidir, pero por las dudas): corre
`niri msg -j outputs` (o `swaymsg -t get_outputs`) y compara los nombres
(`eDP-1`, `HDMI-A-1`, etc.) — si ves algo raro, dime los nombres exactos y
lo ajustamos.

## Corrección: nada se mostraba (ni el fondo de pantalla)

`modules/FocusedScreen.qml` declaraba sus dos `Process` como hijos
anónimos sueltos dentro de un `QtObject`. El problema: a diferencia de
`Item` (que sí tiene una "propiedad por defecto" para aceptar hijos sin
nombrarlos — así están escritos `Workspaces.qml`, `ActiveWindow.qml`,
etc.), `QtObject` no la tiene. Eso rompía la carga de todo el módulo
`./modules`, y por eso no aparecía absolutamente nada — ni siquiera el
fondo de pantalla o la barra, que ni dependen de `FocusedScreen`.

Se corrigió declarándolos como propiedades explícitas
(`property Process x: Process { ... }`), el mismo patrón que ya usaban
correctamente `AppUsage.qml` y `Wallpaper.qml`.

De paso, confirmamos con `niri msg -j outputs` que el nombre de pantalla
interna en este equipo es `LVDS-1` (no el más común `eDP-1`) — no hace
falta ningún ajuste por eso, ya que el nombre se lee dinámicamente y no
está hardcodeado en ningún lado.

## Cada barra muestra solo sus propios workspaces

Como cada monitor tiene su propia instancia de la barra
(`Variants { model: Quickshell.screens }`), pero `Workspaces.qml` pedía
"todos" los workspaces sin filtrar por output, en 2+ monitores veías
mezclados los de ambas pantallas en cada barra.

Se agregó `screenName` como propiedad que baja en cadena
`barWindow → Bar → Workspaces`: `shell.qml` le pasa `modelData.name` (el
nombre del output de esa instancia de la barra) a `Bar`, y `Bar` se lo
pasa a `Workspaces`, que ahora filtra la lista por el campo `output` que
ya trae cada workspace (tanto `niri msg -j workspaces` como
`swaymsg -t get_workspaces` lo incluyen). Cada barra debería mostrar
únicamente los workspaces de su propio monitor.

## Tanda de correcciones y mejoras (multi-monitor, systray, wallpaper, red, layout)

**1. Espacios de trabajo mezclados entre pantallas**: esto ya se había
corregido en el paso anterior (filtro `screenName` en `Workspaces.qml`,
conectado desde `shell.qml` → `Bar.qml` → `Workspaces.qml`). Si lo seguías
viendo mezclado, asegúrate de estar usando el zip más reciente.

**2. Menú contextual del systray (click derecho) no aparecía**: el bug
real estaba en `modules/SysTray.qml` — se pasaba `this` dentro de un
arrow function (`onClicked: (mouse) => { ...this... }`), y los arrow
function en JS **no** "rebindean" `this` como sí lo hace una función
normal, así que apuntaba al objeto equivocado. Se corrigió usando la
ventana real vía la propiedad adjunta `Window.window` y la posición del
ícono mapeada a esa ventana con `mapToItem`. **Aviso de versión**: el
método `SystemTrayItem.display(window, x, y)` es, junto con notificaciones
e íconos, de lo más nuevo/sensible a la versión de Quickshell — si sigue
sin abrir el menú, revisa la consola de quickshell (dejé un `try/catch`
con `console.log` para que el error, si lo hay, se vea ahí).

**3. Selector de fondo de pantalla mejorado**
(`modules/WallpaperPicker.qml`):
- Ya no se cierra al elegir un fondo — puedes ir probando varios seguidos.
- Navegación con las 4 flechas (calcula columnas según el ancho de la
  grilla), Enter aplica el fondo donde estás parado, Esc cierra.
- Recuerda en qué posición ibas (`Wallpaper.lastIndex`, en memoria — dura
  mientras quickshell siga corriendo, se reinicia si reinicias la sesión)
  y retoma ahí la próxima vez que lo abras.
- Resaltado: el fondo **actualmente aplicado** se marca con borde verde y
  un check ✓ en la esquina; la posición del **cursor de teclado** (con la
  que te mueves con las flechas) se marca con borde azul — así se
  distinguen aunque no coincidan.

**4. IP local al hacer click en la conexión**: nuevo
`modules/NetworkPopup.qml`, abierto al hacer click en `NetworkIndicator`
(antes no hacía nada al click). Corre
`ip -4 -o addr show scope global` y lista interfaz + IP de cada una con
dirección IPv4 activa.

**5. (Solo sway) Número de workspace vacío se mostraba como "ventana
activa"**: cuando un workspace no tiene ninguna ventana, sway igual marca
ese workspace como `"focused": true` en el árbol — `ActiveWindow.qml`
tomaba ese nodo y mostraba su nombre (el número del workspace). Se
corrigió exigiendo que el nodo tenga `pid` (solo lo tienen ventanas
reales, no contenedores de workspace/output) para contar como "ventana
activa".

**6. (Solo sway) Popups apareciendo siempre en la pantalla principal**: el
código de `FocusedScreen.qml` para sway era estructuralmente idéntico al
de niri (que sí te funcionó), así que no encontré un bug concreto en la
lógica — agregué de todos modos un sondeo de respaldo cada 2s (además del
`swaymsg -t subscribe`) por si algún cambio de foco entre monitores no
dispara el evento esperado. Si sigue sin seguir el foco correctamente
después de este cambio, lo más probable es un desfase entre el nombre que
reporta `swaymsg -t get_outputs` para cada output y el que expone
`Quickshell.screens[]` — compáralos y dime qué ves para ajustar el
matching exacto.

**7. (Solo sway) Falta el ícono de red en el systray**: esto no es un bug
de nuestra config — el ícono de red en el tray lo pone una aplicación
aparte (típicamente `nm-applet`), no Quickshell. Si en niri lo ves y en
sway no, seguramente `nm-applet` (u otro indicador de red) está
autoiniciándose en tu sesión de niri pero no en la de sway. Para agregarlo
en sway:
```bash
sudo pacman -S network-manager-applet   # si no lo tienes
```
y en `~/.config/sway/config`:
```
exec_always nm-applet --indicator
```

**8 y 9. Layout de la barra: 3 zonas reales**: `modules/Bar.qml` se
reescribió con `anchors` en vez de un solo `RowLayout` con un espaciador —
ahora el grupo izquierdo (Menu + Workspaces) se ancla a la izquierda, el
grupo derecho (Cpu, Ram, Volumen, Red, tray+notificaciones, Batería,
Reloj, Power) se ancla a la derecha, y `ActiveWindow` ocupa exactamente el
espacio que queda en el medio, con el texto centrado dentro de esa franja.
Esto también explica por qué se veía distinto entre sway y niri: antes
`ActiveWindow` estaba agrupado con el bloque izquierdo, así que su ancho
variable (según el largo del título de la ventana) empujaba el resto de
forma inconsistente — con el layout de 3 zonas eso ya no pasa.

## Tanda 2: menú del systray, wallpaper picker, y 3 cajas nuevas

**1. Menú contextual del systray — causa real encontrada**: el error que
compartiste lo dice todo:
```
ERROR: Cannot display PlatformMenuEntry as quickshell was not started in QApplication mode.
ERROR: To use platform menus, add `//@ pragma UseQApplication` to the top of your root QML file and restart quickshell.
```
Se agregó esa línea como primera línea de `shell.qml`:
```qml
//@ pragma UseQApplication
```
**Importante**: esto cambia el modo de arranque de la app, así que no basta
con recargar — hay que **matar el proceso de quickshell y volver a
lanzarlo** (`pkill quickshell` y que tu `exec`/`spawn-at-startup` lo
vuelva a levantar, o lanzarlo a mano). De paso, `modules/SysTray.qml`
ahora intenta primero `QsMenuAnchor` (la forma "nativa" en QML) y si falla
cae a `display()` como respaldo, dejando en la terminal cuál de los dos
falló — con el pragma puesto, no debería hacer falta el respaldo.

**2. Wallpaper picker se posiciona en el fondo actual al abrir**: antes
usaba `Wallpaper.lastIndex` (la última posición navegada); ahora, cuando
termina de escanear, busca el índice de `Wallpaper.current` en la lista y
se ubica ahí (si por algún motivo no lo encuentra, cae a `lastIndex` como
antes). El bug de timing que había que evitar: el escaneo es asíncrono
(las imágenes llegan una por una), así que la posición se calcula recién
cuando el proceso de escaneo termina, no apenas se abre.

**3. Caja de IP local más chica**: bajó de 260×160 a 190×100, con menos
margen y texto un poco más chico.

**4. Tres cajas nuevas, mismo patrón que la de red** (click para
abrir/cerrar, pantalla completa transparente de fondo para poder cerrar
con click afuera, siguiendo el monitor con foco):

- **CPU** (`modules/CpuPopup.qml`, click en el indicador de CPU): muestra
  `nproc` (hilos totales) y una barra de uso por cada hilo, actualizada
  cada 1.5s mientras está abierta (usa `/proc/stat` por núcleo, mismo
  cálculo de delta que ya usábamos para el total).
- **RAM** (`modules/RamPopup.qml`, click en el indicador de RAM): total
  usada y total disponible, formateadas en GB si son ≥1 GB o en MB si no,
  con una barra de progreso.
- **Volumen (OSD)** (`modules/VolumeOsdPopup.qml`): a diferencia de las
  otras, esta NO se abre con click — aparece sola arriba centrada cada vez
  que el volumen o el mute cambian (rueda del mouse sobre el indicador, o
  las teclas multimedia, ya que ambas terminan tocando el mismo sink de
  Pipewire) y se cierra sola 1.5s después de la última vez que cambió. No
  tiene click-afuera porque no lo necesita.

Todos comparten los mismos flags nuevos en `Bridge.qml`: `cpuPopupOpen`,
`ramPopupOpen`, `volumeOsdVisible` (más `networkPopupOpen` de la tanda
anterior).

## Corrección: "PlatformMenuEntry.display() must be called with a window"

Con el pragma `UseQApplication` puesto, ya se intentaba llamar a
`display()`, pero fallaba porque la ventana que le pasábamos
(`trayItem.Window.window`, la propiedad adjunta de QtQuick.Window) no se
resolvía correctamente dentro de la jerarquía de componentes de
Quickshell — llegaba nula o inválida.

Se corrigió pasando la ventana real de forma explícita, en cadena:
`shell.qml` (donde la `PanelWindow` de la barra tiene `id: barWindow`) →
`Bar.qml` (nueva propiedad `barWindow`) → `SysTray.qml` (la recibe y la
usa directamente en `display(root.barWindow, x, y)`), en vez de intentar
adivinarla desde dentro del propio ícono.

Sigue habiendo un primer intento con `QsMenuAnchor` (la vía más "nativa"
en QML); si eso falla, cae a `display()` con la ventana ya correcta. Si
todavía da algún error, la consola de quickshell debería mostrar
exactamente cuál de las dos vías falló y por qué.

## Corrección: "QsMenuAnchor is not a type"

`QsMenuAnchor` no existe en tu versión instalada de Quickshell — era el
"intento nativo" que había agregado como primera opción antes de caer a
`display()`. Se quitó por completo; `modules/SysTray.qml` ahora usa
únicamente `display(root.barWindow, x, y)`, que ya tiene la ventana
correcta pasada explícitamente desde `shell.qml` → `Bar.qml` →
`SysTray.qml`.

## Cajas de CPU/RAM/Vol/Red posicionadas dinámicamente + bug del volumen

**Diseño final**: las 4 cajas (CPU, RAM, volumen y red) ahora aparecen
centradas justo debajo de su módulo correspondiente en la barra, en vez
de con márgenes fijos calculados a ojo (que se veían bien en una
resolución y mal en otra, o directamente desalineados).

Cómo funciona: se agregó `modules/BarPositions.qml` (singleton) que guarda
la posición X y el ancho de cada módulo **por monitor** (clave
`"<nombre-del-monitor>:<módulo>"`). Cada uno de los 4 indicadores
(`Cpu.qml`, `Ram.qml`, `VolumeIndicator.qml`, `NetworkIndicator.qml`)
ahora recibe su `screenName` (igual que ya hacía `Workspaces.qml`) y
reporta su propia posición ahí mismo, recalculándola cada vez que se
mueve o cambia de ancho (por ejemplo, cuando el texto de al lado cambia de
largo y todo se corre). Las ventanas de las cajas, en `shell.qml`, leen
esa posición con `BarPositions.getPos(modelData.name, "cpu")` (etc.) y se
centran automáticamente debajo con
`leftMargin: pos.x + pos.width/2 - width/2`.

**Bug del volumen que empujaba el escritorio/fondo hacia abajo**: la
ventana del widget de volumen usaba `anchors { top: true }` sola (ancla
solo el borde superior, sin fijar los otros 3), a diferencia de todas las
demás ventanas de esta barra que anclan los 4 bordes. Eso hacía que, sin
un `exclusiveZone` explícito, el compositor le reservara espacio como si
fuera otra barra — empujando hacia abajo todo lo demás (fondo, contenido,
o la barra según el compositor) cada vez que aparecía. Se corrigió
anclando los 4 bordes igual que el resto y agregando
`WlrLayershell.exclusiveZone: -1` explícito (que significa "nunca
reserves espacio"), tanto en esta ventana como, por seguridad, en las
otras 3 cajas nuevas (red/CPU/RAM) que hasta ahora no lo tenían puesto de
forma explícita.

## Bug del posicionamiento inicial, títulos centrados, y módulo TEMP

**1. La caja de CPU aparecía mal posicionada la primera vez**: dos causas
combinadas:
- El primer reporte de posición (`Component.onCompleted`) se disparaba
  antes de que el `RowLayout` de la barra terminara de acomodar los ítems
  — se corrigió envolviéndolo en `Qt.callLater(...)`, que lo pospone hasta
  que el layout ya asentó.
- Las ventanas de las cajas leían la posición a través de una función
  (`BarPositions.getPos(...)`), y ese nivel de indirección no siempre
  disparaba la reactividad de QML de forma confiable. Se cambió a lectura
  directa de la propiedad (`BarPositions.positions[...]`), que sí
  garantiza que la caja se reposicione apenas la posición real esté
  disponible — sin necesitar ninguna interacción de por medio (como abrir
  el launcher) para "despertarla".

**2. Títulos centrados**: "Memoria RAM", "CPU — N hilos" e "IP local"
ahora quedan centrados con `Layout.fillWidth: true` +
`horizontalAlignment: Text.AlignHCenter`.

**3. Módulo TEMP nuevo**, entre RAM y Volumen: `modules/Temp.qml` lee las
zonas térmicas del kernel en `/sys/class/thermal/thermal_zone*/type` y
`.../temp` (en milésimas de grado), prefiriendo una zona cuyo nombre
contenga "pkg" o "cpu" (la del procesador) y si no encuentra ninguna así
usa la primera disponible. Al hacer click abre `modules/TempPopup.qml`,
que lista TODAS las zonas detectadas con su temperatura — útil si tienes
sensores de más de un componente (CPU, GPU, NVMe, etc.).

Si en tu equipo no aparece nada (`TEMP --` y el popup dice "sin datos"),
es porque `/sys/class/thermal` no expone ninguna zona en tu hardware/VM —
no hay mucho que hacer ahí sin `lm-sensors` instalado y configurado
(`sensors-detect`), que sería un cambio más grande si lo necesitas.

## Confirmación con cuenta regresiva, botones de energía en el launcher, y borrado individual de notificaciones

**1. Botones de energía en el launcher del botón Menu (solo ese)**:
`modules/LauncherPopup.qml` ahora acepta `showPowerButtons: true/false`
(por defecto `false`). En `shell.qml`, solo la instancia del launcher que
abre el botón Menu lo tiene activado — la centrada por atajo de teclado
queda exactamente igual que antes, sin esos botones. Aparecen tres
botones abajo: "Cerrar sesión", "Reiniciar" y "Apagar".

**2. Confirmación con cuenta regresiva de 8s**: nuevo singleton
`modules/PendingAction.qml`, que guarda qué acción está pendiente
(etiqueta + comando) y si la ventana de confirmación debe estar abierta.
Se dispara desde tres lugares:
- Los 3 botones nuevos del launcher.
- "Cerrar sesión"/"Reiniciar"/"Apagar" de **ambos** power menus (el del
  botón Power y el del atajo de teclado). "Bloquear" y "Suspender" siguen
  ejecutándose de inmediato, sin pasar por la confirmación — solo las
  tres acciones "serias" la requieren.

`modules/ConfirmActionPopup.qml` muestra la etiqueta de la acción, la
cuenta regresiva ("Se ejecutará en Ns"), y dos botones: **Cancelar**
(aborta todo) y **Aceptar ahora** (ejecuta de inmediato sin esperar). Si
no tocas nada, se ejecuta sola al llegar a 0. Aparece centrada en
pantalla, y **a propósito no se cierra con click afuera** — al ser una
acción seria, exige una decisión explícita (Cancelar, Aceptar ahora, o
dejar correr el conteo) en vez de poder cerrarse por accidente.

**3. Borrado individual de notificaciones**: en
`modules/NotificationCenterPopup.qml`, cada notificación del historial
ahora tiene un ícono ✕ a la derecha (visible siempre, se resalta en rojo
al pasar el mouse) que la borra sin tocar las demás. También se puede
navegar la lista con las flechas ↑/↓ (la fila seleccionada se resalta) y
borrar la seleccionada con la tecla **X**. "Limpiar" se renombró a
"Limpiar todas" para diferenciarla del borrado individual.

Internamente, `modules/Notifications.qml` ahora le da a cada entrada del
historial un `historyId` propio (autoincremental), en vez de usar el id
de D-Bus de la notificación — ese id puede reciclarse entre
notificaciones distintas con el tiempo, así que no era seguro usarlo para
borrar una sola sin arriesgarse a borrar otra por error.

## Nuevo intento: bug persistente de la caja de CPU al primer click

El intento anterior (leer la posición vía `BarPositions.positions[clave]`,
un mapa indexado por texto) seguía sin funcionar de forma confiable en el
primerísimo uso — solo se corregía si pasaba algo más (como abrir el
launcher) que forzara una reevaluación general.

Se simplificó todo el mecanismo para depender lo menos posible de partes
de QML que puedan comportarse distinto según la versión:

- `modules/BarPositions.qml` ahora tiene propiedades **planas y directas**
  (`cpuX`, `cpuWidth`, `ramX`, `ramWidth`, `tempX`, `tempWidth`, `volX`,
  `volWidth`, `lanX`, `lanWidth`) en vez de un mapa indexado por clave de
  texto — una lectura directa de propiedad es el caso más simple y mejor
  soportado de la reactividad de QML, sin ninguna capa de indirección de
  por medio.
- Cada indicador (`Cpu.qml`, `Ram.qml`, `Temp.qml`, `VolumeIndicator.qml`,
  `NetworkIndicator.qml`) ahora solo reporta su posición si está en la
  pantalla que tiene el foco (comparando contra `FocusedScreen.name`) —
  como la caja solo se muestra ahí de todos modos, esto evita que dos
  monitores se pisen el valor entre sí, y ya no hace falta guardar nada
  "por pantalla" en un mapa.
- Se agregó un timer de respaldo (cada 2s) en los 5 indicadores que
  vuelve a reportar la posición igual, además de cuando cambia `x` o
  `width` — puramente defensivo, por si algún cambio puntual no llegara a
  disparar la señal correspondiente.
- En `shell.qml`, cada caja lee directamente `BarPositions.cpuX` /
  `BarPositions.cpuWidth` (etc.) en su margen, en vez de armar un objeto
  intermedio.

Si con todo esto la caja de CPU sigue apareciendo mal la primera vez,
dime exactamente cuántos segundos esperaste antes del primer click — con
el timer de respaldo cada 2s, si esperas al menos ese tiempo debería
estar bien posicionada incluso si el reporte inicial fallara por completo.

## Nuevo módulo: visor de atajos de teclado (lee config.kdl)

- Se agregó `KeybindsButton.qml` (ícono ⌨ en la barra, junto a la campana
  de notificaciones) y `KeybindsPopup.qml`, una ventana centrada — misma
  familia visual que el launcher y el power menu — que lista todos los
  atajos configurados.
- El popup lee directamente `~/.config/niri/config.kdl` (ruta
  configurable vía la propiedad `configPath`) y aísla el bloque
  `binds { ... }` de nivel superior.
- Incluye un campo de búsqueda que filtra por combinación, descripción o
  categoría.
- Se agregó el atajo `Mod+Alt+K` en `niri-config-snippet.kdl` para
  abrir/cerrar el visor (`quickshell ipc call keybinds toggle`), siguiendo
  el mismo patrón IPC que el launcher, el power menu y el wallpaper picker.
- Limitación conocida: solo parsea el archivo principal; no sigue
  `include`s (niri no los soporta de forma nativa, así que no debería ser
  un problema en la práctica).

### Dos modos de listado

**Modo curado (recomendado):** anota los binds que quieras que aparezcan
con comentarios `// @category ...` y `// @title ...` justo antes de cada
uno, dentro del bloque `binds { }`:

```kdl
binds {
    // @category Aplicaciones

    // @title Abrir terminal
    Mod+Return { spawn "alacritty"; }

    // @title Abrir lanzador
    Mod+Alt+D { spawn "quickshell" "ipc" "call" "launcher" "toggle"; }

    // @category Ventanas

    // @title Cerrar ventana
    Mod+Shift+Q { close-window; }
}
```

Si el visor encuentra al menos un `// @title`, muestra **solo** esos
binds anotados, agrupados por el `@category` más reciente — el resto de
tu config queda afuera. Ya dejé anotado `niri-config-snippet.kdl` como
ejemplo funcional.

**Modo automático (respaldo):** si tu `config.kdl` no tiene ninguna
anotación `@title`, el visor lista automáticamente TODOS los binds del
bloque, usando `hotkey-overlay-title="..."` si el bind lo tiene, o una
descripción generada a partir de la acción (`spawn "wpctl" ...` → "Ejecutar:
wpctl ..."), agrupados por los comentarios `//` normales que los preceden.
Así, aunque no anotes nada, el visor siempre muestra algo útil.

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
fijo al extremo izquierdo, fuera del sistema). Si lo ocultás, el panel
de Ajustes muestra una advertencia recordando cómo volver a abrirlo:
con el atajo `Mod+,` (agregado a los 3 snippets de compositor) o
corriendo `quickshell ipc call bar-config toggle` desde una terminal —
ambos funcionan esté o no visible el módulo en la barra.

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
llamar a `quickshell -c niri-bar` directamente en tu autostart. El script
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

También se agregó el comando IPC `bar-visibility` (`hide`/`show`/`toggle`),
por si en algún momento querés forzar ocultar/mostrar la barra desde un
script externo sin tocar la preferencia de auto-ocultado:
```
quickshell ipc call bar-visibility hide
quickshell ipc call bar-visibility show
quickshell ipc call bar-visibility toggle
```

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
con `activeWindow`) que al hacer click —o con su atajo `Mod+Alt+C`—
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

## Atajos de teclado: se agregó Alt a la mayoría

Para dejar más margen contra choques con atajos de tus apps o del propio
compositor, casi todos los atajos de Quickshell pasaron a llevar `Alt`
además de `Mod` (el menú de energía es la excepción: pasó a
`Mod+Shift+X`). Ver la tabla completa en la sección 3, más arriba. Si
venías de una instalación anterior, actualizá tu `~/.config/niri/config.kdl`
con el snippet nuevo — los atajos viejos (`Mod+D`, `Mod+W`, etc.) ya no
están en el snippet.

