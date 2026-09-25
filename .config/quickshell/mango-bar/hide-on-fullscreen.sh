#!/bin/sh
# Escucha los cambios del cliente enfocado en mango (mmsg) y oculta/muestra
# la barra cuando ese cliente entra/sale de fullscreen. mango debería
# ocultar los layer-surfaces "Top" (como esta barra) automáticamente al
# entrar a fullscreen real, pero por las dudas -- mismo respaldo explícito
# que ya usás en hyprland-bar (ver ese README, hyprwm/Hyprland discussions
# #8757) -- este script cubre el caso de que no lo haga.
#
# OJO nombre de campo adivinado: se asume que el JSON de
# "mmsg watch focusing-client" trae un campo "fullscreen" (bool) -- es el
# nombre más probable dado que el dispatcher para esto se llama
# "togglefullscreen" y el flag viejo de mmsg es "-m Get fullscreen
# status", pero la wiki no publica el esquema exacto. Si no anda, corré
# "mmsg watch focusing-client" a mano en una terminal, hacé fullscreen a
# una ventana y fijate cómo se llama el campo en el JSON que aparece.
#
# No requiere socat (mmsg ya maneja el socket de mango por su cuenta).
#
# Uso: agregá esta línea a tu ~/.config/mango/config.conf, ADEMÁS de la
# que ya lanza quickshell (no la reemplaza):
#   exec-once = sh ~/.config/quickshell/mango-bar/hide-on-fullscreen.sh

if ! command -v mmsg >/dev/null 2>&1; then
    echo "hide-on-fullscreen (mango): no encontré 'mmsg' en el PATH" >&2
    exit 1
fi

was_fullscreen=""

mmsg watch focusing-client | while IFS= read -r line; do
    case "$line" in
        *'"fullscreen":true'*|*'"fullscreen": true'*)
            if [ "$was_fullscreen" != "1" ]; then
                qs -c mango-bar ipc call bar-visibility hide
                was_fullscreen=1
            fi
            ;;
        *'"fullscreen":false'*|*'"fullscreen": false'*)
            if [ "$was_fullscreen" != "0" ]; then
                qs -c mango-bar ipc call bar-visibility show
                was_fullscreen=0
            fi
            ;;
    esac
done
