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

    function refresh() { getTree.running = true }

    function findFocused(node) {
        if (!node) return null
        // node.pid solo existe en ventanas reales; los contenedores de
        // workspace/output (que sway también puede marcar "focused" cuando
        // el workspace está vacío) no lo tienen — así evitamos mostrar el
        // número del workspace como si fuera un título de ventana.
        if (node.focused && node.pid) return node
        let children = (node.nodes || []).concat(node.floating_nodes || [])
        for (let i = 0; i < children.length; i++) {
            let found = findFocused(children[i])
            if (found) return found
        }
        return null
    }

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
    // en el app-id reverse-DNS al final, ej. "com.discordapp.Discord")
    // -- si no se contempla este caso, ninguna app instalada por
    // Flatpak cruza nunca con AppList, porque "flatpak" no se parece en
    // nada a la clase de la ventana.
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
            // El último segmento de un app-id reverse-DNS suele ser el
            // nombre "corto" real de la app (org.videolan.VLC -> vlc,
            // com.google.Chrome -> chrome) -- separado porque el id
            // completo tiene puntos y no coincide como substring contra
            // una clase con guiones (google-chrome no contiene
            // "com.google.chrome"), y porque nombres cortos como "vlc"
            // (3 letras) no pasan el chequeo de largo mínimo más abajo
            // si se compara contra el id completo en vez del segmento.
            let leaf = id.split(".").pop()
            if (leaf.length > 0 && leaf !== id) out.push(leaf)
        }
        out.push(e.split(" ")[0].split("/").pop().toLowerCase())
        return out
    }

    // Busca en AppList (mismo escaneo de .desktop que usa el launcher)
    // una app cuyo ejecutable coincida con la clase/app-id, y devuelve
    // su Icon= tal cual está declarado -- puede ser un nombre de tema,
    // una ruta absoluta, o "~/..." (las tres formas válidas según la
    // spec de .desktop files; varias apps empaquetadas fuera del tema
    // del sistema, como algunos .deb de Chrome o Discord, usan una ruta
    // absoluta acá en vez de un nombre de tema).
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

    // Resuelve un valor de Icon= a una fuente usable -- mismo criterio
    // que LauncherPopup.iconSource(): nombre de tema, ruta absoluta, o
    // "~/...". Si se lo pasa directo a iconPath() sin este chequeo, una
    // ruta absoluta se trata (mal) como si fuera un nombre de tema y la
    // búsqueda nunca encuentra nada.
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

    // Resuelve la fuente final del ícono: primero los nombres de tema
    // (tal cual y en minúsculas) con iconPath(nombre, true) -- el modo
    // "check", que devuelve "" si no existe en vez de sustituir en
    // silencio un ícono genérico. Si ninguno existe, cruza contra
    // AppList. Si tampoco, un pixmap suelto por nombre de archivo (esto
    // sí puede fallar de verdad con Image.Error, así que el
    // onStatusChanged del IconImage se encarga si tampoco existe).
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

    Process {
        id: getTree
        command: ["swaymsg", "-t", "get_tree", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let tree = JSON.parse(text)
                    let focused = root.findFocused(tree)
                    root.title = (focused && focused.name) ? focused.name : ""
                    // XWayland reporta el app-id en window_properties.class
                    // en vez de app_id -- mismo fallback que WindowListPopup.qml
                    root.appId = focused ? (focused.app_id || (focused.window_properties && focused.window_properties.class) || "") : ""
                } catch (e) { console.log("ActiveWindow: error parseando árbol", e) }
            }
        }
    }

    // Se refresca ante eventos de ventana o de workspace (cambia el foco)
    Process {
        id: subscriber
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"window\",\"workspace\"]"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    Component.onCompleted: root.refresh()

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Scaling.pxFor(screenName, 6)

        // Ícono de la app (tema de íconos), con una inicial de respaldo
        // si no se encuentra -- mismo patrón que WindowListPopup.qml, para
        // que se vea igual que en el listado de ventanas y el launcher.
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
                // Si AppList todavía no terminó de escanear al momento
                // de resolver esto (recién arrancado quickshell), el
                // cruce por .desktop puede no estar disponible todavía
                // -- se corrige solo en el próximo cambio de ventana
                // enfocada.
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
