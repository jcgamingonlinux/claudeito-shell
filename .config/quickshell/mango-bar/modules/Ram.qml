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
        BarPositions.ramX = pos.x
        BarPositions.ramWidth = root.width
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

    Process {
        id: ramProc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                let total = parseInt(lines[0].match(/\d+/)[0])
                let avail = parseInt(lines[1].match(/\d+/)[0])
                root.percent = ((total - avail) / total) * 100
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ramProc.running = true
    }

    Text {
        id: label
        text: "RAM " + root.percent.toFixed(0) + "%"
        color: "#cdd6f4"
        font.pixelSize: Scaling.pxFor(screenName, 12)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.togglePopup("ramPopupOpen")
    }
}
