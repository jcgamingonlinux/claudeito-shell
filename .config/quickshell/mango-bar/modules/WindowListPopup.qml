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

    function iconNameCandidates(appId) {
        let names = []
        if (!appId || appId.length === 0) return names
        names.push(appId)
        let lower = appId.toLowerCase()
        if (lower !== appId) names.push(lower)
        return names
    }

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

    function refresh() {
        lister.command = ["mmsg", "get", "all-clients"]
        lister.running = true
    }

    // Esquema corregido: igual que "get/watch all-tags" (confirmado en
    // pruebas reales), "get all-clients" también viene envuelto en un
    // objeto con la clave del propio comando: {"all_clients": [...]}, no
    // un array directo -- este era el motivo por el que no aparecía
    // ninguna ventana (el array salía vacío en silencio). "id" sigue
    // siendo casi seguro (todos los dispatchers que targetean un cliente
    // usan "client,<id>"); title/app_id se prueban con varias variantes.
    // Si sigue sin verse algo, el console.log de abajo tira el JSON crudo
    // completo la primera vez que se llama.
    property bool _loggedSample: false
    function parseWindows(text) {
        try {
            let data = JSON.parse(text)
            let arr = Array.isArray(data) ? data
                : (Array.isArray(data.all_clients) ? data.all_clients
                : (Array.isArray(data.clients) ? data.clients : null))

            if (!Array.isArray(arr)) {
                console.log("WindowList (mango): no encontré un array de clientes, JSON crudo:", text)
                return []
            }
            if (!root._loggedSample && arr.length > 0) {
                console.log("WindowList (mango): ejemplo de cliente crudo:", JSON.stringify(arr[0]))
                root._loggedSample = true
            }
            return arr.filter(w => w.mapped !== false && w.minimized !== true).map(w => ({
                id: w.id !== undefined ? w.id : w.address,
                title: w.title || "(sin título)",
                // snake_case primero: confirmado que mango lo usa en
                // /all-tags (client_count, is_active); todavía sin probar
                // puntualmente en /all-clients.
                app: w.app_id || w.appid || w.class || w.wm_class || "",
                workspace: w.tags !== undefined ? ("Tag " + w.tags) : (w.tag !== undefined ? ("Tag " + w.tag) : "")
            }))
        } catch (e) { console.log("WindowList (mango): error parseando all-clients, JSON crudo:", text); return [] }
    }

    // Documentado: "focusid" enfoca cualquier cliente por id vía IPC --
    // "mmsg dispatch focusid client,<id>".
    function focusWindow(w) {
        focuser.command = ["mmsg", "dispatch", "focusid", "client," + w.id]
        focuser.running = true
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                root.windows = root.parseWindows(text)
            }
        }
    }
    Process {
        id: focuser
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (out.length > 0) console.log("WindowList: mmsg dispatch focusid, respuesta:", out)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim().length > 0) console.log("WindowList: mmsg dispatch focusid falló:", text) }
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
