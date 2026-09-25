pragma Singleton
import QtQuick
import Quickshell.Io

// Cuenta cuántas veces se lanzó cada app desde el launcher, persistido en
// disco (~/.local/share/quickshell-launcher-usage.tsv) para que sobreviva
// a reinicios y sea compartido por los dos launchers (botón + atajo).
QtObject {
    id: root

    // { "Firefox": 5, "Discord": 2, ... }
    property var counts: ({})

    readonly property string readScript: `cat "$HOME/.local/share/quickshell-launcher-usage.tsv" 2>/dev/null`

    function load() { reader.running = true }

    function save() {
        let lines = []
        for (let name in root.counts) {
            lines.push(root.counts[name] + "\t" + name)
        }
        let content = lines.join("\n")
        // Se codifica en base64 para evitar por completo cualquier problema
        // de comillas/caracteres especiales al pasar el contenido al shell.
        let b64 = Qt.btoa(content)
        writer.command = ["sh", "-c",
            "mkdir -p \"$HOME/.local/share\" && printf '%s' '" + b64 + "' | base64 -d > \"$HOME/.local/share/quickshell-launcher-usage.tsv\""]
        writer.running = true
    }

    function recordLaunch(name) {
        if (!name) return
        let c = root.counts
        c[name] = (c[name] || 0) + 1
        root.counts = c
        root.save()
    }

    function getCount(name) {
        return root.counts[name] || 0
    }

    // Ranking de "más usadas", fijado UNA sola vez por sesión (cuando ya
    // están listos tanto el conteo de uso como el primer escaneo de
    // AppList) para que aparezca de inmediato y no se reordene ni
    // parpadee cada vez que se abre o refresca el launcher. Se guardan los
    // objetos app completos (nombre/exec/ícono) tal cual estaban en ese
    // momento -- si alguna se desinstala después durante la misma sesión,
    // sigue apareciendo igual (el usuario pidió que no dependa de eso).
    // null = todavía no se calculó esta sesión.
    property var pinnedTopApps: null
    // true recién cuando termina de leerse el archivo de conteos desde
    // disco -- evita fijar el ranking con counts todavía vacío por una
    // carrera de arranque (AppList podría terminar su primer escaneo
    // antes de que esto termine de cargar).
    property bool loaded: false

    function pinTop(apps) {
        if (root.pinnedTopApps !== null) return
        if (!root.loaded || !apps || apps.length === 0) return
        let withCounts = apps.map(a => ({ app: a, count: root.getCount(a.name) }))
        let used = withCounts.filter(x => x.count > 0)
        used.sort((a, b) => b.count - a.count || a.app.name.localeCompare(b.app.name))
        root.pinnedTopApps = used.slice(0, 8).map(x => x.app)
    }

    property Process reader: Process {
        command: ["sh", "-c", root.readScript]
        stdout: StdioCollector {
            onStreamFinished: {
                let map = {}
                let lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i]
                    if (line.trim().length === 0) continue
                    let parts = line.split("\t")
                    if (parts.length < 2) continue
                    let n = parseInt(parts[0])
                    let name = parts.slice(1).join("\t")
                    if (!isNaN(n) && name.length > 0) map[name] = n
                }
                root.counts = map
                root.loaded = true
                // Por si el escaneo de AppList (que corre en paralelo)
                // terminó primero: reintentar acá con los datos ya
                // completos. pinTop() no hace nada si ya se fijó antes.
                root.pinTop(AppList.apps)
            }
        }
    }

    property Process writer: Process { }

    Component.onCompleted: root.load()
}
