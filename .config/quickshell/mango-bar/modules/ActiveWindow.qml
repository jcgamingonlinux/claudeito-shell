import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Item {
    // Nombre de la pantalla en la que vive esta instancia (la coloca
    // BarModule.qml). La usa Scaling.pxFor() para escalar según la
    // resolucion de ESTA pantalla en vez de la que tiene el foco.
    property string screenName: ""
    id: root
    implicitWidth: Scaling.pxFor(screenName, 260)
    implicitHeight: contentRow.implicitHeight

    property string title: ""
    property string appId: ""

    function refresh() { getWindow.running = true }

    // Nombres de ícono de TEMA candidatos (nunca rutas) para un app-id/
    // clase de ventana: tal cual, y en minúsculas -- cubre apps cuya
    // clase no coincide en mayúsculas con el nombre del ícono en el
    // tema (ej. Audacity/audacity, Google-chrome/google-chrome).
    function iconNameCandidates(appId) {
        let names = []
        if (!appId || appId.length === 0) return names
        names.push(appId)
        let lower = appId.toLowerCase()
        if (lower !== appId) names.push(lower)
        return names
    }

    // Nombres de ejecutable posibles a partir de una línea Exec= de un
    // .desktop. Contempla Flatpak, donde el primer token de Exec=
    // SIEMPRE es "flatpak" (el ejecutable real está en --command=X, o
    // en el app-id reverse-DNS al final, ej. "com.discordapp.Discord").
    function execMatchCandidates(exec) {
        let e = (exec || "").trim()
        if (e.length === 0) return []
        let out = []
        let cmdMatch = e.match(/--command=(\S+)/)
        if (cmdMatch) out.push(cmdMatch[1].split("/").pop().toLowerCase())
        let idMatch = e.match(/\b[a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_-]+){2,}\b/)
        if (idMatch) {
            let id = idMatch[0].toLowerCase()
            out.push(id)
            let leaf = id.split(".").pop()
            if (leaf.length > 0 && leaf !== id) out.push(leaf)
        }
        out.push(e.split(" ")[0].split("/").pop().toLowerCase())
        return out
    }

    function appListIconValue(appId) {
        if (!appId || appId.length === 0) return ""
        let lower = appId.toLowerCase()
        let match = AppList.apps.find(a => {
            let candidates = root.execMatchCandidates(a.exec)
            return candidates.some(exe => exe.length > 0 && (exe === lower
                || (lower.length >= 4 && exe.indexOf(lower) !== -1)
                || (exe.length >= 4 && lower.indexOf(exe) !== -1)))
        })
        return (match && match.icon) ? match.icon : ""
    }

    function resolveIconValue(icon) {
        if (!icon || icon.length === 0) return ""
        let resolved = icon
        if (resolved === "~" || resolved.startsWith("~/")) {
            let home = Quickshell.env("HOME") || ""
            resolved = home + resolved.slice(1)
        }
        if (resolved.startsWith("/")) return "file://" + resolved
        return Quickshell.iconPath(resolved, true)
    }

    function iconInitialSource(appId) {
        let names = root.iconNameCandidates(appId)
        for (let i = 0; i < names.length; i++) {
            let resolved = Quickshell.iconPath(names[i], true)
            if (resolved.length > 0) return resolved
        }
        let fromAppList = root.resolveIconValue(root.appListIconValue(appId))
        if (fromAppList.length > 0) return fromAppList
        if (appId && appId.length > 0) return "file:///usr/share/pixmaps/" + appId + ".png"
        return ""
    }

    // Aplica el JSON que devuelve mmsg (tanto "get focusing-client" como
    // cada línea de "watch focusing-client" -- misma forma).
    //
    // OJO: la wiki de mango documenta el COMANDO ("get focusing-client")
    // pero no el esquema exacto del JSON de respuesta. "title" es un
    // nombre casi seguro (lo usan hyprland/sway/niri igual); "appid" es
    // la convención estándar de xdg-toplevel/app_id en Wayland, pero acá
    // se prueban varias variantes por si acaso. Con una ventana enfocada,
    // mirá la consola de quickshell -- el console.log de abajo muestra el
    // JSON crudo apenas algo no matchea, para confirmar/ajustar el nombre
    // de campo real.
    function applyClient(text) {
        try {
            let w = JSON.parse(text)
            if (!w || Object.keys(w).length === 0) {
                root.title = ""; root.appId = ""
                return
            }
            root.title = w.title || ""
            // Reordenado tras confirmar en pruebas reales que mango usa
            // snake_case en sus JSON (client_count, is_active, is_urgent
            // en /all-tags) -- se prueba app_id primero por eso, aunque
            // esta parte puntual (focusing-client) todavía no se probó.
            root.appId = w.app_id || w.appid || w.appId || w.class || w.wm_class || ""
            if (root.title.length > 0 && root.appId.length === 0)
                console.log("ActiveWindow (mango): no reconocí el campo de app-id, JSON crudo:", text)
        } catch (e) { root.title = ""; root.appId = "" }
    }

    Process {
        id: getWindow
        command: ["mmsg", "get", "focusing-client"]
        stdout: StdioCollector {
            onStreamFinished: root.applyClient(text)
        }
    }

    // "mmsg watch focusing-client" empuja un JSON nuevo cada vez que
    // cambia el cliente enfocado -- a diferencia del socket crudo de
    // Hyprland (que dispara varios eventos sueltos por acción y
    // necesitaba debounce), esta suscripción ya viene filtrada a "solo
    // esto", así que se aplica cada línea directo, sin timer de por
    // medio ni depender de socat.
    Process {
        id: subscriber
        command: ["mmsg", "watch", "focusing-client"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.applyClient(line)
        }
    }

    // Sondeo de respaldo, por si el proceso de watch se cae o mango
    // todavía no levantó el socket cuando arrancó quickshell.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Scaling.pxFor(screenName, 6)

        Item {
            id: iconBox
            visible: root.title.length > 0
            implicitWidth: visible ? Scaling.pxFor(screenName, 16) : 0
            implicitHeight: Scaling.pxFor(screenName, 16)

            Rectangle {
                anchors.fill: parent
                radius: Scaling.pxFor(screenName, 3)
                color: "#45475a"
                visible: appIcon.status !== Image.Ready
                Text {
                    anchors.centerIn: parent
                    text: (root.appId || root.title || "?").charAt(0).toUpperCase()
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.pxFor(screenName, 9)
                    font.bold: true
                }
            }
            IconImage {
                id: appIcon
                anchors.fill: parent
                asynchronous: true
                source: root.iconInitialSource(root.appId)
                onStatusChanged: {
                    if (status === Image.Error)
                        console.log("ActiveWindow: no cargó ningún ícono para app=\"" + root.appId + "\"")
                }
            }
        }

        Text {
            id: label
            width: Math.min(implicitWidth, root.width - iconBox.width - (iconBox.visible ? contentRow.spacing : 0))
            text: root.title
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: "#cdd6f4"
            font.pixelSize: Scaling.pxFor(screenName, 12)
        }
    }
}
