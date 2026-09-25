import QtQuick
import Quickshell.Io

Item {
    id: root

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
        BarPositions.lanX = pos.x
        BarPositions.lanWidth = root.width
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
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    property bool connected: false
    property bool wifi: false
    property string connName: ""

    // Primero intenta con nmcli (NetworkManager). Si no está disponible o
    // no reporta nada conectado (p. ej. la red la maneja systemd-networkd,
    // dhcpcd, etc. y no NetworkManager), cae a revisar directamente el
    // estado de las interfaces en /sys/class/net.
    readonly property string checkScript: `
out=""
if command -v nmcli >/dev/null 2>&1; then
  line=$(nmcli -t -f TYPE,STATE,CONNECTION dev status 2>/dev/null | grep -E '^(wifi|ethernet):connected:' | head -n1)
  if [ -n "$line" ]; then
    t=$(printf '%s' "$line" | cut -d: -f1)
    n=$(printf '%s' "$line" | cut -d: -f3-)
    out="$t:$n"
  fi
fi
if [ -z "$out" ]; then
  for i in /sys/class/net/*/operstate; do
    dev=$(basename "$(dirname "$i")")
    [ "$dev" = "lo" ] && continue
    state=$(cat "$i" 2>/dev/null)
    if [ "$state" = "up" ]; then
      if [ -d "/sys/class/net/$dev/wireless" ]; then
        out="wifi:$dev"
      else
        out="ethernet:$dev"
      fi
      break
    fi
  done
fi
printf '%s\\n' "$out"
`

    Process {
        id: check
        command: ["sh", "-c", root.checkScript]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = text.trim()
                if (t.length === 0) {
                    root.connected = false
                    root.connName = ""
                } else {
                    let idx = t.indexOf(":")
                    let type = idx >= 0 ? t.slice(0, idx) : t
                    let name = idx >= 0 ? t.slice(idx + 1) : ""
                    root.connected = true
                    root.wifi = type === "wifi"
                    root.connName = name || type
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: check.running = true
    }

    Text {
        id: label
        text: root.connected
              ? (root.wifi ? "WiFi: " : "LAN: ") + root.connName
              : "Sin conexión"
        color: root.connected ? "#cdd6f4" : "#f38ba8"
        font.pixelSize: Scaling.pxFor(screenName, 12)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.togglePopup("networkPopupOpen")
    }
}
