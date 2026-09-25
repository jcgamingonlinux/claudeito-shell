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

    function refresh() { getWorkspaces.running = true }

    // El workspace enfocado trae el nombre del output al que pertenece
    // (mismo dato que ya usa Workspaces.qml).
    property Process getWorkspaces: Process {
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(text)
                    let focused = list.find(w => w.is_focused)
                    if (focused && focused.output) root.name = focused.output
                } catch (e) { console.log("FocusedScreen: error parseando workspaces", e) }
            }
        }
    }

    property Process subscriber: Process {
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    // Sondeo de respaldo: por si algún cambio de foco entre monitores no
    // llega a través del event-stream, esto refresca igual como máximo
    // cada 2s.
    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
