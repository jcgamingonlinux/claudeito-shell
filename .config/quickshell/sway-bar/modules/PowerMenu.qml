import QtQuick

Rectangle {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""

    // Reporta su posición en la barra (para que su ventana emergente
    // aparezca centrada justo debajo/encima, en vez de un margen fijo que
    // no seguía al módulo si lo reordenabas en Ajustes).
    function reportPos() {
        if (screenName.length === 0) return
        if (screenName !== FocusedScreen.name) return
        let pos = mapToItem(null, 0, height)
        BarPositions.powerX = pos.x
        BarPositions.powerWidth = width
    }
    onXChanged: reportPos()
    onWidthChanged: reportPos()
    Component.onCompleted: Qt.callLater(reportPos)
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: reportPos()
    }
    implicitWidth: row.implicitWidth + 16
    implicitHeight: Scaling.pxFor(screenName, 22)
    radius: Scaling.pxFor(screenName, 4)
    color: mouseArea.containsMouse ? "#585b70" : "#313244"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Scaling.pxFor(screenName, 4)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf011"
            font.family: "JetBrainsMono Nerd Font"
            color: "#f38ba8"
            font.pixelSize: Scaling.pxFor(screenName, 13)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Power"
            color: "#f38ba8"
            font.bold: true
            font.pixelSize: Scaling.pxFor(screenName, 12)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Bridge.togglePopup("menuPowerOpen")
    }
}
