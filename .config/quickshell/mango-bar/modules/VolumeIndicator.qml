import QtQuick
import Quickshell.Services.Pipewire

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
        BarPositions.volX = pos.x
        BarPositions.volWidth = root.width
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

    property var sink: Pipewire.defaultAudioSink

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    // Muestra el widget visual (OSD) cada vez que cambia el volumen o el
    // mute — ya sea desde la rueda del mouse acá mismo, o desde las teclas
    // multimedia (que llaman a wpctl directo y modifican el mismo sink de
    // Pipewire, así que esto también las detecta).
    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() {
            Bridge.volumeOsdVisible = true
            osdHideTimer.restart()
        }
        function onMutedChanged() {
            Bridge.volumeOsdVisible = true
            osdHideTimer.restart()
        }
    }

    Timer {
        id: osdHideTimer
        interval: 1500
        onTriggered: Bridge.volumeOsdVisible = false
    }

    Text {
        id: label
        text: {
            if (!root.sink || !root.sink.audio) return "VOL --"
            if (root.sink.audio.muted) return "VOL mute"
            let vol = Math.round(root.sink.audio.volume * 100)
            return "VOL " + vol + "%"
        }
        color: "#cdd6f4"
        font.pixelSize: Scaling.pxFor(screenName, 12)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (!root.sink || !root.sink.audio) return
            if (mouse.button === Qt.LeftButton) {
                Bridge.togglePopup("volumePopupOpen")
            } else if (mouse.button === Qt.RightButton) {
                Bridge.closeTransientPopups()
                root.sink.audio.muted = !root.sink.audio.muted
            }
        }
        onWheel: (wheel) => {
            if (!root.sink || !root.sink.audio) return
            let step = 0.05
            let delta = wheel.angleDelta.y > 0 ? step : -step
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta))
        }
    }
}
