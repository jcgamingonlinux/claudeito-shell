import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Nombre del monitor (output) al que pertenece esta instancia de la
    // barra. Si está vacío, se muestran todos los workspaces (comportamiento
    // anterior); si trae un nombre, se filtra solo a los de ese monitor.
    property string screenName: ""

    property var workspaces: []
    readonly property var filtered: root.screenName.length === 0
        ? root.workspaces
        : root.workspaces.filter(w => w.output === root.screenName)

    function refresh() { getWorkspaces.running = true }

    // Consulta puntual del estado actual: niri msg -j workspaces
    // devuelve un array de objetos: { id, idx, name, output, is_active, is_focused, ... }
    Process {
        id: getWorkspaces
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(text)
                    list.sort((a, b) => a.idx - b.idx)
                    root.workspaces = list
                } catch (e) { console.log("Workspaces: error parseando JSON", e) }
            }
        }
    }

    // niri no tiene un filtro de eventos tan granular como sway; nos suscribimos
    // al event-stream completo y simplemente refrescamos ante cualquier línea.
    Process {
        id: subscriber
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    // "focus-workspace-by-id" no es una acción real de niri (era un error
    // de la versión anterior) — la acción correcta es "focus-workspace",
    // referenciando el workspace por su nombre si tiene uno, o si no por
    // su índice (idx). Capturamos stderr para poder ver en la terminal
    // si el nombre de la acción vuelve a no coincidir con tu versión de niri.
    Process {
        id: switcher
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) console.log("Workspaces: niri msg action falló:", text)
            }
        }
    }

    Component.onCompleted: root.refresh()

    RowLayout {
        id: row
        spacing: Scaling.pxFor(screenName, 4)

        Repeater {
            model: root.filtered
            delegate: Rectangle {
                required property var modelData
                implicitWidth: Scaling.pxFor(screenName, 26)
                implicitHeight: Scaling.pxFor(screenName, 22)
                radius: Scaling.pxFor(screenName, 4)
                color: modelData.is_focused ? "#89b4fa"
                       : (modelData.is_active ? "#45475a" : "transparent")

                Text {
                    anchors.centerIn: parent
                    // niri numera los workspaces desde 1 en su propio "idx" — mostrar
                    // idx directamente (sin sumarle 1) evita el desfase de "estoy en
                    // el 1 y muestra 2".
                    text: modelData.name ? modelData.name : modelData.idx
                    color: modelData.is_focused ? "#1e1e2e" : "#cdd6f4"
                    font.pixelSize: Scaling.pxFor(screenName, 12)
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: Bridge.closeTransientPopups()
                    onClicked: {
                        let ref = modelData.name ? modelData.name : String(modelData.idx)
                        switcher.command = ["niri", "msg", "action", "focus-workspace", ref]
                        switcher.running = true
                    }
                }
            }
        }
    }
}
