import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Lee ~/.config/sway/config y extrae cada línea "bindsym".
//
// Modo curado (preferido): si el archivo tiene comentarios
// "# @category ..." y "# @title ..." (ver README), SOLO se muestran los
// binds anotados con "@title", agrupados por el "@category" más reciente.
//
// Modo automático (respaldo): si no se encuentra ninguna anotación
// "@title" en todo el archivo, se listan TODOS los "bindsym" tal cual,
// agrupados por los comentarios "#" normales que los preceden.
Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    // Configurable por si tu config vive en otro lado (XDG_CONFIG_HOME, etc.)
    property string configPath: "$HOME/.config/sway/config"

    property var entries: []
    property string query: ""
    property string loadError: ""
    property var includePaths: []
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
        root.includePaths = []
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
                let result = root.parseSway(text)
                root.entries = result.entries
                root.includePaths = result.includes
                root.curated = result.curated
                if (root.entries.length === 0) {
                    root.loadError = "No se encontraron líneas \"bindsym\" en el archivo"
                }
            }
        }
    }

    function humanizeAction(action) {
        let a = action.trim()
        let execMatch = a.match(/^exec(?:_always)?\s+(?:--no-startup-id\s+)?(.+)$/)
        if (execMatch) return "Ejecutar: " + execMatch[1].trim()
        return a.length > 48 ? a.slice(0, 48) + "…" : a
    }

    function substituteVars(str, vars) {
        // Reemplaza $var de mayor a menor longitud para evitar que "$mod"
        // pise a "$mod2" a medias
        let keys = Object.keys(vars).sort((a, b) => b.length - a.length)
        let out = str
        keys.forEach(k => { out = out.split(k).join(vars[k]) })
        return out
    }

    function niceCombo(combo) {
        // "Mod4" (el nombre real de la tecla Super en Linux) es menos
        // reconocible que "Super" — y así queda igual que en la versión
        // de niri, que ya muestra "Super" en vez de "Mod"
        return combo.replace(/\bMod4\b/g, "Super")
    }

    function parseSway(text) {
        let lines = text.split("\n")
        let vars = {}
        let includes = []

        // Modo curado: solo entra un bind si lo precede "# @title ..."
        // (con la categoría del "# @category ..." más reciente).
        let annotated = []
        let annCategory = ""
        let annTitle = null

        // Modo automático (respaldo): todos los binds, agrupados por
        // comentarios "#" normales, tal como antes.
        let fallback = []
        let fbCategory = ""

        for (let i = 0; i < lines.length; i++) {
            let trimmed = lines[i].trim()
            if (trimmed.length === 0) continue

            let catMatch = trimmed.match(/^#\s*@category\s+(.+)$/)
            if (catMatch) {
                annCategory = catMatch[1].trim()
                annTitle = null
                continue
            }

            let titleMatch = trimmed.match(/^#\s*@title\s+(.+)$/)
            if (titleMatch) {
                annTitle = titleMatch[1].trim()
                continue
            }

            if (trimmed.startsWith("#")) {
                let t = trimmed.replace(/^#\s?/, "")
                fbCategory = fbCategory ? fbCategory + " " + t : t
                continue
            }

            let setMatch = trimmed.match(/^set\s+(\$\S+)\s+(.+)$/)
            if (setMatch) {
                vars[setMatch[1]] = setMatch[2].trim()
                continue
            }

            let includeMatch = trimmed.match(/^include\s+(.+)$/)
            if (includeMatch) {
                includes.push(includeMatch[1].trim())
                fbCategory = ""
                continue
            }

            let bindMatch = trimmed.match(/^bindsym\s+(?:--\S+\s+)*(\S+)\s+(.+)$/)
            if (bindMatch) {
                let combo = root.niceCombo(root.substituteVars(bindMatch[1], vars))
                let action = bindMatch[2].trim()

                if (annTitle !== null) {
                    annotated.push({ combo: combo, desc: annTitle, category: annCategory })
                    annTitle = null
                }

                fallback.push({ combo: combo, desc: root.humanizeAction(action), category: fbCategory })
                fbCategory = ""
                continue
            }

            // cualquier otra línea "consume" la categoría del modo
            // automático, para que no se le pegue a un bind que no le
            // corresponde (la anotación @title/@category no se resetea
            // acá: solo se consume al usarse en un bindsym, o se
            // reemplaza por la siguiente @title/@category)
            fbCategory = ""
        }

        let useCurated = annotated.length > 0
        return {
            entries: useCurated ? annotated : fallback,
            includes: includes,
            curated: useCurated
        }
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
                text: "Atajos de teclado (sway)"
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
                : "Sin anotaciones \"@title\" — mostrando todos los bindsym detectados"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
            font.italic: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Text {
            visible: root.includePaths.length > 0
            text: "Nota: no se leen los \"include\" (" + root.includePaths.join(", ") + ")"
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
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
