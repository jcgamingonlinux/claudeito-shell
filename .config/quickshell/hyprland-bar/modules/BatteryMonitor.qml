pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

// Notificaciones y alertas de batería, en UN SOLO lugar para toda la
// sesión (sin importar cuántas pantallas/copias de BatteryIndicator haya
// -- antes esa lógica vivía en el propio módulo de la barra, que existe
// una vez POR PANTALLA, así que con 3 monitores cada evento real disparaba
// 3 notificaciones idénticas, una por cada copia).
QtObject {
    id: root

    property var device: UPower.displayDevice
    property bool isBattery: device && device.isLaptopBattery

    readonly property bool onAC: root.device
        && root.device.state !== UPowerDeviceState.Discharging
        && root.device.state !== UPowerDeviceState.PendingDischarge
    readonly property int percent: root.device ? Math.round(root.device.percentage * 100) : 0

    // --- Notificación al conectar/desconectar el cargador ---
    property bool _acKnown: false
    property bool _lastOnAC: false
    // FIX: antes la "base" (para no notificar el estado que ya tenías al
    // arrancar) se establecía recién en la PRIMERA transición detectada
    // -- si esa primera transición coincidía con tu acción real (ej.
    // desconectar apenas arrancaba quickshell), esa notificación se
    // perdía. Ahora la base se fija apenas hay datos reales de batería
    // disponibles (no cuando cambian), así cualquier cambio real
    // posterior -- incluida la primera acción del usuario -- sí notifica.
    onIsBatteryChanged: {
        if (root.isBattery && !root._acKnown) {
            root._acKnown = true
            root._lastOnAC = root.onAC
        }
    }
    Component.onCompleted: {
        if (root.isBattery && !root._acKnown) {
            root._acKnown = true
            root._lastOnAC = root.onAC
        }
    }
    onOnACChanged: {
        // Al reconectar a AC se resetean los avisos de batería baja, para
        // que puedan volver a sonar si se vuelve a descargar más adelante
        // en la misma sesión.
        if (root.onAC) root._warnedThresholds = []

        if (!root.isBattery) return
        if (!root._acKnown) { root._acKnown = true; root._lastOnAC = root.onAC; return }
        if (root.onAC !== root._lastOnAC) {
            root._lastOnAC = root.onAC
            notifier.command = ["notify-send", "-a", "Batería",
                root.onAC ? "Cargador conectado" : "Cargador desconectado",
                root.onAC ? "Usando corriente alterna" : ("Usando batería (" + root.percent + "%)")]
            notifier.running = true
        }
    }

    // --- Alertas de batería baja (80/50/30/20/15/10/5%), con sonido ---
    // Solo mientras se está descargando (onOnACChanged ya resetea todo al
    // reconectar el cargador, así que 80/50 pueden volver a sonar en la
    // próxima descarga de la misma sesión). Se agregaron 80% y 50% como
    // avisos tempranos -- el resto de los umbrales y el mecanismo de "ya
    // avisado" son los mismos de antes.
    readonly property var _lowThresholds: [80, 50, 30, 20, 15, 10, 5]
    // Umbrales ya avisados desde la última vez que se conectó a AC (o
    // desde que arrancó la sesión). Nota: si la sesión arranca ya por
    // debajo de alguno de estos valores, ese aviso sale de una en el
    // primer chequeo -- es intencional, para no quedarse sin avisar si
    // ya estabas bajo de carga cuando abriste sesión.
    property var _warnedThresholds: []
    onPercentChanged: {
        if (!root.isBattery || root.onAC) return
        // Se juntan acá todos los umbrales recién cruzados en ESTE mismo
        // cambio de porcentaje -- puede ser más de uno si, por ejemplo,
        // el equipo estuvo suspendido y el porcentaje salta de golpe al
        // reanudar (ej. de 85% a 45% de una, cruzando 80 y 50 juntos).
        for (let i = 0; i < root._lowThresholds.length; i++) {
            let t = root._lowThresholds[i]
            if (root.percent <= t && root._warnedThresholds.indexOf(t) === -1) {
                root._warnedThresholds = root._warnedThresholds.concat([t])
                root.fireLowBatteryAlert(t)
            }
        }
    }

    // Antes esto reutilizaba UN solo Process para todos los avisos. Si
    // dos umbrales se cruzaban en el mismo cambio de porcentaje, la
    // segunda reasignación de "command" pisaba a la primera ANTES de que
    // "running" pudiera disparar un nuevo lanzamiento (pasar de true a
    // true de nuevo no hace nada) -- el segundo aviso simplemente no
    // sonaba. Ahora cada aviso arma su propio Process descartable (mismo
    // patrón que ya se usa para lanzar apps en LauncherPopup.launch()).
    function fireLowBatteryAlert(t) {
        let proc = Qt.createQmlObject(
            "import Quickshell.Io; Process { stderr: StdioCollector { onStreamFinished: { if (text.trim().length > 0) console.log('BatteryMonitor: no se pudo reproducir el sonido de alerta (revisá /tmp/quickshell-battery-sound.err):', text) } } }",
            root,
            "lowBatteryAlertProc"
        )
        proc.command = ["sh", "-c",
            "notify-send -u critical -a Batería 'Batería baja' '" + t + "% o menos' ; " +
            "( (command -v canberra-gtk-play >/dev/null 2>&1 && canberra-gtk-play -i battery-caution) " +
            // FIX: acá se apuntaba a battery-low.oga, que NO viene incluido
            // en el tema de sonidos freedesktop (se confirmó revisando el
            // paquete real, tanto en Arch como en Debian/Ubuntu) -- por
            // eso nunca sonaba nada salvo que canberra-gtk-play (que
            // requiere GTK3, no siempre instalado en un setup niri/sway/
            // Hyprland sin entorno GNOME) estuviera presente y funcionando.
            // dialog-warning.oga sí viene incluido en el tema y es un tono
            // de "atención" apropiado para esto.
            "|| paplay /usr/share/sounds/freedesktop/stereo/dialog-warning.oga " +
            "|| pw-play /usr/share/sounds/freedesktop/stereo/dialog-warning.oga " +
            // FIX: se saca aplay de la cadena -- es un reproductor de ALSA
            // que solo entiende WAV/PCM crudo, nunca pudo reproducir un
            // .oga (Ogg Vorbis) aunque el archivo hubiese existido.
            // FIX: el \\\\a de acá tenía un backslash de más y terminaba
            // imprimiendo el texto literal "\\a" en vez de hacer sonar la
            // campana del terminal (\\a). Ya corregido -- aunque, sin una
            // terminal conectada, un Process en segundo plano rara vez
            // puede hacer sonar algo por acá; queda como último recurso.
            "|| printf '\\a' ) 2>/tmp/quickshell-battery-sound.err"]
        proc.runningChanged.connect(() => { if (!proc.running) proc.destroy() })
        proc.running = true
    }

    property Process notifier: Process { }
}
