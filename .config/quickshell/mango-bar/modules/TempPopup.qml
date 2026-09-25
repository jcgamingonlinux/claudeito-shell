import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    property var zones: []

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el popup al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    // Misma fuente que Temp.qml: primero /sys/class/thermal, y si no hay
    // nada ahí, también /sys/class/hwmon (lo que usan btop/sensors) -- en
    // equipos viejos suele faltar el primero pero el segundo sí tiene
    // datos. Acá se listan TODAS las lecturas encontradas de ambas
    // fuentes, no solo la "mejor" (eso lo hace Temp.qml para la barra).
    readonly property string script: `
for z in /sys/class/thermal/thermal_zone*; do
  [ -d "$z" ] || continue
  type=$(cat "$z/type" 2>/dev/null)
  temp=$(cat "$z/temp" 2>/dev/null)
  [ -n "$temp" ] && printf '%s %s\\n' "$type" "$temp"
done
for h in /sys/class/hwmon/hwmon*; do
  [ -d "$h" ] || continue
  hwname=$(cat "$h/name" 2>/dev/null)
  for t in "$h"/temp*_input; do
    [ -f "$t" ] || continue
    lf=$(echo "$t" | sed 's/_input$/_label/')
    label=$(cat "$lf" 2>/dev/null)
    temp=$(cat "$t" 2>/dev/null)
    [ -z "$label" ] && label="$hwname"
    [ -n "$temp" ] && printf '%s %s\\n' "$label" "$temp"
  done
done
`

    function scan() {
        proc.command = ["sh", "-c", root.script]
        proc.running = true
    }

    Process {
        id: proc
        // FIX: antes se vaciaba root.zones y se iba llenando línea por
        // línea en vivo -- cada reasignación reiniciaba el scroll de la
        // ListView a la parte de arriba, así que si estabas scrolleando
        // justo cuando tocaba el refresco cada 2s (bastante seguido), el
        // contenido "saltaba" al comienzo. Ahora se junta todo en un
        // buffer y se asigna una sola vez al terminar, restaurando la
        // posición de scroll que tenías.
        property var _buffer: []
        onRunningChanged: if (running) proc._buffer = []
        stdout: SplitParser {
            onRead: (line) => {
                let t = line.trim()
                if (t.length === 0) return
                let parts = t.split(" ")
                let type = parts[0] || "?"
                let temp = parseInt(parts[1])
                if (isNaN(temp)) return
                proc._buffer.push({ type: type, celsius: temp / 1000 })
            }
        }
        onExited: {
            let savedY = zonesList.contentY
            root.zones = proc._buffer
            zonesList.contentY = Math.max(0, Math.min(savedY, zonesList.contentHeight - zonesList.height))
        }
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: root.scan()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(6)

        Text {
            text: "Temperatura"
            color: "#f5e0dc"
            font.bold: true
            font.pixelSize: Scaling.px(13)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // Antes esto era un Repeater directo dentro del ColumnLayout: con
        // pocas zonas térmicas se veía bien, pero en equipos con muchas
        // (varios núcleos, NVMe, WiFi, ACPI, etc.) la lista crecía más que
        // el alto fijo del popup y el contenido se salía de la caja sin
        // forma de verlo. Una ListView con clip + scrollbar soluciona esto
        // igual que ya se hacía en CpuPopup.
        ListView {
            id: zonesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Scaling.px(4)
            model: root.zones
            visible: root.zones.length > 0

            ScrollBar.vertical: ScrollBar {
                policy: zonesList.contentHeight > zonesList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: RowLayout {
                required property var modelData
                // Se resta un poco de ancho para dejarle lugar al
                // scrollbar (antes tapaba los últimos caracteres, ej. los
                // grados, cuando había más zonas de las que entraban).
                width: ListView.view.width - Scaling.px(14)

                Text {
                    text: modelData.type
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.px(11)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.celsius.toFixed(0) + "°C"
                    color: "#cdd6f4"
                    font.pixelSize: Scaling.px(11)
                }
            }
        }

        Text {
            visible: root.zones.length === 0
            text: "Sin datos de temperatura (no se encontró /sys/class/thermal ni /sys/class/hwmon)"
            wrapMode: Text.Wrap
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
            Layout.fillWidth: true
        }
    }
}
