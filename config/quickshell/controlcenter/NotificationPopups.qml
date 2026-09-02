import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Toasts no canto superior direito, abaixo da menubar.
Scope {
    id: root

    readonly property int cardWidth: 380

    PanelWindow {
        visible: Notifs.popupCount > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.cardWidth + 16
        implicitHeight: Math.max(1, stack.implicitHeight + 16)
        anchors { top: true; right: true }
        margins { top: 40; right: 8 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification-popups"
        // Toast nao rouba foco do teclado do que o usuario estiver fazendo.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Column {
            id: stack
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 8
            width: root.cardWidth
            spacing: 8

            Repeater {
                model: Notifs.popups

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    readonly property bool critical:
                        modelData && modelData.urgency === NotificationUrgency.Critical

                    width: root.cardWidth
                    implicitHeight: content.implicitHeight + 24
                    radius: Theme.radiusCard
                    color: Theme.panel
                    border.width: 1
                    border.color: card.critical ? Theme.danger : Theme.stroke

                    opacity: 0
                    y: -8
                    Component.onCompleted: {
                        opacity = 1
                        y = 0
                    }
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                    Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

                    // Barra de urgencia na borda esquerda.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        width: 3
                        radius: 1.5
                        color: Notifs.urgencyColor(card.modelData ? card.modelData.urgency : 0)
                        visible: card.critical
                    }

                    // Critica nao some sozinha: exige o usuario dispensar.
                    Timer {
                        running: !card.critical && !hover.containsMouse
                        interval: card.modelData && card.modelData.expireTimeout > 0
                                  ? card.modelData.expireTimeout : 6000
                        onTriggered: Notifs.dismissPopup(card.modelData)
                    }

                    Row {
                        id: content
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 11

                        Item {
                            width: 32
                            height: 32
                            anchors.verticalCenter: undefined

                            Image {
                                id: notifImage
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 32
                                sourceSize.height: 32
                                source: {
                                    const m = card.modelData
                                    if (!m) return ""
                                    if (m.image) return m.image
                                    if (m.appIcon) return Quickshell.iconPath(m.appIcon, true)
                                    return ""
                                }
                                visible: status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                visible: notifImage.status !== Image.Ready
                                color: Theme.card

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂚"
                                    font.family: Theme.iconFamily
                                    font.pixelSize: 15
                                    color: Theme.textDim
                                }
                            }
                        }

                        Column {
                            width: parent.width - 32 - 11
                            spacing: 3

                            Text {
                                width: parent.width
                                text: card.modelData ? (card.modelData.appName || "Sistema") : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.4
                                color: Notifs.urgencyColor(card.modelData ? card.modelData.urgency : 0)
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: card.modelData ? card.modelData.summary : ""
                                visible: text !== ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                color: Theme.text
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: card.modelData ? card.modelData.body : ""
                                visible: text !== ""
                                textFormat: Text.StyledText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textDim
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            // Botoes de acao enviados pelo app.
                            Row {
                                spacing: 6
                                visible: card.modelData && card.modelData.actions.length > 0
                                topPadding: 4

                                Repeater {
                                    model: card.modelData ? card.modelData.actions : []

                                    Rectangle {
                                        required property var modelData
                                        width: actionText.implicitWidth + 20
                                        height: 26
                                        radius: 8
                                        color: actionArea.containsMouse ? Theme.cardHover : Theme.card
                                        border.width: 1
                                        border.color: Theme.stroke

                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.text
                                        }

                                        MouseArea {
                                            id: actionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                parent.modelData.invoke()
                                                Notifs.dismissPopup(card.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Botao de fechar, so no hover.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        width: 20
                        height: 20
                        radius: 10
                        visible: hover.containsMouse
                        color: closeArea.containsMouse ? Theme.danger : Theme.cardHover

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFamily
                            font.pixelSize: 10
                            color: Theme.text
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.dismissPopup(card.modelData)
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.RightButton
                        // Pausa a contagem enquanto o mouse esta em cima.
                        onClicked: Notifs.dismissPopup(card.modelData)
                        z: -1
                    }
                }
            }
        }
    }
}
