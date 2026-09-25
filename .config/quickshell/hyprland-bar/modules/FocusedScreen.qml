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

    property Process getMonitors: Process {
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(text)
                    let focused = list.find(m => m.focused === true)
                    if (focused && focused.name) root.name = focused.name
                } catch (e) { console.log("FocusedScreen: error parseando monitors", e) }
            }
        }
    }

    property Process subscriber: Process {
        command: ["sh", "-c", "socat -U - UNIX-CONNECT:\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\" 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    // Sondeo de respaldo: por si algún cambio de foco entre monitores no
    // llega a través del socket de eventos (o falta socat), esto refresca
    // igual como máximo cada 2s.
    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
