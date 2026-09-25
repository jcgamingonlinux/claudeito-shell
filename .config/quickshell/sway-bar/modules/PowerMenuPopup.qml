import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    // Controlado por quien instancia este componente (dos instancias
    // independientes: botón Power y atajo de teclado)
    property bool open: false
    signal closeRequested()

    property int selectedIndex: 0

    // Códigos de JetBrainsMono Nerd Font (compatibles con Font Awesome,
    // de los más estables entre versiones de Nerd Fonts). Si algún glifo
    // no aparece, confirma con `fc-list | grep -i jetbrains` que el nombre
    // de familia coincide con el usado en font.family más abajo.
    readonly property var items: [
        { label: "Bloquear",      icon: "\uf023", cmd: ["swaylock"], confirm: false },
        { label: "Cerrar sesión", icon: "\uf08b", cmd: ["swaymsg", "exit"], confirm: true },
        { label: "Suspender",     icon: "\uf186", action: "suspend", confirm: false },
        { label: "Reiniciar",     icon: "\uf021", action: "reboot", confirm: true },
        { label: "Apagar",        icon: "\uf011", action: "poweroff", confirm: true }
    ]

    // Suspender/Reiniciar/Apagar no traen un cmd fijo (ver PowerCommands.qml):
    // se resuelve acá, recién al ejecutar, para no depender de que la
    // detección systemctl/loginctl/raw ya haya terminado cuando se arma este
    // array. Bloquear y Cerrar sesión no cambian: ya traen su cmd fijo.
    function cmdFor(item) {
        if (item.action === "suspend") return PowerCommands.suspendCmd()
        if (item.action === "reboot") return PowerCommands.rebootCmd()
        if (item.action === "poweroff") return PowerCommands.poweroffCmd()
        return item.cmd
    }

    Process { id: runner }

    function run(index) {
        let item = root.items[index]
        let cmd = root.cmdFor(item)
        if (item.confirm) {
            // Cerrar sesión/Reiniciar/Apagar pasan por la ventana de
            // confirmación con cuenta regresiva en vez de ejecutarse ya.
            PendingAction.request(item.label, cmd)
        } else {
            runner.command = cmd
            runner.running = true
        }
        root.closeRequested()
    }

    focus: true
    Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
    Keys.onDownPressed: root.selectedIndex = Math.min(root.items.length - 1, root.selectedIndex + 1)
    Keys.onReturnPressed: root.run(root.selectedIndex)
    Keys.onEscapePressed: root.closeRequested()

    onOpenChanged: {
        if (root.open) {
            root.selectedIndex = 0
            root.forceActiveFocus()
        }
    }

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el menú al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(10)
        spacing: Scaling.px(4)

        Repeater {
            model: root.items
            delegate: Rectangle {
                id: delegateRoot
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: Scaling.px(32)
                radius: Scaling.px(6)
                color: (index === root.selectedIndex || itemArea.containsMouse) ? "#313244" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Scaling.px(10)
                    anchors.rightMargin: Scaling.px(10)
                    spacing: Scaling.px(10)

                    Text {
                        text: delegateRoot.modelData.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Scaling.px(14)
                        color: "#f5e0dc"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: delegateRoot.modelData.label
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(12)
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.selectedIndex = delegateRoot.index
                        root.run(delegateRoot.index)
                    }
                }
            }
        }
    }
}
