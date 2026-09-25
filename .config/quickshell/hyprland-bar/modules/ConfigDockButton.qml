import QtQuick

// Botón de barra "Config": abre ConfigDockPopup, un dock chico con accesos
// directos a Keybinds, Ajustes y Wallpaper (ver ConfigDockPopup.qml).
// Mismo patrón visual que ConfigButton.qml (Ajustes).
Rectangle {
    id: root
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    implicitWidth: label.implicitWidth + Scaling.pxFor(screenName, 16)
    implicitHeight: Scaling.pxFor(screenName, 24)
    radius: Scaling.pxFor(screenName, 4)
    color: hover.containsMouse ? "#585b70" : "#313244"

    // Reporta su posición en la barra (para que el Dock aparezca centrado
    // justo debajo/arriba, igual que las cajas de CPU/RAM/etc. -- ver
    // BarPositions.qml) cada vez que se mueve, cambia de ancho, o cambia
    // de zona (izquierda/centro/derecha).
    function reportPos() {
        if (root.screenName.length === 0) return
        if (root.screenName !== FocusedScreen.name) return
        let pos = root.mapToItem(null, 0, root.height)
        BarPositions.configDockX = pos.x
        BarPositions.configDockWidth = root.width
    }
    onXChanged: root.reportPos()
    onWidthChanged: root.reportPos()
    Component.onCompleted: Qt.callLater(root.reportPos)

    // Respaldo: reporta también cada 2s por si algún xChanged/widthChanged
    // puntual no llegara a dispararse (ej. al cambiar de zona en Ajustes).
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.reportPos()
    }

    Text { id: label; anchors.centerIn: parent; text: "Config"; color: "#cdd6f4"; font.bold: true; font.pixelSize: Scaling.pxFor(screenName, 12) }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: Bridge.togglePopup("configDockOpen") }
}

