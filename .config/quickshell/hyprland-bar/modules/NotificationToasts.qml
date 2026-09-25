import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: Scaling.px(320)
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Scaling.px(6)

        Repeater {
            model: Notifications.active

            delegate: Rectangle {
                id: card
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: cardColumn.implicitHeight + 20
                radius: Scaling.px(8)
                color: "#1e1e2e"
                border.width: Scaling.px(1)
                // urgency: 0=Low 1=Normal 2=Critical (según la mayoría de versiones)
                border.color: card.modelData.urgency === 2 ? "#f38ba8" : "#313244"

                ColumnLayout {
                    id: cardColumn
                    anchors.fill: parent
                    anchors.margins: Scaling.px(10)
                    spacing: Scaling.px(4)

                    Text {
                        text: card.modelData.appName + (card.modelData.summary ? " — " + card.modelData.summary : "")
                        color: "#f5e0dc"
                        font.bold: true
                        font.pixelSize: Scaling.px(12)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: card.modelData.body.length > 0
                        text: card.modelData.body
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(11)
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        spacing: Scaling.px(6)
                        visible: card.modelData.actions.length > 0

                        Repeater {
                            model: card.modelData.actions
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: actLabel.implicitWidth + 12
                                implicitHeight: Scaling.px(20)
                                radius: Scaling.px(4)
                                color: "#45475a"

                                Text {
                                    id: actLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData.text
                                    color: "#cdd6f4"
                                    font.pixelSize: Scaling.px(11)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Notifications.invokeAction(card.modelData, parent.modelData.id)
                                }
                            }
                        }
                    }
                }

                // Click en cualquier parte de la tarjeta (fuera de las acciones) la descarta
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: Notifications.dismiss(card.modelData)
                }
            }
        }
    }
}
