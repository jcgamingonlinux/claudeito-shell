pragma Singleton
import QtQuick
import Quickshell.Io

// Estado compartido para acciones "peligrosas" (cerrar sesión, reiniciar,
// apagar) que deben pasar por una confirmación con cuenta regresiva antes
// de ejecutarse. Se usa desde el launcher (botones de abajo) y desde los
// dos power menus, así que vive en un singleton en vez de duplicarse.
QtObject {
    id: root

    property bool open: false
    property string label: ""
    property var command: []

    function request(label, command) {
        root.label = label
        root.command = command
        root.open = true
    }

    function cancel() {
        root.open = false
    }

    function executeNow() {
        runner.command = root.command
        runner.running = true
        root.open = false
    }

    property Process runner: Process { }
}
