import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Nombre del monitor (output) al que pertenece esta instancia de la
    // barra. Si está vacío, se muestran todos los workspaces; si trae un
    // nombre, se filtra solo a los de ese monitor.
    property string screenName: ""

    property var workspaces: []
    readonly property var filtered: root.screenName.length === 0
        ? root.workspaces
        : root.workspaces.filter(w => w.output === root.screenName)

    function refresh() { getData.running = true }

    // Hyprland no marca "activo/enfocado" dentro de "hyprctl -j workspaces"
    // en sí — hay que cruzarlo con "hyprctl -j monitors" (cada monitor
    // trae su "activeWorkspace" y si tiene el foco global). Se piden los
    // dos de un tirón separados por un delimitador para no encadenar
    // Process.
    //
    // "urgent" NO sale de acá: intenté primero leerlo de "hyprctl -j
    // clients" (no existe en esta versión) y después escuchar el evento
    // crudo del socket2 a mano (tampoco apareció con el nombre que
    // esperaba). En vez de seguir adivinando el protocolo, se usa
    // Quickshell.Hyprland (import de más arriba) -- Hyprland.workspaces
    // ya trae "urgent" resuelto y al día, mantenido por Quickshell mismo
    // en vez de por este archivo.
    Process {
        id: getData
        command: ["sh", "-c", "hyprctl -j workspaces; echo '---QS-SPLIT---'; hyprctl -j monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parts = text.split("---QS-SPLIT---")
                    let wsList = JSON.parse(parts[0])
                    let monitors = JSON.parse(parts[1])

                    let merged = wsList.map(w => {
                        let mon = monitors.find(m => m.name === w.monitor)
                        let isActive = !!(mon && mon.activeWorkspace && mon.activeWorkspace.id === w.id)
                        let isFocused = isActive && !!(mon && mon.focused === true)

                        let hw = Hyprland.workspaces.values.find(x => x.id === w.id)
                        let isUrgent = !!(hw && hw.urgent)

                        return {
                            id: w.id,
                            name: w.name,
                            output: w.monitor,
                            is_active: isActive,
                            is_focused: isFocused,
                            urgent: isUrgent
                        }
                    })
                    merged.sort((a, b) => a.id - b.id)
                    root.workspaces = merged
                } catch (e) { console.log("Workspaces: error parseando JSON", e) }
            }
        }
    }

    // Refresca la lista propia (id/nombre/activo/enfocado, vía hyprctl)
    // cada vez que Quickshell.Hyprland avisa que actualizó SUS workspaces
    // -- así "urgent" queda al día sin necesitar su propio timer/evento.
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.refresh() }
    }

    // Se suscribe al socket de eventos de Hyprland (socket2) y refresca
    // ante cualquier línea (cambios de workspace/foco, etc.). Requiere
    // tener "socat" instalado.
    Process {
        id: subscriber
        command: ["sh", "-c", "socat -U - UNIX-CONNECT:\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\" 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: (line) => root.refresh()
        }
    }

    // Sondeo de respaldo por si el socket de eventos no está disponible
    // (p. ej. falta socat)
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: switcher
        stdout: StdioCollector {
            onStreamFinished: {
                let out = text.trim()
                if (out.length > 0 && out !== "ok") console.log("Workspaces: hyprctl dispatch error:", out)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) console.log("Workspaces: hyprctl dispatch falló:", text)
            }
        }
    }

    Component.onCompleted: root.refresh()

    RowLayout {
        id: row
        spacing: Scaling.pxFor(screenName, 4)

        // Parpadeo para los workspaces urgentes (ej. una app que ya estaba
        // abierta en otro workspace pidió atención). Solo corre mientras
        // haya al menos uno urgente -- se apaga solo en cuanto ya no queda
        // ninguno (Hyprland limpia el flag urgent cuando enfocás ese
        // workspace).
        property bool blinkOn: false
        Timer {
            interval: 500
            repeat: true
            running: root.filtered.some(w => w.urgent)
            onTriggered: row.blinkOn = !row.blinkOn
        }

        Repeater {
            model: root.filtered
            delegate: Rectangle {
                required property var modelData
                implicitWidth: Scaling.pxFor(screenName, 26)
                implicitHeight: Scaling.pxFor(screenName, 22)
                radius: Scaling.pxFor(screenName, 4)
                color: modelData.urgent ? (row.blinkOn ? "#f38ba8" : "#45475a")
                       : modelData.is_focused ? "#89b4fa"
                       : (modelData.is_active ? "#45475a" : "transparent")

                Text {
                    anchors.centerIn: parent
                    text: modelData.name ? modelData.name : modelData.id
                    color: modelData.is_focused ? "#1e1e2e" : "#cdd6f4"
                    font.pixelSize: Scaling.pxFor(screenName, 12)
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: Bridge.closeTransientPopups()
                    onClicked: {
                        // Hyprland 0.55 (config Lua) cambió cómo "hyprctl
                        // dispatch" interpreta sus argumentos: ya no acepta
                        // el formato viejo "workspace N" (dispatcher + arg
                        // separados) -- ahora todo el argumento se evalúa
                        // como una expresión Lua vía hl.dispatch(...), y el
                        // dispatcher de workspace se llama "focus" con una
                        // tabla { workspace = "N" }. El formato viejo
                        // fallaba en silencio (el proceso corría, pero
                        // hyprctl devolvía un error de sintaxis Lua que
                        // nadie estaba mostrando).
                        switcher.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + String(modelData.id) + "\" })"]
                        switcher.running = true
                    }
                }
            }
        }
    }
}
