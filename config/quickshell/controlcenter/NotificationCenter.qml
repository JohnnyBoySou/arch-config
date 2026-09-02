import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Central de notificacoes: historico, Nao Perturbe e limpeza.
Scope {
    id: root

    property bool open: false
    property bool closeArmed: false

    readonly property int panelWidth: 400

    signal closed()

    function close() { root.closed() }

    onOpenChanged: {
        if (open) {
            root.closeArmed = false
            closeArmTimer.restart()
        }
    }

    Timer {
        id: closeArmTimer
        interval: 220
        onTriggered: root.closeArmed = true
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "notification-center-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            enabled: root.closeArmed
            onClicked: root.close()
        }

        Item {
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.close()
        }
    }

    PanelWindow {
        id: panelWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.panelWidth + 16
        implicitHeight: Math.min(screen.height - 80, 620)
        anchors { top: true; right: true }
        margins { top: 44; right: 8 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification-center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            MouseArea { anchors.fill: parent }

            // ── cabecalho ──
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.pad
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notificações"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Nao Perturbe
                    Rectangle {
                        width: 30
                        height: 28
                        radius: 9
                        color: Notifs.dnd ? Qt.rgba(1, 0.62, 0.04, 0.30)
                                          : (dndArea.containsMouse ? Theme.cardHover : Theme.card)
                        border.width: 1
                        border.color: Notifs.dnd ? Theme.warning : Theme.stroke

                        Text {
                            anchors.centerIn: parent
                            text: Notifs.dnd ? "󰂛" : "󰂚"
                            font.family: Theme.iconFamily
                            font.pixelSize: 14
                            color: Notifs.dnd ? Theme.warning : Theme.textDim
                        }

                        MouseArea {
                            id: dndArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.toggleDnd()
                        }
                    }

                    // Limpar tudo
                    Rectangle {
                        width: 64
                        height: 28
                        radius: 9
                        visible: Notifs.historyCount > 0
                        color: clearArea.containsMouse ? Theme.cardHover : Theme.card
                        border.width: 1
                        border.color: Theme.stroke

                        Text {
                            anchors.centerIn: parent
                            text: "Limpar"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.text
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.clearHistory()
                        }
                    }
                }
            }

            Text {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.pad
                anchors.topMargin: 4
                visible: Notifs.dnd
                text: "Não Perturbe ativo — só notificações críticas aparecem."
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: 11
                color: Theme.warning
            }

            // ── estado vazio ──
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: Notifs.historyCount === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰂜"
                    font.family: Theme.iconFamily
                    font.pixelSize: 34
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sem notificações"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textDim
                }
            }

            // ── historico ──
            ListView {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.pad
                anchors.topMargin: Notifs.dnd ? 26 : 10
                spacing: 8
                clip: true
                model: Notifs.history
                visible: Notifs.historyCount > 0

                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    implicitHeight: itemBody.implicitHeight + 22
                    radius: Theme.radiusCard
                    color: itemArea.containsMouse ? Theme.cardHover : Theme.card
                    border.width: 1
                    border.color: modelData.urgency === NotificationUrgency.Critical
                                  ? Qt.rgba(1, 0.27, 0.23, 0.5) : Theme.stroke

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: itemBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 11
                        spacing: 10

                        Item {
                            width: 26
                            height: 26

                            Image {
                                id: histImage
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 26
                                sourceSize.height: 26
                                source: {
                                    if (item.modelData.image) return item.modelData.image
                                    if (item.modelData.appIcon)
                                        return Quickshell.iconPath(item.modelData.appIcon, true)
                                    return ""
                                }
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: histImage.status !== Image.Ready
                                text: "󰂚"
                                font.family: Theme.iconFamily
                                font.pixelSize: 13
                                color: Theme.textDim
                            }
                        }

                        Column {
                            width: parent.width - 26 - 10 - 24
                            spacing: 2

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: item.modelData.appName
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Notifs.urgencyColor(item.modelData.urgency)
                                }

                                Text {
                                    text: "· " + Notifs.timeAgo(item.modelData.time)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                }
                            }

                            Text {
                                width: parent.width
                                text: item.modelData.summary
                                visible: text !== ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.DemiBold
                                color: Theme.text
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: item.modelData.body
                                visible: text !== ""
                                textFormat: Text.StyledText
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 7
                        width: 18
                        height: 18
                        radius: 9
                        visible: itemArea.containsMouse || removeArea.containsMouse
                        color: removeArea.containsMouse ? Theme.danger : Theme.cardHover

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFamily
                            font.pixelSize: 9
                            color: Theme.text
                        }

                        MouseArea {
                            id: removeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.removeFromHistory(item.index)
                        }
                    }
                }
            }
        }
    }
}
