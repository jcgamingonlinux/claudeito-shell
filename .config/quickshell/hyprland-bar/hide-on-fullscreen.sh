#!/bin/sh
# Escucha los eventos de fullscreen de Hyprland (socket2) y oculta/muestra
# la barra en consecuencia. Hyprland debería ocultar los layer-surfaces
# "Top" (como esta barra) automáticamente al entrar a fullscreen real,
# pero según versión/config a veces no lo hace y la barra queda flotando
# por encima de la ventana -- este script es un respaldo explícito, en la
# línea de lo que recomienda la propia comunidad de Hyprland para casos
# similares (ver hyprwm/Hyprland discussions #8757).
#
# Requiere socat (paquete "socat" en la mayoría de las distros).
#
# Uso: agregá esta línea a tu hyprland.conf, ADEMÁS de la que ya lanza
# quickshell (no la reemplaza):
#   exec-once = sh ~/.config/quickshell/hyprland-bar/hide-on-fullscreen.sh

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

if ! command -v socat >/dev/null 2>&1; then
    echo "hide-on-fullscreen: falta 'socat' (instalalo con tu gestor de paquetes)" >&2
    exit 1
fi

socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
    case "$line" in
        fullscreen\>\>1) qs -c hyprland-bar ipc call bar-visibility hide ;;
        fullscreen\>\>0) qs -c hyprland-bar ipc call bar-visibility show ;;
    esac
done
