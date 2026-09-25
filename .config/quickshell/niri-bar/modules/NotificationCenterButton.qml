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
        BarPositions.notificationsX = pos.x
        BarPositions.notificationsWidth = width
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
    implicitWidth: row.implicitWidth + 12
    implicitHeight: Scaling.pxFor(screenName, 22)
    radius: Scaling.pxFor(screenName, 4)
    color: mouseArea.containsMouse ? "#585b70" : "#313244"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Scaling.pxFor(screenName, 4)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "🔔"
            font.pixelSize: Scaling.pxFor(screenName, 12)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.history.length > 0
            text: Notifications.history.length
            color: "#f5e0dc"
            font.pixelSize: Scaling.pxFor(screenName, 11)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Bridge.togglePopup("notificationsOpen")
    }
}
