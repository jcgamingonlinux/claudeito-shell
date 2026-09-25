import QtQuick
import QtQuick.Layouts

// Dock chico con 3 accesos directos en fila: Keybinds, Ajustes, Wallpaper.
// Mismo patrón que PowerMenuPopup.qml (selección con teclado + click),
// pero en horizontal en vez de vertical, y activando otros popups del
// Bridge en vez de ejecutar comandos.
Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    // Controlado por quien instancia este componente (click en el módulo
    // "Config" de la barra, o su atajo de teclado propio -- ver shell.qml)
    property bool open: false
    signal closeRequested()

    property int selectedIndex: 0

    // bridgeKey: nombre de la propiedad de Bridge que abre el popup real
    // (reutiliza Bridge.togglePopup, igual que cada botón individual).
    readonly property var items: [
        { label: "Keybinds", icon: "\uf11c", bridgeKey: "keybindsOpen" },
        { label: "Ajustes", icon: "\uf013", bridgeKey: "barConfigOpen" },
        { label: "Wallpaper", icon: "\uf03e", bridgeKey: "wallpaperPickerOpen" }
    ]

    function activate(index) {
        Bridge.togglePopup(root.items[index].bridgeKey)
        root.closeRequested()
    }

    focus: true
    Keys.onLeftPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
    Keys.onRightPressed: root.selectedIndex = Math.min(root.items.length - 1, root.selectedIndex + 1)
    Keys.onReturnPressed: root.activate(root.selectedIndex)
    Keys.onEscapePressed: root.closeRequested()

    onOpenChanged: {
        if (root.open) {
            root.selectedIndex = 0
            root.forceActiveFocus()
        }
    }

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el dock al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(10)
        spacing: Scaling.px(8)

        Repeater {
            model: root.items
            delegate: Rectangle {
                id: delegateRoot
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Scaling.px(6)
                color: (index === root.selectedIndex || itemArea.containsMouse) ? "#313244" : "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Scaling.px(6)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: delegateRoot.modelData.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Scaling.px(22)
                        color: "#f5e0dc"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: delegateRoot.modelData.label
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(11)
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.selectedIndex = delegateRoot.index
                        root.activate(delegateRoot.index)
                    }
                }
            }
        }
    }
}
