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

    // Consulta puntual del estado actual
    Process {
        id: getWorkspaces
        command: ["swaymsg", "-t", "get_workspaces", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.workspaces = JSON.parse(text) }
                catch (e) { console.log("Workspaces: error parseando JSON", e) }
            }
        }
    }

    // Se queda escuchando eventos de sway para refrescar en tiempo real
    Process {
        id: subscriber
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"workspace\"]"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    Process {
        id: switcher
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) console.log("Workspaces: swaymsg falló:", text)
            }
        }
    }

    Component.onCompleted: root.refresh()

    RowLayout {
        id: row
        spacing: Scaling.pxFor(screenName, 4)

        // Parpadeo para los workspaces urgentes (ej. una app que ya estaba
        // abierta en otro workspace pidió atención). Solo corre mientras
        // haya al menos uno urgente -- se apaga solo en cuanto ya no queda
        // ninguno (Sway limpia el flag urgent cuando enfocás ese workspace).
        property bool blinkOn: false
        Timer {
            interval: 500
            repeat: true
            running: root.filtered.some(w => w.urgent)
            onTriggered: row.blinkOn = !row.blinkOn
        }

        Repeater {
            model: root.filtered
            delegate: Rectangle {
                required property var modelData
                implicitWidth: Scaling.pxFor(screenName, 26)
                implicitHeight: Scaling.pxFor(screenName, 22)
                radius: Scaling.pxFor(screenName, 4)
                color: modelData.urgent ? (row.blinkOn ? "#f38ba8" : "#45475a")
                       : modelData.focused ? "#89b4fa"
                       : (modelData.visible ? "#45475a" : "transparent")

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.focused ? "#1e1e2e" : "#cdd6f4"
                    font.pixelSize: Scaling.pxFor(screenName, 12)
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: Bridge.closeTransientPopups()
                    onClicked: {
                        switcher.command = ["swaymsg", "workspace", "number", modelData.name]
                        switcher.running = true
                    }
                }
            }
        }
    }
}
