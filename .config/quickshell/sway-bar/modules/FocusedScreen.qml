pragma Singleton
import QtQuick
import Quickshell.Io

// Nombre del monitor (output) que tiene el foco ahora mismo, para que los
// launchers/menús/calendario/etc. aparezcan en la pantalla donde estás
// trabajando en vez de siempre en la primera detectada.
//
// También trackea el NÚMERO de workspace enfocado (focusedWorkspaceNum).
// Se usa solo desde LauncherPopup.launch(): al lanzar una app, se reafirma
// ese workspace de forma atómica junto con el exec (ver comentario ahí) --
// mitigación para un comportamiento de Sway donde, si pasa un rato entre
// cambiar a un workspace recién creado (vacío, sin ninguna ventana todavía)
// y que la app lanzada realmente llegue a mapear su ventana, Sway puede
// "olvidar" ese cambio y la ventana nueva termina apareciendo en el
// workspace anterior. Pasa solo con workspaces vacíos -- swaywm/sway#6753,
// #9075 y #7864 documentan variantes del mismo problema. No es un bug de
// esta config, es de Sway; esto reduce la ventana del problema pero no lo
// garantiza al 100% (el propio "swaymsg exec" de Sway sufre lo mismo si
// pasa suficiente tiempo -- ver #7864).
//
// NOTA: QtObject no tiene "propiedad por defecto", así que los Process
// hijos deben declararse como "property Process x: Process { ... }" y no
// como bloques anónimos sueltos (eso rompe la carga de todo el módulo).
QtObject {
    id: root

    property string name: ""
    property int focusedWorkspaceNum: 1

    function refresh() {
        getOutputs.running = true
        getWorkspaces.running = true
    }

    property Process getOutputs: Process {
        command: ["swaymsg", "-t", "get_outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(text)
                    let focused = list.find(o => o.focused)
                    if (focused && focused.name) root.name = focused.name
                } catch (e) { console.log("FocusedScreen: error parseando outputs", e) }
            }
        }
    }

    property Process getWorkspaces: Process {
        command: ["swaymsg", "-t", "get_workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(text)
                    let focused = list.find(w => w.focused)
                    // num es -1 para workspaces con nombre no numérico
                    // (ej. renombrados a texto) -- ahí no hay nada
                    // sensato que reafirmar, se deja el último válido.
                    if (focused && focused.num >= 0) root.focusedWorkspaceNum = focused.num
                } catch (e) { console.log("FocusedScreen: error parseando workspaces", e) }
            }
        }
    }

    property Process subscriber: Process {
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"workspace\",\"output\"]"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    // Sondeo de respaldo: por si algún cambio de foco entre monitores no
    // dispara un evento "workspace"/"output" (o el subscribe se corta),
    // esto refresca igual como máximo cada 2s.
    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
