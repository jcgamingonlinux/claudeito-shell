pragma Singleton
import QtQuick
import Quickshell.Io

// Nombre del monitor (output) que tiene el foco ahora mismo, para que los
// launchers/menús/calendario/etc. aparezcan en la pantalla donde estás
// trabajando en vez de siempre en la primera detectada.
//
// NOTA: QtObject no tiene "propiedad por defecto", así que los Process
// hijos deben declararse como "property Process x: Process { ... }" y no
// como bloques anónimos sueltos (eso rompe la carga de todo el módulo).
QtObject {
    id: root

    property string name: ""

    function refresh() { getMonitors.running = true }

    // Confirmado en pruebas reales (ver "all_tags" del módulo de tags):
    // mango envuelve los arrays de "get all-*" en un objeto con la clave
    // en snake_case del propio comando -- "get all-tags" -> "all_tags".
    // Por analogía, "get all-monitors" debería venir envuelto en
    // "all_monitors". Ojo: dentro de cada monitor, el campo de nombre y
    // el de "tiene el foco" siguen sin confirmar (is_active/is_focused
    // fueron los nombres reales que usó mango para tags, así que se
    // prueban primero acá también) -- si esto sigue sin andar, el
    // console.log de abajo tira el JSON crudo completo para ajustarlo.
    property Process getMonitors: Process {
        command: ["mmsg", "get", "all-monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    let list = Array.isArray(data) ? data
                        : (Array.isArray(data.all_monitors) ? data.all_monitors
                        : (Array.isArray(data.monitors) ? data.monitors : null))

                    if (!Array.isArray(list)) {
                        console.log("FocusedScreen (mango): no encontré un array de monitores, JSON crudo:", text)
                        return
                    }

                    let focused = list.find(m => m.is_focused === true || m.is_active === true
                        || m.focused === true || m.active === true || m.selected === true)

                    if (focused && (focused.name || focused.monitor || focused.output))
                        root.name = focused.name || focused.monitor || focused.output
                    else if (list.length > 0)
                        console.log("FocusedScreen (mango): no reconocí el campo de foco, primer monitor crudo:", JSON.stringify(list[0]))
                } catch (e) {
                    console.log("FocusedScreen (mango): error parseando all-monitors, JSON crudo:", text)
                }
            }
        }
    }

    // "mmsg watch all-monitors" reemplaza al socat+socket2 de Hyprland --
    // mmsg ya maneja la conexión al socket de mango por su cuenta.
    property Process subscriber: Process {
        command: ["mmsg", "watch", "all-monitors"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    // Sondeo de respaldo: por si algún cambio de foco entre monitores no
    // llega a través de "watch" (o el proceso se cae), esto refresca
    // igual como máximo cada 2s.
    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
