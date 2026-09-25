import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    property var lines: []

    readonly property string script: `ip -4 -o addr show scope global 2>/dev/null | awk '{print $2": "$4}'`

    function scan() {
        root.lines = []
        proc.command = ["sh", "-c", root.script]
        proc.running = true
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: (line) => {
                let t = line.trim()
                if (t.length === 0) return
                let l = root.lines.slice()
                l.push(t)
                root.lines = l
            }
        }
    }

    onOpenChanged: if (root.open) root.scan()

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el popup al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(8)
        spacing: Scaling.px(4)

        Text {
            text: "IP local"
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(12)
                    Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: root.lines
            delegate: Text {
                text: modelData
                color: "#cdd6f4"
                font.pixelSize: Scaling.px(11)
            }
        }

        Text {
            visible: root.lines.length === 0
            text: "Sin direcciones IPv4 activas"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }

        Item { Layout.fillHeight: true }
    }
}
