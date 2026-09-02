import QtQuick
import Quickshell.Services.Pipewire

// Seleção de saída PipeWire. Só aparece quando há mais de uma opção real.
Card {
    id: root

    readonly property var sinks: Pipewire.nodes.values.filter(node =>
        node && node.ready && node.isSink && !node.isStream && node.audio)
    readonly property var currentSink: Pipewire.defaultAudioSink

    visible: sinks.length > 1
    implicitHeight: visible ? title.implicitHeight + list.implicitHeight + Theme.cardPad * 2 + 8 : 0

    PwObjectTracker { objects: Pipewire.nodes.values }

    Text {
        id: title
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.cardPad
        text: "Saída de áudio"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSm
        font.weight: Font.DemiBold
        color: Theme.textDim
    }

    Column {
        id: list
        anchors.top: title.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.cardPad
        anchors.rightMargin: Theme.cardPad
        spacing: 6

        Repeater {
            model: root.sinks

            Rectangle {
                required property var modelData
                width: list.width
                height: 38
                radius: 10
                readonly property bool selected: root.currentSink
                    && modelData.id === root.currentSink.id
                color: selected ? Qt.rgba(0.039, 0.518, 1.0, 0.34)
                                : (deviceArea.containsMouse ? Theme.cardHover : "transparent")
                border.width: 1
                border.color: selected ? Theme.accent : Theme.stroke

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.selected ? "󰓃" : "󰓄"
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.iconSize
                        color: parent.parent.selected ? Theme.accent : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34
                        text: modelData.description || modelData.nickname || modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.text
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: deviceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }
}
