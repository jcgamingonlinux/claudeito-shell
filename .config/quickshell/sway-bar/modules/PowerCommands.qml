pragma Singleton
import QtQuick

// El diseño anterior detectaba una sola vez al arrancar (con un Process
// async) cuál de systemctl/loginctl/raw usar, y guardaba el resultado en
// una propiedad. Tenía una condición de carrera real: si se hacía click
// en Reiniciar/Apagar ANTES de que esa detección terminara, quedaba
// pegado el valor por defecto ("systemctl"). En Alpine (sin systemctl)
// eso hacía que el primer click fallara en silencio -- el comando
// systemctl ni existe ahí -- y recién el segundo click, ya con la
// detección terminada, usaba loginctl y funcionaba.
//
// Ahora en vez de detectar y recordar, cada acción intenta cada
// herramienta en el momento y sigue con la próxima solo si la anterior
// no está instalada (systemctl/loginctl/raw, en ese orden) -- no hay
// ningún estado que pueda quedar desactualizado. Mismo patrón que ya usa
// downloadWallhaven() en WallpaperPicker.qml con curl/wget.
//
// Se usa desde los 2 power menus y desde los botones de abajo del
// launcher para Suspender/Reiniciar/Apagar, así que vive acá en vez de
// duplicar estos comandos en cada lugar.
//
// "Cerrar sesión" y "Bloquear" quedan afuera de esto a propósito: cerrar
// sesión ya es específico de cada compositor (hyprctl/swaymsg/niri msg,
// no tiene nada que ver con systemd), y bloquear usa swaylock.
//
// OJO con "raw" (ni systemctl ni loginctl instalados, SysV puro sin
// elogind): a diferencia de las otras dos opciones, reboot/poweroff
// directos normalmente necesitan privilegios (root/sudo/doas configurado
// sin contraseña) -- systemctl/loginctl no, porque pasan por polkit. Y
// no hay un comando de suspender universal ahí: pm-suspend (paquete
// pm-utils) es lo más parecido a un estándar en sistemas SysV/OpenRC
// tradicionales, pero no está garantizado -- avisame si tu sistema usa
// otra cosa.
QtObject {
    function poweroffCmd() { return ["sh", "-c", "systemctl poweroff || loginctl poweroff || poweroff"] }
    function rebootCmd() { return ["sh", "-c", "systemctl reboot || loginctl reboot || reboot"] }
    function suspendCmd() { return ["sh", "-c", "systemctl suspend || loginctl suspend || pm-suspend"] }
}
