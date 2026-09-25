import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// A diferencia de Hyprland/niri/Sway (un workspace activo por monitor),
// mango usa TAGS estilo dwm: siempre existen los 9 (1-9) por monitor, una
// ventana puede estar en más de uno, y podés estar VIENDO más de uno a la
// vez ("multiview", con comboview/toggleview). Por eso este módulo no
// lista "los workspaces que existen" como el original -- siempre dibuja
// los 9 botones fijos, y superpone el estado que llega por IPC.
//
// Click izquierdo  -> "view"       (mirar SOLO ese tag, reemplaza la vista)
// Click derecho    -> "toggleview" (sumar/sacar ese tag de la vista actual
//                      sin perder los demás -- esto es el multiview)
//
// Esquema de "mmsg get/watch all-tags" CONFIRMADO en pruebas reales
// (Debian 14 forky):
//   { "all_tags": [
//       { "monitor": "Virtual-1", "tags": [
//           { "index": 1, "is_active": true, "is_urgent": false,
//             "layout": "T", "client_count": 1 },
//           ...
//       ]},
//       ...
//   ]}
// "is_active" = este tag está siendo visto ahora mismo (no "ocupado").
// "client_count" es lo que se usa acá para derivar "ocupado" (> 0).
// "layout" queda sin usar por ahora (disponible si en algún momento
// querés mostrar el layout activo de cada tag).
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Nombre del monitor (output). Los tags son por monitor, así que sin
    // screenName se toma el primer monitor que devuelva mango (probable
    // que no sea lo que querés en multi-monitor).
    property string screenName: ""

    // [{num, occupied, selected, urgent}, ...] para el monitor filtrado.
    property var tags: []

    // Siempre expone los 9 tags (1-9), completando con "vacío" los que no
    // vinieron en la respuesta -- así los botones SIEMPRE aparecen y
    // funcionan para cambiar de tag, incluso si por algún motivo faltara
    // alguno en la respuesta de mango.
    readonly property var display: {
        let byNum = {}
        root.tags.forEach(t => byNum[t.num] = t)
        let out = []
        for (let n = 1; n <= 9; n++)
            out.push(byNum[n] || { num: n, occupied: false, selected: false, urgent: false })
        return out
    }

    function refresh() { getData.running = true }

    property bool _loggedSample: false
    function applyAllTags(text) {
        try {
            let data = JSON.parse(text)
            if (!root._loggedSample) {
                console.log("Workspaces/Tags (mango): JSON crudo de all-tags:", text)
                root._loggedSample = true
            }

            let groups = data.all_tags
            if (!Array.isArray(groups)) {
                console.log("Workspaces (mango): esperaba data.all_tags como array, recibí:", text)
                return
            }

            let group = (root.screenName.length > 0)
                ? groups.find(g => g.monitor === root.screenName)
                : groups[0]
            if (!group || !Array.isArray(group.tags)) return

            root.tags = group.tags.map(t => ({
                num: t.index,
                occupied: (t.client_count || 0) > 0,
                selected: t.is_active === true,
                urgent: t.is_urgent === true
            })).filter(t => t.num >= 1 && t.num <= 9)
        } catch (e) {
            console.log("Workspaces (mango): error parseando all-tags, JSON crudo:", text)
        }
    }

    Process {
        id: getData
        command: ["mmsg", "get", "all-tags"]
        stdout: StdioCollector {
            onStreamFinished: root.applyAllTags(text)
        }
    }

    // "mmsg watch all-tags" reemplaza al socat+socket2 de Hyprland: mango
    // ya maneja la conexión al socket por su cuenta.
    Process {
        id: subscriber
        command: ["mmsg", "watch", "all-tags"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.applyAllTags(line)
        }
    }

    // Sondeo de respaldo por si "watch" se cae.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: dispatcher
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (out.length > 0) console.log("Workspaces: mmsg dispatch, respuesta:", out)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) console.log("Workspaces: mmsg dispatch falló:", text)
            }
        }
    }

    Component.onCompleted: root.refresh()

    RowLayout {
        id: row
        spacing: Scaling.pxFor(screenName, 4)

        property bool blinkOn: false
        Timer {
            interval: 500
            repeat: true
            running: root.display.some(t => t.urgent)
            onTriggered: row.blinkOn = !row.blinkOn
        }

        Repeater {
            model: root.display
            delegate: Rectangle {
                required property var modelData
                implicitWidth: Scaling.pxFor(screenName, 22)
                implicitHeight: Scaling.pxFor(screenName, 22)
                radius: Scaling.pxFor(screenName, 4)
                color: modelData.urgent ? (row.blinkOn ? "#f38ba8" : "#45475a")
                       : modelData.selected ? "#89b4fa"
                       : (modelData.occupied ? "#45475a" : "transparent")
                border.width: modelData.occupied && !modelData.selected ? Scaling.pxFor(screenName, 1) : 0
                border.color: "#6c7086"

                Text {
                    anchors.centerIn: parent
                    text: modelData.num
                    color: modelData.selected ? "#1e1e2e" : "#cdd6f4"
                    font.pixelSize: Scaling.pxFor(screenName, 12)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: Bridge.closeTransientPopups()
                    onClicked: (mouse) => {
                        // Confirmado: dispatch "view,<mask>" reemplaza la
                        // vista; "toggleview,<mask>" suma/saca ese tag sin
                        // tocar los demás (multiview). Click derecho para
                        // multiview porque es la operación "aditiva", más
                        // parecida a un click secundario/contextual.
                        dispatcher.command = mouse.button === Qt.RightButton
                            ? ["mmsg", "dispatch", "toggleview," + modelData.num]
                            : ["mmsg", "dispatch", "view," + modelData.num]
                        dispatcher.running = true
                    }
                }
            }
        }
    }
}
