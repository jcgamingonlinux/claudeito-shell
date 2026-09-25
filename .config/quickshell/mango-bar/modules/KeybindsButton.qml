import QtQuick

Rectangle {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    implicitWidth: label.implicitWidth + 14
    implicitHeight: Scaling.pxFor(screenName, 22)
    radius: Scaling.pxFor(screenName, 4)
    color: mouseArea.containsMouse ? "#585b70" : "#313244"

    Text {
        id: label
        anchors.centerIn: parent
        text: "⌨"
        font.pixelSize: Scaling.pxFor(screenName, 13)
        color: "#f5e0dc"
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Bridge.togglePopup("keybindsOpen")
    }
}
