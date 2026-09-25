import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    property string query: ""
    property int selectedIndex: 0
    property var windows: []

    readonly property var filtered: {
        let q = root.query.toLowerCase()
        if (q.length === 0) return root.windows
        return root.windows.filter(w =>
            (w.title || "").toLowerCase().indexOf(q) !== -1 ||
            (w.app || "").toLowerCase().indexOf(q) !== -1)
    }

    function moveSelection(delta) {
        let i = root.selectedIndex + delta
        if (i >= 0 && i < root.filtered.length) root.selectedIndex = i
    }

    function focusSelected() {
        if (root.filtered.length === 0) return
        root.focusWindow(root.filtered[root.selectedIndex])
        root.closeRequested()
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
            // una clase con guiones, y porque nombres cortos como "vlc"
            // no pasan el chequeo de largo mínimo si se comparan contra
            // el id completo en vez del segmento.
            let leaf = id.split(".").pop()
            if (leaf.length > 0 && leaf !== id) out.push(leaf)
        }
        out.push(e.split(" ")[0].split("/").pop().toLowerCase())
        return out
    }

    // Busca en AppList (mismo escaneo de .desktop que usa el launcher)
    // una app cuyo ejecutable coincida con la clase/app-id, y devuelve
    // su Icon= tal cual está declarado -- puede ser un nombre de tema,
    // una ruta absoluta, o "~/..." (varias apps empaquetadas fuera del
    // tema del sistema, como algunos .deb de Chrome o Discord, usan una
    // ruta absoluta acá en vez de un nombre de tema).
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

    // Resuelve la fuente final del ícono a partir del app-id/clase de la
    // ventana -- mismo mecanismo que ActiveWindow.qml: primero los
    // nombres de tema (tal cual y en minúsculas) con iconPath(nombre,
    // true) -- el modo "check", que devuelve "" si no existe en vez de
    // sustituir en silencio un ícono genérico (el modo "fallback" que
    // usaba esta función antes nunca fallaba de verdad -- por eso nunca
    // se notaba que el nombre pedido no existía). Si ninguno existe,
    // cruza contra AppList. Si tampoco, un pixmap suelto por nombre de
    // archivo (esto sí puede fallar de verdad con Image.Error, así que
    // el onStatusChanged del IconImage se encarga si tampoco existe).
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

    function refresh() {
        lister.command = ["hyprctl", "-j", "clients"]
        lister.running = true
    }

    function parseWindows(text) {
        try {
            let arr = JSON.parse(text)
            return arr.filter(w => w.mapped !== false).map(w => ({
                id: w.address,
                title: w.title || w.initialTitle || "(sin título)",
                app: w.class || w.initialClass || "",
                workspace: (w.workspace && w.workspace.name) ? w.workspace.name : ""
            }))
        } catch (e) { return [] }
    }

    // Igual que con el cambio de workspace: Hyprland 0.55 (config Lua)
    // espera una expresión Lua completa, no el "dispatcher arg" viejo. El
    // dispatcher "focus" toma un parámetro "window" cuyo valor es un
    // selector -- mismo formato que usaba la sintaxis vieja de Hyprland
    // ("address:0x...").
    function focusWindow(w) {
        focuser.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + w.id + "\" })"]
        focuser.running = true
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                root.windows = root.parseWindows(text)
                // TEMPORAL: para ver el app-id/clase cruda de cada ventana,
                // tal como la reporta el compositor.
                root.windows.forEach(w => console.log("WindowList: \"" + w.title + "\" -- app crudo:", JSON.stringify(w.app)))
            }
        }
    }
    Process {
        id: focuser
        // Si el enfoque no funciona, esto va a mostrar en la terminal de
        // quickshell la respuesta real de hyprctl -- mismo enfoque de
        // diagnóstico que usamos para el bug de los workspaces.
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (out.length > 0 && out !== "ok") console.log("WindowList: hyprctl dispatch focus, respuesta:", out)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim().length > 0) console.log("WindowList: hyprctl dispatch focus falló:", text) }
        }
    }

    onOpenChanged: {
        if (root.open) {
            root.selectedIndex = 0
            root.query = ""
            root.refresh()
            search.forceActiveFocus()
        }
    }
    onFilteredChanged: {
        if (root.selectedIndex >= root.filtered.length) root.selectedIndex = Math.max(0, root.filtered.length - 1)
    }

    // Absorbe cualquier click dentro del popup para que no se propague al
    // fondo. El fondo en sí ya no cierra la ventana al clickear afuera --
    // se pidió que solo se cierre con Esc o el botón X.
    MouseArea { anchors.fill: parent; onClicked: {} }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(14)
        spacing: Scaling.px(10)

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Listado de Ventanas Abiertas"
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(14)
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                implicitWidth: Scaling.px(22)
                implicitHeight: Scaling.px(22)
                radius: Scaling.px(4)
                color: closeHover.containsMouse ? "#f38ba8" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Scaling.px(11)
                    color: closeHover.containsMouse ? "#1e1e2e" : "#cdd6f4"
                }
                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }
            }
        }

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Filtrar ventanas…"
            text: root.query
            onTextChanged: { root.query = text; root.selectedIndex = 0 }
            Keys.onEscapePressed: root.closeRequested()
            Keys.onReturnPressed: root.focusSelected()
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-1)
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filtered
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: Scaling.px(8)
                minimumSize: 0.12
                background: Rectangle { implicitWidth: Scaling.px(8); radius: width / 2; color: "#313244" }
                contentItem: Rectangle {
                    implicitWidth: Scaling.px(5)
                    radius: width / 2
                    color: "#6c7086"
                    opacity: parent.active ? 0.95 : 0.65
                }
            }

            delegate: Rectangle {
                id: delegateRoot
                required property var modelData
                required property int index
                width: list.width - Scaling.px(14)
                height: Scaling.px(42)
                radius: Scaling.px(6)
                color: (delegateRoot.index === root.selectedIndex || itemArea.containsMouse) ? "#313244" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Scaling.px(8)
                    anchors.rightMargin: Scaling.px(8)
                    spacing: Scaling.px(10)

                    // Ícono de la app (tema de íconos), con una inicial de
                    // respaldo si no se encuentra -- mismo patrón que usa
                    // el launcher.
                    Item {
                        implicitWidth: Scaling.px(24)
                        implicitHeight: Scaling.px(24)

                        Rectangle {
                            anchors.fill: parent
                            radius: Scaling.px(4)
                            color: "#45475a"
                            visible: appIcon.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: (delegateRoot.modelData.app || delegateRoot.modelData.title || "?").charAt(0).toUpperCase()
                                color: "#cdd6f4"
                                font.pixelSize: Scaling.px(12)
                                font.bold: true
                            }
                        }
                        IconImage {
                            id: appIcon
                            anchors.fill: parent
                            asynchronous: true
                            source: root.iconInitialSource(delegateRoot.modelData.app)
                            onStatusChanged: {
                                if (status === Image.Error)
                                    console.log("WindowList: no cargó ningún ícono para app=\"" + delegateRoot.modelData.app + "\"")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: delegateRoot.modelData.title || "(sin título)"
                            color: "#cdd6f4"
                            font.pixelSize: Scaling.px(12)
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: [delegateRoot.modelData.app, delegateRoot.modelData.workspace].filter(s => s && s.length > 0).join("  ·  ")
                            color: "#9399b2"
                            font.pixelSize: Scaling.px(10)
                        }
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.selectedIndex = delegateRoot.index; root.focusSelected() }
                }
            }
        }

        Text {
            visible: root.filtered.length === 0
            text: root.windows.length === 0 ? "Sin ventanas abiertas" : "Sin resultados"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Flechas: moverse · Enter: aplicar · Esc: cerrar"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }
    }
}
