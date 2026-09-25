pragma Singleton
import QtQuick
import Quickshell.Io

// Preferencias de la barra. Se guardan en ~/.config/quickshell/bar-layout.tsv
// para que se conserven aunque se reinicie quickshell.
QtObject {
    id: root
    property bool barAtBottom: false
    property int scalePercent: 100
    // Auto-ocultar: la barra se repliega tras un momento sin actividad
    // (mouse fuera y sin popups abiertos) y reaparece al acercar el mouse
    // al borde de la pantalla donde vive la barra.
    property bool autoHide: false
    property var modules: [
        { id: "config", enabled: true, zone: "left" },
        { id: "menu", enabled: true, zone: "left" },
        { id: "workspaces", enabled: true, zone: "left" },
        { id: "activeWindow", enabled: true, zone: "center" },
        { id: "configDock", enabled: true, zone: "center" },
        { id: "cpu", enabled: true, zone: "right" },
        { id: "ram", enabled: true, zone: "right" },
        { id: "temp", enabled: true, zone: "right" },
        { id: "volume", enabled: true, zone: "right" },
        { id: "network", enabled: true, zone: "right" },
        { id: "systray", enabled: true, zone: "right" },
        { id: "notifications", enabled: true, zone: "right" },
        { id: "keybinds", enabled: true, zone: "right" },
        { id: "battery", enabled: true, zone: "right" },
        { id: "bluetooth", enabled: true, zone: "right" },
        { id: "windowlist", enabled: true, zone: "right" },
        { id: "clock", enabled: true, zone: "right" },
        { id: "power", enabled: true, zone: "right" }
    ]

    function modulesFor(zone) {
        return modules.filter(function(module) { return module.enabled && module.zone === zone })
    }

    function update(index, changes) {
        let copy = modules.slice()
        copy[index] = Object.assign({}, copy[index], changes)
        modules = copy
        save()
    }

    function move(index, direction) {
        let target = index + direction
        // El orden visible es independiente en cada zona. Saltar elementos
        // de las otras zonas evita que una flecha parezca no hacer nada.
        while (target >= 0 && target < modules.length && modules[target].zone !== modules[index].zone)
            target += direction
        if (target < 0 || target >= modules.length) return
        let copy = modules.slice()
        let item = copy.splice(index, 1)[0]
        copy.splice(target, 0, item)
        modules = copy
        save()
    }

    function reset() {
        barAtBottom = false
        scalePercent = 100
        autoHide = false
        modules = defaultModules()
        save()
    }

    function defaultModules() { return [
        { id: "config", enabled: true, zone: "left" },
        { id: "menu", enabled: true, zone: "left" }, { id: "workspaces", enabled: true, zone: "left" },
        { id: "activeWindow", enabled: true, zone: "center" }, { id: "configDock", enabled: true, zone: "center" },
        { id: "cpu", enabled: true, zone: "right" }, { id: "ram", enabled: true, zone: "right" },
        { id: "temp", enabled: true, zone: "right" }, { id: "volume", enabled: true, zone: "right" },
        { id: "network", enabled: true, zone: "right" }, { id: "systray", enabled: true, zone: "right" },
        { id: "notifications", enabled: true, zone: "right" }, { id: "keybinds", enabled: true, zone: "right" },
        { id: "battery", enabled: true, zone: "right" }, { id: "bluetooth", enabled: true, zone: "right" }, { id: "windowlist", enabled: true, zone: "right" }, { id: "clock", enabled: true, zone: "right" },
        { id: "power", enabled: true, zone: "right" }
    ] }

    function save() {
        // Línea 3 (índice 2) es "0"/"1" para autoHide. Para no romper
        // archivos bar-layout.tsv guardados por versiones previas (que no
        // tenían esta línea), el lector detecta el formato viejo mirando si
        // esa línea trae tabs (formato de módulo) o no (formato autoHide).
        let lines = [barAtBottom ? "bottom" : "top", scalePercent.toString(), autoHide ? "1" : "0"]
        for (let i = 0; i < modules.length; ++i) {
            let item = modules[i]
            lines.push(item.id + "\t" + item.zone + "\t" + (item.enabled ? "1" : "0"))
        }
        let b64 = Qt.btoa(lines.join("\n"))
        writer.command = ["sh", "-c", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + b64 + "' | base64 -d > \"$HOME/.config/quickshell/bar-layout.tsv\""]
        writer.running = true
    }

    property Process reader: Process {
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/bar-layout.tsv\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                if (lines.length < 2) return
                root.barAtBottom = lines[0] === "bottom"
                let percent = parseInt(lines[1])
                if (!isNaN(percent)) root.scalePercent = Math.max(70, Math.min(160, percent))

                let moduleStart = 2
                if (lines.length > 2 && lines[2].indexOf("\t") === -1) {
                    root.autoHide = lines[2] === "1"
                    moduleStart = 3
                } else {
                    root.autoHide = false
                }

                let restored = []
                for (let i = moduleStart; i < lines.length; ++i) {
                    let part = lines[i].split("\t")
                    if (part.length === 3) restored.push({ id: part[0], zone: part[1], enabled: part[2] === "1" })
                }
                // Si el archivo viejo no tenía el módulo "config" (versiones
                // previas a esta), lo agregamos al principio de la zona
                // izquierda para no perder el acceso a Ajustes.
                if (restored.length > 0) {
                    if (!restored.some(function(m) { return m.id === "config" }))
                        restored.unshift({ id: "config", enabled: true, zone: "left" })
                    if (!restored.some(function(m) { return m.id === "configDock" }))
                        restored.push({ id: "configDock", enabled: true, zone: "center" })
                    root.modules = restored
                }
            }
        }
    }
    property Process writer: Process { }
    Component.onCompleted: reader.running = true
}
