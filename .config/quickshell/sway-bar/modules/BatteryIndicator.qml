import QtQuick

Item {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    id: root
    property var device: BatteryMonitor.device
    property bool isBattery: BatteryMonitor.isBattery
    readonly property bool onAC: BatteryMonitor.onAC
    readonly property int percent: BatteryMonitor.percent

    // Reporta su posición en la barra (para que su caja de info aparezca
    // centrada justo debajo) cada vez que se mueve o cambia de ancho.
    function reportPos() {
        if (root.screenName.length === 0) return
        if (root.screenName !== FocusedScreen.name) return
        let pos = root.mapToItem(null, 0, root.height)
        BarPositions.batteryX = pos.x
        BarPositions.batteryWidth = root.width
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

    readonly property string batteryGlyph: {
        if (root.percent >= 90) return "\uf240"
        if (root.percent >= 65) return "\uf241"
        if (root.percent >= 40) return "\uf242"
        if (root.percent >= 15) return "\uf243"
        return "\uf244"
    }

    // 80-100 verde, 50-80 amarillo, 30-50 ámbar, <30 rojo -- se aplica
    // siempre según el nivel real de carga, esté o no en AC.
    readonly property color levelColor: {
        if (root.percent >= 80) return "#a6e3a1"
        if (root.percent >= 50) return "#f9e2af"
        if (root.percent >= 30) return "#fab387"
        return "#f38ba8"
    }

    visible: isBattery
    implicitWidth: isBattery ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: Scaling.pxFor(screenName, 4)

        Text {
            // Enchufe si está en AC; pila (según nivel) si está a batería.
            text: root.onAC ? "\uf1e6" : root.batteryGlyph
            font.family: "JetBrainsMono Nerd Font"
            color: root.levelColor
            font.pixelSize: Scaling.pxFor(screenName, 12)
        }
        Text {
            text: root.percent + "% " + (root.onAC ? "AC" : "BAT")
            color: root.levelColor
            font.pixelSize: Scaling.pxFor(screenName, 12)
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.togglePopup("batteryPopupOpen")
    }
}
