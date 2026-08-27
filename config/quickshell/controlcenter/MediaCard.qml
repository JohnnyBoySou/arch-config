import QtQuick
import Quickshell.Services.Mpris

// "Tocando agora" — capa, título/artista e controles de transporte
Card {
    id: root

    // prefere um player tocando; senão, o primeiro disponível
    readonly property var player: {
        const list = Mpris.players.values
        if (!list || list.length === 0)
            return null
        for (const p of list) {
            if (p.isPlaying)
                return p
        }
        return list[0]
    }

    visible: player !== null
    implicitHeight: visible ? Theme.mediaHeight : 0

    Row {
        anchors.fill: parent
        anchors.margins: Theme.cardPad
        spacing: 14

        // ── capa do álbum ──
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.mediaArt; height: Theme.mediaArt; radius: 10
            color: Qt.rgba(1, 1, 1, 0.10)
            clip: true

            Image {
                id: art
                anchors.fill: parent
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !art.visible
                text: "󰎇"
                font.family: Theme.iconFamily
                font.pixelSize: 26
                color: Theme.textDim
            }
        }

        // ── texto + controles ──
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.mediaArt - 14
            spacing: 3

            Text {
                width: parent.width
                text: root.player ? (root.player.trackTitle || "Sem título") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                color: Theme.textDim
                elide: Text.ElideRight
            }

            Row {
                spacing: 6
                topPadding: 2

                Repeater {
                    model: [
                        { glyph: "󰒮", act: "previous" },
                        { glyph: "play",  act: "toggle" },
                        { glyph: "󰒭", act: "next" }
                    ]

                    Rectangle {
                        required property var modelData
                        width: 34; height: 28; radius: 8
                        color: btn.containsMouse ? Theme.cardHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph === "play"
                                  ? (root.player && root.player.isPlaying ? "󰏤" : "󰐊")
                                  : modelData.glyph
                            font.family: Theme.iconFamily
                            font.pixelSize: Theme.iconSize
                            color: Theme.text
                        }

                        MouseArea {
                            id: btn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.player) return
                                if (modelData.act === "previous") root.player.previous()
                                else if (modelData.act === "next") root.player.next()
                                else root.player.togglePlaying()
                            }
                        }
                    }
                }
            }
        }
    }
}
