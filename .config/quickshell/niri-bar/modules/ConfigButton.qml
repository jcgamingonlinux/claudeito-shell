import QtQuick

Rectangle {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    implicitWidth: label.implicitWidth + Scaling.pxFor(screenName, 16)
    implicitHeight: Scaling.pxFor(screenName, 24)
    radius: Scaling.pxFor(screenName, 4)
    color: hover.containsMouse ? "#585b70" : "#313244"
    Text { id: label; anchors.centerIn: parent; text: "Ajustes"; color: "#cdd6f4"; font.bold: true; font.pixelSize: Scaling.pxFor(screenName, 12) }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: Bridge.togglePopup("barConfigOpen") }
}

