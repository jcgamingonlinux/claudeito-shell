import QtQuick
import QtQuick.Controls
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

    property int threadCount: 0
    property var cores: []       // [porcentaje, porcentaje, ...]
    property var lastIdle: []
    property var lastTotal: []

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el popup al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    readonly property string script: `
nproc
grep -E '^cpu[0-9]+ ' /proc/stat
`

    Process {
        id: proc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                if (lines.length === 0) return
                root.threadCount = parseInt(lines[0]) || 0

                let newCores = []
                for (let i = 1; i < lines.length; i++) {
                    let parts = lines[i].trim().split(/\s+/).slice(1).map(Number)
                    if (parts.length < 5) continue
                    let idle = parts[3] + parts[4]
                    let total = parts.reduce((a, b) => a + b, 0)
                    let idx = i - 1
                    let prevIdle = root.lastIdle[idx] || 0
                    let prevTotal = root.lastTotal[idx] || 0
                    let diffIdle = idle - prevIdle
                    let diffTotal = total - prevTotal
                    let pct = 0
                    if (prevTotal > 0 && diffTotal > 0) pct = (1 - diffIdle / diffTotal) * 100
                    newCores.push(pct)
                    root.lastIdle[idx] = idle
                    root.lastTotal[idx] = total
                }
                // Se preserva la posición de scroll -- sin esto, cada
                // refresco (cada 1.5s) reiniciaba la ListView al comienzo.
                let savedY = coresList.contentY
                root.cores = newCores
                coresList.contentY = Math.max(0, Math.min(savedY, coresList.contentHeight - coresList.height))
            }
        }
    }

    Timer {
        interval: 1500
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(6)

        Text {
            text: "CPU — " + root.threadCount + " hilos"
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(13)
                    Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // El ListView ya venía con clip + scroll interno (con mouse wheel
        // funciona), pero sin ningún indicador visible no era obvio que se
        // podía scrollear -- en equipos con muchos hilos parecía que la
        // info simplemente se cortaba. El ScrollBar lo hace evidente.
        ListView {
            id: coresList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Scaling.px(4)
            model: root.cores

            ScrollBar.vertical: ScrollBar {
                policy: coresList.contentHeight > coresList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: RowLayout {
                required property real modelData
                required property int index
                width: ListView.view.width - Scaling.px(14)
                spacing: Scaling.px(6)

                Text {
                    text: "Hilo " + index
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.px(11)
                    Layout.preferredWidth: Scaling.px(46)
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Scaling.px(8)
                    radius: Scaling.px(4)
                    color: "#313244"

                    Rectangle {
                        width: parent.width * (Math.max(0, Math.min(100, modelData)) / 100)
                        height: parent.height
                        radius: Scaling.px(4)
                        color: "#89b4fa"
                    }
                }

                Text {
                    text: Math.round(Math.max(0, Math.min(100, modelData))) + "%"
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.px(11)
                    Layout.preferredWidth: Scaling.px(32)
                }
            }
        }
    }
}
