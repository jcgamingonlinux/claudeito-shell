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
        BarPositions.menuX = pos.x
        BarPositions.menuWidth = width
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
    implicitWidth: label.implicitWidth + 20
    implicitHeight: Scaling.pxFor(screenName, 24)
    radius: Scaling.pxFor(screenName, 4)
    color: mouseArea.containsMouse ? "#585b70" : "#313244"

    Text {
        id: label
        anchors.centerIn: parent
        text: "Menu"
        color: "#f5e0dc"
        font.bold: true
        font.pixelSize: Scaling.pxFor(screenName, 12)
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Bridge.togglePopup("menuLauncherOpen")
    }
}
