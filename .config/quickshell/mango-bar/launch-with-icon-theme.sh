#!/bin/sh
# Lanza quickshell autodetectando el tema de íconos GTK activo (el mismo
# que ya usan rofi, GTK, etc.) y exportándolo como QS_ICON_THEME antes de
# arrancar -- esto es lo que hace falta para que Quickshell/Qt resuelvan
# los mismos íconos que otras apps, ya que por defecto Quickshell sigue el
# "platform theme" de Qt, que en sesiones mango/niri/sway/Hyprland sin
# qt5ct o qt6ct suele quedar sin configurar (aunque el tema SÍ esté
# instalado y GTK lo encuentre bien, como en tu caso).
#
# Uso: usá esta línea como exec-once en tu ~/.config/mango/config.conf
# (ver mango-config-snippet.conf):
#   exec-once = sh ~/.config/quickshell/mango-bar/launch-with-icon-theme.sh

theme=""

for f in "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"; do
  [ -f "$f" ] || continue
  t=$(grep -m1 '^gtk-icon-theme-name' "$f" | cut -d= -f2 | tr -d '[:space:]')
  [ -n "$t" ] && theme="$t" && break
done

if [ -z "$theme" ] && command -v gsettings >/dev/null 2>&1; then
  theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" )
fi

if [ -n "$theme" ]; then
  export QS_ICON_THEME="$theme"
  echo "launch-with-icon-theme: usando QS_ICON_THEME=$theme" >&2
else
  echo "launch-with-icon-theme: no se pudo detectar el tema de iconos GTK -- arrancando sin QS_ICON_THEME" >&2
fi

exec qs -c mango-bar
