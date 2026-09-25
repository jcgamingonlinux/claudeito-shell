-- === Añade esto a tu ~/.config/hypr/hyprland.lua ===
-- (Hyprland 0.55+, config Lua nueva — si todavía usás hyprland.conf
-- clásico, esto NO aplica; ver hyprland-config-snippet-legacy.conf en
-- cambio)
--
-- NOTA: estos comandos asumen que instalaste esta carpeta en una
-- subcarpeta CON NOMBRE dentro de ~/.config/quickshell/, es decir que
-- ~/.config/quickshell/hyprland-bar/shell.qml existe (no directo en
-- ~/.config/quickshell/shell.qml). Por eso todos los comandos usan
-- "-c hyprland-bar" -- así podés tener las 3 variantes (niri-bar,
-- sway-bar, hyprland-bar) instaladas al mismo tiempo sin que se pisen.
-- "qs" es el binario de quickshell (alias corto habitual -- si en tu
-- sistema el binario se llama "quickshell" en vez de "qs", cambialo en
-- todas las líneas de abajo).

local mainMod = "SUPER"

-- 1) Lanza quickshell al iniciar Hyprland
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c hyprland-bar")
end)

-- NOTA sobre los comentarios "-- @category" / "-- @title" de abajo: son
-- opcionales, y los lee el visor de atajos (botón ⌨ / SUPER+ALT+K) para
-- mostrar SOLO los binds anotados así, agrupados por categoría. Con la
-- config Lua nueva, anotar es más importante que en niri/sway/el
-- hyprlang clásico: el modo automático (sin anotar) es más limitado acá
-- porque no todo bind de Lua se puede resumir sin ejecutarlo (ver
-- README). Así que para esta versión, anotar los binds importantes con
-- @title es lo recomendado, no solo lo opcional.

-- @category Quickshell

-- @title Abrir/cerrar launcher
hl.bind(mainMod .. " + ALT + D", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call launcher toggle"))
-- @title Abrir/cerrar menú de energía
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call powermenu toggle"))
-- @title Abrir/cerrar selector de fondo de pantalla
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call wallpaper toggle"))
-- @title Abrir/cerrar esta lista de atajos
hl.bind(mainMod .. " + ALT + K", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call keybinds toggle"))
-- @title Abrir/cerrar dock de accesos rápidos (Keybinds/Ajustes/Wallpaper)
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call config-dock toggle"))
-- @title Listado de ventanas abiertas (como "rofi -show window")
hl.bind(mainMod .. " + ALT + Tab", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call windowlist toggle"))
-- @title Abrir/cerrar Ajustes de la barra
-- Respaldo por si ocultás los módulos "Ajustes" y "Config" de la barra:
-- este atajo (y el comando `qs -c hyprland-bar ipc call bar-config
-- toggle`) siempre funcionan, estén o no visibles esos botones.
hl.bind(mainMod .. " + ALT + comma", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call bar-config toggle"))
-- @title Prender/apagar auto-ocultado de la barra
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("qs -c hyprland-bar ipc call autohide toggle"))

-- @category Multimedia

-- @title Subir volumen
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
-- @title Bajar volumen
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
-- @title Silenciar/activar audio
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
-- @title Silenciar/activar micrófono
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

-- 2) (Opcional) Brillo, si tienes un portátil con brightnessctl instalado
-- hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
-- hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
