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

    property real totalKB: 0
    property real usedKB: 0

    function fmt(kb) {
        if (kb >= 1024 * 1024) return (kb / 1024 / 1024).toFixed(1) + " GB"
        return Math.round(kb / 1024) + " MB"
    }

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el popup al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Process {
        id: proc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                if (lines.length < 2) return
                let total = parseInt(lines[0].match(/\d+/)[0])
                let avail = parseInt(lines[1].match(/\d+/)[0])
                root.totalKB = total
                root.usedKB = total - avail
            }
        }
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(8)

        Text {
            text: "Memoria RAM"
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(13)
                    Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "Usada: " + root.fmt(root.usedKB) + " de " + root.fmt(root.totalKB)
            color: "#cdd6f4"
            font.pixelSize: Scaling.px(12)
        }

        Rectangle {
            Layout.fillWidth: true
            height: Scaling.px(10)
            radius: Scaling.px(5)
            color: "#313244"

            Rectangle {
                width: parent.width * (root.totalKB > 0 ? root.usedKB / root.totalKB : 0)
                height: parent.height
                radius: Scaling.px(5)
                color: "#a6e3a1"
            }
        }

        Item { Layout.fillHeight: true }
    }
}
