import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    readonly property var device: BatteryMonitor.device
    readonly property bool onAC: BatteryMonitor.onAC
    readonly property int percent: BatteryMonitor.percent
    readonly property bool charging: root.device && root.device.state === UPowerDeviceState.Charging

    readonly property color levelColor: {
        if (root.percent >= 80) return "#a6e3a1"
        if (root.percent >= 50) return "#f9e2af"
        if (root.percent >= 30) return "#fab387"
        return "#f38ba8"
    }

    readonly property string stateText: {
        if (!root.device) return "Sin información de batería"
        if (root.onAC && root.charging) return "Con corriente alterna, cargando"
        if (root.onAC) return "Con corriente alterna"
        if (root.percent <= 10) return "Con batería, descargando (nivel crítico)"
        return "Con batería, descargando"
    }

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el popup al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(8)

        Text {
            text: "Batería"
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(13)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: root.percent + "%"
            color: root.levelColor
            font.bold: true
            font.pixelSize: Scaling.px(22)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: Scaling.px(10)
            radius: Scaling.px(5)
            color: "#313244"

            Rectangle {
                width: parent.width * (root.percent / 100)
                height: parent.height
                radius: Scaling.px(5)
                color: root.levelColor
            }
        }

        Text {
            text: root.stateText
            color: "#cdd6f4"
            font.pixelSize: Scaling.px(12)
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }
    }
}
