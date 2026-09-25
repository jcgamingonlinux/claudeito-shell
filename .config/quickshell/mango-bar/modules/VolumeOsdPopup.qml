import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Rectangle {
    id: root
    focus: Bridge.volumePopupOpen
    color: "#1e1e2e"
    radius: Scaling.px(10)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: root.sink && root.sink.audio ? root.sink.audio.muted : false
    readonly property real volume: root.sink && root.sink.audio ? root.sink.audio.volume : 0

    function setVolume(value) {
        if (!root.sink || !root.sink.audio) return
        root.sink.audio.volume = Math.max(0, Math.min(1, value))
    }

    function changeVolume(delta) {
        root.setVolume(root.volume + delta)
    }

    onVisibleChanged: {
        if (visible && Bridge.volumePopupOpen)
            Qt.callLater(root.forceActiveFocus)
    }

    Connections {
        target: Bridge
        function onVolumePopupOpenChanged() {
            if (Bridge.volumePopupOpen)
                Qt.callLater(root.forceActiveFocus)
        }
    }

    Keys.onLeftPressed: (event) => {
        root.changeVolume(-0.05)
        event.accepted = true
    }
    Keys.onRightPressed: (event) => {
        root.changeVolume(0.05)
        event.accepted = true
    }
    Keys.onEscapePressed: (event) => {
        Bridge.volumePopupOpen = false
        event.accepted = true
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(12)
        spacing: Scaling.px(10)

        Text {
            text: root.muted ? "🔇" : "🔊"
            font.pixelSize: Scaling.px(18)
        }

            Rectangle {
                id: sliderTrack
                Layout.fillWidth: true
                height: Scaling.px(12)
                radius: Scaling.px(6)
                color: "#313244"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.volume))
                height: parent.height
                radius: Scaling.px(6)
                color: root.muted ? "#f38ba8" : "#89b4fa"
            }

            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, parent.width * Math.max(0, Math.min(1, root.volume)) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: Scaling.px(16)
                height: width
                radius: width / 2
                color: "#cdd6f4"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => root.setVolume(mouse.x / width)
                onPositionChanged: (mouse) => {
                    if (pressed) root.setVolume(mouse.x / width)
                }
            }
        }

        Text {
            text: Math.round(root.volume * 100) + "%"
            color: "#cdd6f4"
            font.pixelSize: Scaling.px(12)
            Layout.preferredWidth: Scaling.px(36)
        }
    }
}
