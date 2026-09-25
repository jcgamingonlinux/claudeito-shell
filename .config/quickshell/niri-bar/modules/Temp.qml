import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // Reporta su posición en la barra (para que su caja de info aparezca
    // centrada justo debajo) cada vez que se mueve o cambia de ancho.
    property string screenName: ""
    function reportPos() {
        if (root.screenName.length === 0) return
        // Solo reporta si esta instancia está en la pantalla con foco —
        // la caja de info solo se muestra ahí, así que no hace falta (ni
        // conviene) que otra pantalla sobreescriba el valor.
        if (root.screenName !== FocusedScreen.name) return
        let pos = root.mapToItem(null, 0, root.height)
        BarPositions.tempX = pos.x
        BarPositions.tempWidth = root.width
    }
    onXChanged: root.reportPos()
    onWidthChanged: root.reportPos()
    Component.onCompleted: Qt.callLater(root.reportPos)

    // Respaldo: reporta también cada 2s por si algún xChanged/widthChanged
    // puntual no llegara a dispararse.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.reportPos()
    }

    property real celsius: 0
    property bool available: false

    // Recorre las zonas térmicas del kernel (/sys/class/thermal) Y, si no
    // encuentra nada ahí, también /sys/class/hwmon (lo que usan
    // btop/sensors/lm-sensors) -- en equipos viejos (ej. AMD Puma/Jaguar
    // como el E1-6010) suele NO haber thermal_zone con datos útiles, pero
    // el sensor SÍ está expuesto por hwmon (driver k10temp, label
    // "Tctl"/"Tdie", o directamente el nombre del chip si no hay label).
    // Prioriza lo que parece ser el paquete de CPU (pkg/cpu/tctl/tdie/
    // k10temp/coretemp en el nombre) y si no encuentra ninguna coincidencia
    // usa la primera lectura disponible de cualquiera de las dos fuentes.
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

    Process {
        id: proc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(l => l.length > 0)
                if (lines.length === 0) { root.available = false; return }
                let best = null
                for (let i = 0; i < lines.length; i++) {
                    let parts = lines[i].split(" ")
                    let type = parts[0] || ""
                    let temp = parseInt(parts[1])
                    if (isNaN(temp)) continue
                    if (best === null) best = temp
                    if (/pkg|cpu|tctl|tdie|k10temp|coretemp/i.test(type)) { best = temp; break }
                }
                if (best !== null) {
                    root.celsius = best / 1000
                    root.available = true
                } else {
                    root.available = false
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Text {
        id: label
        text: root.available ? ("TEMP " + root.celsius.toFixed(0) + "°C") : "TEMP --"
        color: "#cdd6f4"
        font.pixelSize: Scaling.pxFor(screenName, 12)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.togglePopup("tempPopupOpen")
    }
}
