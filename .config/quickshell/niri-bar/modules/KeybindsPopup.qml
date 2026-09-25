import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Lee ~/.config/niri/config.kdl y extrae el bloque "binds { ... }".
//
// Modo curado (preferido): si dentro del bloque hay comentarios
// "// @category ..." y "// @title ..." (ver README), SOLO se muestran los
// binds anotados con "@title", agrupados por el "@category" más reciente.
//
// Modo automático (respaldo): si no se encuentra ninguna anotación
// "@title", se listan TODOS los binds tal cual, agrupados por los
// comentarios "//" normales que los preceden.
Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    // Configurable por si tu config.kdl vive en otro lado (XDG_CONFIG_HOME, etc.)
    property string configPath: "$HOME/.config/niri/config.kdl"

    property var entries: []
    property string query: ""
    property string loadError: ""
    property var includeNotes: []
    property bool curated: false

    FontMetrics {
        id: comboMetrics
        font.pixelSize: Scaling.px(12)
        font.family: "monospace"
    }

    FontMetrics {
        id: descriptionMetrics
        font.pixelSize: Scaling.px(13)
    }

    // Conserva el ancho real de cada combinación y descripción para que la
    // lista pueda desplazarse horizontalmente solo si hace falta.
    function shortcutsContentWidth(viewWidth) {
        let widest = 0
        root.grouped.forEach(item => {
            if (item.isHeader) {
                widest = Math.max(widest, descriptionMetrics.advanceWidth(item.text || ""))
            } else {
                let combo = comboMetrics.advanceWidth(item.combo || "") + Scaling.px(14)
                let description = descriptionMetrics.advanceWidth(item.desc || "")
                widest = Math.max(widest, combo + Scaling.px(10) + description + Scaling.px(8))
            }
        })
        return Math.max(viewWidth, Math.ceil(widest))
    }

    function scan() {
        root.entries = []
        root.loadError = ""
        root.includeNotes = []
        reader.buffer = []
        reader.command = ["sh", "-c", "cat \"" + root.configPath.replace(/"/g, "\\\"") + "\" 2>/dev/null"]
        reader.running = true
    }

    Process {
        id: reader
        property var buffer: []
        stdout: SplitParser {
            onRead: (line) => { reader.buffer.push(line) }
        }
        onRunningChanged: {
            if (!running) {
                let text = reader.buffer.join("\n")
                if (text.trim().length === 0) {
                    root.loadError = "No se pudo leer " + root.configPath
                    return
                }
                let result = root.parseNiri(text)
                root.entries = result.entries
                root.curated = result.curated
                if (root.entries.length === 0) {
                    root.loadError = "No se encontró un bloque \"binds { }\" en el archivo"
                }
            }
        }
    }

    // --- humanización de la acción de un bind ---
    function humanizeAction(action) {
        let a = action.trim().replace(/;\s*$/, "").trim()
        if (a.length === 0) return "(vacío)"

        let spawnMatch = a.match(/^spawn(?:-sh)?\s+(.+)$/)
        if (spawnMatch) {
            let raw = spawnMatch[1]
            let tokens = raw.match(/"([^"]*)"|(\S+)/g) || []
            let clean = tokens.map(t => t.replace(/^"|"$/g, ""))
            return "Ejecutar: " + clean.join(" ")
        }

        let first = a.split(/\s+/)[0].replace(/^"|"$/g, "")
        let words = first.replace(/-/g, " ")
        return words.charAt(0).toUpperCase() + words.slice(1)
    }

    function niceCombo(combo) {
        return combo.replace(/Mod/g, "Super")
    }

    // --- extrae el contenido del bloque "binds { ... }" de nivel superior ---
    function extractBindsBody(text) {
        let lines = text.split("\n")
        let inBinds = false
        let depth = 0
        let body = []
        for (let i = 0; i < lines.length; i++) {
            let raw = lines[i]
            if (!inBinds) {
                if (/^\s*binds\s*\{/.test(raw)) {
                    inBinds = true
                    depth = 1
                    let after = raw.slice(raw.indexOf("{") + 1)
                    if (after.trim().length > 0) body.push(after)
                }
                continue
            }
            let opens = (raw.match(/\{/g) || []).length
            let closes = (raw.match(/\}/g) || []).length
            if (depth + opens - closes <= 0) {
                let idx = raw.lastIndexOf("}")
                let keep = raw.slice(0, idx)
                if (keep.trim().length > 0) body.push(keep)
                break
            }
            depth += opens - closes
            body.push(raw)
        }
        return body
    }

    // --- separa el cuerpo en entradas individuales (clave { acción; }) ---
    function parseNiri(text) {
        let body = root.extractBindsBody(text)

        // Modo curado: solo entra un bind si lo precede "// @title ..."
        // (con la categoría del "// @category ..." más reciente).
        let annotated = []
        let annCategory = ""
        let annTitle = null

        // Modo automático (respaldo): todos los binds, agrupados por
        // comentarios "//" normales, tal como antes.
        let fallback = []
        let fbCategory = ""

        let buffer = ""
        let braceDepth = 0

        for (let i = 0; i < body.length; i++) {
            let line = body[i]
            if (braceDepth === 0) {
                let trimmed = line.trim()
                if (trimmed.length === 0) continue

                if (trimmed.startsWith("//")) {
                    let catMatch = trimmed.match(/^\/\/\s*@category\s+(.+)$/)
                    if (catMatch) {
                        annCategory = catMatch[1].trim()
                        annTitle = null
                        continue
                    }
                    let titleMatch = trimmed.match(/^\/\/\s*@title\s+(.+)$/)
                    if (titleMatch) {
                        annTitle = titleMatch[1].trim()
                        continue
                    }
                    let t = trimmed.replace(/^\/\/\s?/, "")
                    fbCategory = fbCategory ? fbCategory + " " + t : t
                    continue
                }
                buffer = line
            } else {
                buffer += "\n" + line
            }
            let opens = (line.match(/\{/g) || []).length
            let closes = (line.match(/\}/g) || []).length
            braceDepth += opens - closes
            if (braceDepth <= 0 && buffer.trim().length > 0) {
                let e = root.parseNiriEntry(buffer, fbCategory)
                if (e) {
                    fallback.push(e)
                    if (annTitle !== null) {
                        annotated.push({ combo: e.combo, desc: annTitle, category: annCategory })
                        annTitle = null
                    }
                }
                fbCategory = ""
                buffer = ""
                braceDepth = 0
            }
        }

        let useCurated = annotated.length > 0
        return {
            entries: useCurated ? annotated : fallback,
            curated: useCurated
        }
    }

    function parseNiriEntry(chunk, category) {
        let m = chunk.match(/^\s*([A-Za-z0-9_+.]+)\s+(?:[a-zA-Z-]+\s*=\s*"[^"]*"\s*)*(?:hotkey-overlay-title\s*=\s*"([^"]*)"\s*)?(?:[a-zA-Z-]+\s*=\s*"[^"]*"\s*)*\{([\s\S]*)\}\s*$/)
        if (!m) {
            // variante sin atributos, la más común
            m = chunk.match(/^\s*([A-Za-z0-9_+.]+)\s*\{([\s\S]*)\}\s*$/)
            if (!m) return null
            let combo = m[1]
            let action = m[2].trim()
            return { combo: root.niceCombo(combo), desc: root.humanizeAction(action), category: category }
        }
        let combo = m[1]
        let title = m[2]
        let action = m[3].trim()
        let desc = (title && title.length > 0) ? title : root.humanizeAction(action)
        return { combo: root.niceCombo(combo), desc: desc, category: category }
    }

    onOpenChanged: {
        if (root.open) {
            root.scan()
            search.forceActiveFocus()
        } else {
            root.query = ""
        }
    }

    readonly property var grouped: {
        let q = root.query.trim().toLowerCase()
        let filtered = root.entries.filter(e => {
            if (q.length === 0) return true
            return (e.combo + " " + e.desc + " " + e.category).toLowerCase().indexOf(q) !== -1
        })
        let byCategory = {}
        let order = []
        filtered.forEach(e => {
            let fallbackLabel = root.curated ? "Sin categoría" : "Otros atajos"
            let cat = (e.category && e.category.length > 0) ? e.category : fallbackLabel
            if (!byCategory[cat]) { byCategory[cat] = []; order.push(cat) }
            byCategory[cat].push(e)
        })
        let items = []
        order.forEach(cat => {
            items.push({ isHeader: true, text: cat })
            byCategory[cat].forEach(e => items.push(e))
        })
        return items
    }

    // Absorbe clicks internos para que no se propaguen al fondo (que cierra el popup)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(14)
        spacing: Scaling.px(10)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Atajos de teclado (niri)"
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(14)
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                implicitWidth: Scaling.px(22)
                implicitHeight: Scaling.px(22)
                radius: Scaling.px(4)
                color: closeHoverKeybinds.containsMouse ? "#f38ba8" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Scaling.px(11)
                    color: closeHoverKeybinds.containsMouse ? "#1e1e2e" : "#cdd6f4"
                }
                MouseArea {
                    id: closeHoverKeybinds
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }
            }
        }

        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Buscar atajo…"
            text: root.query
            onTextChanged: root.query = text
            Keys.onEscapePressed: root.closeRequested()
        }

        Text {
            visible: root.loadError.length > 0
            text: root.loadError
            color: "#f38ba8"
            font.pixelSize: Scaling.px(12)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Text {
            visible: root.loadError.length === 0 && root.entries.length > 0
            text: root.curated
                ? "Mostrando solo los atajos documentados con \"@title\""
                : "Sin anotaciones \"@title\" — mostrando todos los binds detectados"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
            font.italic: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ListView {
            id: shortcutList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Scaling.px(2)
            model: root.grouped
            contentWidth: root.shortcutsContentWidth(width)

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                width: shortcutList.contentWidth
                height: delegateRoot.modelData.isHeader ? 30 : 38

                Text {
                    visible: delegateRoot.modelData.isHeader === true
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: delegateRoot.modelData.text
                    color: "#89b4fa"
                    font.bold: true
                    font.pixelSize: Scaling.px(12)
                }

                RowLayout {
                    visible: delegateRoot.modelData.isHeader !== true
                    anchors.fill: parent
                    anchors.leftMargin: Scaling.px(4)
                    anchors.rightMargin: Scaling.px(4)
                    spacing: Scaling.px(10)

                    Rectangle {
                        Layout.preferredWidth: comboText.implicitWidth + 14
                        Layout.preferredHeight: Scaling.px(22)
                        radius: Scaling.px(5)
                        color: "#313244"

                        Text {
                            id: comboText
                            anchors.centerIn: parent
                            text: delegateRoot.modelData.combo || ""
                            color: "#cdd6f4"
                            font.pixelSize: Scaling.px(12)
                            font.family: "monospace"
                        }
                    }

                    Text {
                        id: descriptionText
                        Layout.fillWidth: true
                        Layout.preferredWidth: descriptionMetrics.advanceWidth(text)
                        text: delegateRoot.modelData.desc || ""
                        color: "#bac2de"
                        font.pixelSize: Scaling.px(13)
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }

        Text {
            visible: root.entries.length === 0 && root.loadError.length === 0
            text: "Leyendo " + root.configPath + "…"
            color: "#9399b2"
            font.pixelSize: Scaling.px(12)
        }
    }
}
