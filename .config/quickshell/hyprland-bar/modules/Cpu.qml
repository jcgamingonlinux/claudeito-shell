import QtQuick
import Quickshell.Io

Item {
    id: root

    // Reporta su posición en la barra (para que su caja de info aparezca
    // centrada justo debajo) cada vez que se mueve o cambia de ancho.
    property string screenName: ""
    function reportPos() {
        if (root.screenName.length === 0) return
        // Solo reporta si esta instancia está en la pantalla con foco —
        // la caja de info solo se muestra ahí, así que no hace falta (ni
        // conviene) que otra pantalla sobreescriba el valor.
        if (root.screenName !== FocusedScreen.name) return
        let pos = root.mapToItem(null, 0, root.height)
        BarPositions.cpuX = pos.x
        BarPositions.cpuWidth = root.width
    }
    onXChanged: root.reportPos()
    onWidthChanged: root.reportPos()
    Component.onCompleted: Qt.callLater(root.reportPos)

    // Respaldo: reporta también cada 2s por si algún xChanged/widthChanged
    // puntual no llegara a dispararse.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.reportPos()
    }
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property real percent: 0
    property real lastIdle: 0
    property real lastTotal: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -n1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(/\s+/).slice(1).map(Number)
                let idle = parts[3] + parts[4]
                let total = parts.reduce((a, b) => a + b, 0)
                let diffIdle = idle - root.lastIdle
                let diffTotal = total - root.lastTotal
                if (root.lastTotal > 0 && diffTotal > 0) {
                    root.percent = (1 - diffIdle / diffTotal) * 100
                }
                root.lastIdle = idle
                root.lastTotal = total
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }

    Text {
        id: label
        text: "CPU " + root.percent.toFixed(0) + "%"
        color: "#cdd6f4"
        font.pixelSize: Scaling.pxFor(screenName, 12)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.togglePopup("cpuPopupOpen")
    }
}
