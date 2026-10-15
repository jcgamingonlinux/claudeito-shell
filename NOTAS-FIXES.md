# Claudito Shell — Fixes aplicados (2026-10-14)

Repo corregido localmente (sin push). Base: `claudeito-src` (clon de
`https://gitlab.com/linux-en-casa/claudito-shell`).

## Bugs corregidos

### 1. [BLOQUEANTE] `01-install-arch.sh` — paquete inexistente `xorg`
- **Línea 178** (array `pkgs_base`): `xorg` no existe como paquete en
  Arch (core/extra/multilib). Verificado contra los índices
  `*.db.tar.gz` (15.522 paquetes) y la API JSON de archlinux.org.
  Solo existen paquetes `xorg-*`. `pacman -S` fallaba y abortaba
  la instalación base.
- **Fix:** `xorg` → `xorg-server` (el X server real; `xorg-xwayland`
  ya se instala aparte por compositor).

### 2. [FUNCIONAL] `01-install-arch.sh` — condición invertida en yay/paru
- **Líneas 1061 y 1075**: `if [ ! -d "/tmp/yay" ]; then sudo rm -rf
  ...` borraba el directorio solo cuando **no** existía. En una
  re-ejecución del script, `git clone` fallaba (directorio ya
  ocupado) y el script abortaba.
- **Fix:** `[ ! -d ... ]` → `[ -d ... ]` en ambos casos (yay y paru).
- **Fix adicional (copy-paste):** en el caso paru el mensaje de error
  decía "No se pudo instalar yay." → ahora "No se pudo borrar
  /tmp/paru." (el de yay quedó "No se pudo borrar /tmp/yay.").

### 3. [COSMÉTICO] `03-install-forky.sh` — mensajes copy-paste
- **Líneas 978 y 989** (caso mango): decían "borrando directorio
  temporal de ly" al borrar `/tmp/scenefx` y `/tmp/mango`.
- **Fix:** ahora dicen "de scenefx" y "de mango" respectivamente.
  El de línea 1169 (caso `ly`, directorio `/tmp/ly`) era correcto y
  se mantuvo.

### 4. [MEDIO] `01-install-arch.sh` — no se copiaban configs de terminal
- Hyprland usa kitty, niri usa alacritty, sway usa foot, pero el
  script arch solo copiaba la config del compositor: cada terminal
  arrancaba con su config por defecto.
- **Fix:** se agregaron los bloques de copia (mismo patrón que ya
  tiene `03-install-forky.sh`): `backup_if_exists` + `rm -rf` +
  `cp -r kitty/|alacritty/|foot/ $HOME/.config/` en cada caso
  respectivo. Los directorios `.config/kitty`, `.config/alacritty` y
  `.config/foot` ya existían en el repo.

### 5. [MEDIO] `02-install-trixie.sh` — misma falta que 4
- **Fix:** idéntico al 4, en los casos hyprland/niri/sway.

### 6. [COSMÉTICO] `01-install-arch.sh` — mensajes SDDM en el caso `ly`
- **Líneas 1058 y 1060** (caso `ly)` de display managers): dos
  check_error **comentados** decían "No se pudo instalar/activar
  SDDM" (copy-paste del caso sddm). Solo estético (están en
  comentarios), pero se corrigió igual: ahora dicen "ly".
- Hallazgo reportado por el pase de calidad (subagente) tras
  aplicar los fixes 1-5.

### 7. [FUNCIONAL] Menús: no advertía si el usuario no seleccionaba nada (los 3 scripts)
- **El problema:** en los 5 menús de selección (WM, Software, Apps, DM,
  Flatpak), si el usuario presionaba ENTER sin marcar ninguna opción
  (o desmarcaba todas), el script seguía adelante **sin avisar** con
  esa sección vacía: en una instalación nueva quedaba sin WM o sin
  pack de software y el usuario no entendía por qué no se instaló
  nada. No había ninguna ayuda con las teclas que había que usar.
- **Fix:** nueva función `warn_no_selection()` + cada menú ahora
  entra en un loop: si se confirma con la selección vacía, muestra un
  aviso de diálogo explicando que hay que elegir al menos una opción
  con las teclas (ESPACIO = marcar/desmarcar, ENTER = confirmar,
  ESC = volver sin tocar la selección) y reabre el menú. Si el
  usuario presiona ESC, se mantiene el estado previo (comportamiento
  original). Se aplica a los 5 menús de los 3 scripts (código
  idéntico en los tres, verificado por md5).
- **Verificado:** (1) harness unitario con `dialog` simulado contra el
  código real extraído del archivo — 3 casos: vacío → aviso →
  reabre → se aplica la selección; selección directa sin aviso; ESC
  sin tocar el estado previo. (2) Test visual en vivo en la mini PC
  (CachyOS, 192.168.1.12): con el menú de WMs vacío, ENTER mostró
  el aviso exacto y reabrió el menú; después se marcó hyprland con
  ESPACIO+ENTER y quedó `wm_hyprland=1` en `~/.wm-installer-state`.

### 8. [FUNCIONAL] Menús: "Cancelar" cerraba el script (set -e) en vez de volver al menú (los 3 scripts)
- **El problema:** el script arranca con `set -euo pipefail`. Con ese modo,
  un `dialog` que devuelve 1 (Cancelar/ESC/No) **mata el script** si no
  está protegido con `||`. En "Restaurar backup" (y en el diálogo de
  confirmación de restauración, el checklist de archivos y la pantalla
  de bienvenida) las llamadas a dialog estaban sin proteger:
  `chosen=$(dialog ... --menu ...)` → al presionar Cancelar, `dialog`
  devuelve 1, la asignación falla y `set -e` cierra todo el script,
  cuando lo esperado era volver al menú principal.
- **Fix (los 3 scripts):**
  - `show_restore_menu`: `chosen=$(dialog ... --menu ...)` ahora termina
    en `|| return 0` → Cancelar vuelve al menú principal.
  - `restore_backup`: el checklist `selected=$(dialog ...)` termina en
    `|| { rm -f "$idx_file"; return 0; }` (y además limpia el índice
    temporal).
  - Los dos `--yesno` ("Confirmar restauración" y la pantalla de
    bienvenida) cambiaron de `dialog ... ; if [[ $? -ne 0 ]]` a un
    `if dialog ...; then ... else ... fi` directo: con el patrón viejo,
    el `dialog` suelto que devuelve 1 moría por `set -e` antes de leer
    el `$?`.
  - El aviso `warn_no_selection` ahora devuelve el rc del dialog
    (`|| rc=$?` + `return "$rc"`), y los 5 menús usan `if ! warn_
    no_selection ...; then return 0; fi`: ENTER en el aviso reabre el
    menú; **ESC en el aviso vuelve al menú principal sin tocar la
    selección** (lo que dice el propio texto del aviso).
  - Todos los msgbox/infobox restantes (Resumen, Leeme, Bienvenida,
    Preparando, "no hay backups", "restauración completada", etc.)
    llevan `|| true` para que un ESC/cierre no mate el script.
- **Verificado:** harness contra el código real extraído de cada script
  (4 escenarios por archivo, 15 ejecuciones): cancelar en el menú de
  fechas, cancelar en el checklist, "No" en la confirmación, y una
  restauración completa exitosa (archivo realmente restaurado). Los 3
  scripts pasan.

### 9. [PEDIDO] Créditos: "JC Gaming On Linux - fork, mejoras y testeo, asistido por JC IA"
- Agregado en los 3 scripts: (a) bloque de créditos al inicio del
  archivo y (b) en el diálogo "Instrucciones - Leeme" (el crédito que
  se ve desde el menú principal), debajo de "Script by Gabriel Parri".

### 10. [PEDIDO] Advertencia "WM primero" + créditos en Bienvenida (los 3 scripts)
- **Problema reportado:** al pasar a otra sección sin haber elegido un
  Window Manager, el script se cerraba en vez de indicar que falta el WM.
- **Fix (los 3 scripts):**
  - Nueva función `wm_selected()` (0 = hay al menos un WM marcado).
  - En el bucle del menú principal, toda opción que no sea `wm` pasa
    primero por `if ! wm_selected; then`: muestra el aviso
    "Falta el Window Manager — Todavía no seleccionaste ningún Window
    Manager. Vole al menú principal y elegí primero el WM (opción 1)
    antes de continuar." y, tras Aceptar (ENTER), `continue` de vuelta
    al menú principal. Con WM elegido, las secciones abren como siempre.
  - Créditos "JC Gaming On Linux - fork, mejoras y testeo, asistido por
    JC IA" agregados también en la pantalla de **Bienvenida** (bajo
    "Script by Gabriel Parri"), igual que en el Leeme.
- **Verificado en vivo (mini PC, HOME fresco):** bienvenida muestra el
  crédito; entrar a software/apps/dm/summary/restore/leeme sin WM
  muestra el aviso y Aceptar vuelve al menú principal; con WM marcado
  (niri) las secciones abren sin aviso. Secciones probadas sin WM
  (todas OK, sin crash): software (basico), apps (yay), dm (sddm),
  summary, restore, leeme.

### 11. [FUNCIONAL] Fixes defensivos `set -e`: estado viejo, HOME y hostnamectl (los 3 scripts)
- **Problema (hallado por el pase de QA):** con `set -euo pipefail`,
  tres líneas podían cerrar el script de forma silenciosa:
  - `load_state`: la línea `[[ -v WM_DESC[$k] ]] && SEL_WM[$k]=$v`
    (y las de `apps_*`/`flatpak_*`) devuelve 1 si el archivo de estado
    trae una clave que ya no existe en el menú (ej. `wm_mango=1` en la
    versión Arch, que no tiene mango). Si esa era la última línea, el
    `while` devolvía 1, la función devolvía 1 y la llamada suelta
    `load_state` moría el script al arrancar.
  - `save_state`: la primera línea `: > "$STATE_FILE"` fallaba si el
    directorio de `$HOME` no existía (ej. arranque con HOME inválido).
  - `show_welcome` (01): `host="$(hostnamectl | grep hostname | awk ... )"`:
    si `hostnamectl` no existe o no emite "hostname" (sin systemd), el
    pipeline fallaba y moría el script en la Bienvenida.
- **Fix (los 3 scripts; `hostnamectl` solo existe en 01):**
  - `load_state`: `|| true` en las 3 líneas de asignación + `return 0`
    explícito al final.
  - `save_state`: `mkdir -p "$(dirname "$STATE_FILE")"` antes de
    escribir.
  - `01 show_welcome`: `hostnamectl 2>/dev/null | ... || true`.
- **Verificado:** `bash -n` en los 3; harness unitario contra el código
  real extraído (T1: estado viejo con clave inválida → sobrevive y
  conserva las válidas; T2: HOME inexistente → `save_state` crea el
  directorio y escribe; T3: pipeline de `hostnamectl` fallando → no
  mata el script); test A/B de la función `load_state` con el estado
  viejo (sin fix: devuelve 1 y moría; con fix: rc=0); consistencia
  entre los 3 scripts (los parches son idénticos, verificado por
  patrón). Además: todos los usos de `check_error` llevan `|| exit 1`
  (36/36 en 01, 35/35 en 02, 40/40 en 03) y `SEL_WM` está
  inicializado para todas las claves, por lo que `wm_selected` es
  seguro bajo `set -u`.

## Verificado (no era bug)
- `xdg-user-dirs-update` (trixie/forky): es un **comando** (del
  paquete `xdg-user-dirs`), no un paquete a instalar. El paquete
  `xdg-user-dirs` sí está en los 3 scripts. Falso positivo.
- `meson` sin `ninja-build` en forky: `meson` trae `ninja-build`
  como dependencia. Falso positivo.
- `evince`, `gdebi`, `gimp`, `nwg-displays` en arrays `*_backports`
  de trixie: no están en backports pero SÍ en main; `apt -t
  trixie-backports` los toma de main. Funciona.
- `hyprland`, `hyprland-guiutils`, `quickshell`,
  `xdg-desktop-portal-hyprland`: no están en main de trixie, pero
  SÍ en trixie-backports, donde el script los instala. OK.
- Barras QML (4 comp): los diffs grandes (KeybindsPopup, Workspaces,
  WindowList, ActiveWindow, FocusedScreen) son comandos legítimos por
  compositor (`hyprctl` / `niri msg` / `swaymsg` / `mmsg`). Los
  pequeños son diffs cosméticos legítimos.
- scenefx: el tag `0.5` existe en GitHub y el proyecto es C (meson,
  sin Rust). Build de forky cubierto.

## Optimizaciones APLICADAS (0.2)
1. **Modo prueba local (los 3 scripts)**: los scripts siempre
   clonaban el repo desde GitLab a `/tmp/claudito-shell`, así que no
   se podía probar esta versión corregida sin subirla. Ahora:
   - Si el script se ejecuta desde la raíz de un checkout de
     claudito-shell (detecta `.config/quickshell` + `release/`), usa
     ese directorio directamente y **no clona** desde GitLab.
   - `REPOGITLAB` y `REPOLOCAL` se pueden sobreescribir con
     variables de entorno (`REPOLOCAL=/ruta bash 01-install-arch.sh`).
   - El clonado original (borrar + `git clone`) queda intacto en el
     modo normal.
2. **Forky: mango fijado al tag `0.14.4`** (`git clone -b 0.14.4
   https://github.com/mangowm/mango.git`). Antes compilaba desde
   `master` (sin version fija; hoy era 0.18.0, la config del repo
   está probada contra 0.14.4, la misma del `.deb` de trixie).
   El tag `0.14.4` existe (verificado en GitHub API).

## Optimizaciones NO aplicadas (verificadas, para decidir)
1. **Trixie usa `.deb` forky** de `xwayland-satellite`: verificado
   que ese `.deb` tiene **Depends vacío** (sin dependencias), así que
   instala sin problemas sobre trixie. No se cambia.
2. **`mango_0.14.4-1_amd64-trixie.deb`** sigue sin usarse (trixie no
   tiene opción mango en el menú; forky compila). Se deja en
   `release/` por si se quiere.
3. **Forky: `sudo apt install -y pcmanfm`** (línea ~760, antes del
   pack de software): NO es redundante — si el usuario no elige
   ningún pack, esa es la única instalación de pcmanfm. Se deja.
4. **Forky: `sudo rm -rf`** sobre `~/.config/...` (directorios del
   usuario): funciona; es estilo. No se cambia para no ensanchar el
   diff.
5. **Arch**: `xorg-server` en base + `xorg-xwayland` por compositor
   es coherente; si en el futuro solo se usan compositores Wayland,
   se podría mover `xorg-server` a los casos que lo necesiten
   (xfce4-screenshooter/xterm son apps X).

## Cómo probarlo (sin subir nada)
El repo tiene git local (histórico completo del upstream + un commit
con todos los fixes, autor "Linux en Casa").

1. Copiá `claudeito-fixes/` a la máquina de prueba (VM) o probalo
   directo en este disco:
   ```
   cd claudeito-fixes
   sudo ./01-install-arch.sh      # Arch / derivadas
   sudo ./02-install-trixie.sh    # Debian 13 Trixie
   sudo ./03-install-forky.sh     # Debian 14 Forky (testing)
   ```
   Al detectarse que se ejecuta desde la raíz del repo, mostrará
   "Modo local: usando el repositorio en ... (no se clona desde
   GitLab)" y usará las configs/debs de ESTE repo (los corregidos).
2. Alternativa: desde cualquier directorio,
   `REPOLOCAL=/ruta/a/claudeito-fixes sudo bash /ruta/01-install-arch.sh`
   (clona desde GitLab a esa ruta; útil si el repo va en otra rama).
3. Si después decides subirlo: el git ya está armado
   (`git log` muestra el commit de fixes); solo hay que
   `git remote add fork <tu-gitlab> && git push -u fork $(git branch --show-current)`.
