import QtQuick

// Ladrilho de alternância (Wi-Fi, Não Perturbe, ...) — estilo Control Center
Card {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool interactive: true
    property color activeColor: Theme.cardActive

    signal toggled()

    implicitHeight: Theme.tileHeight
    color: root.active ? root.activeColor
                       : (mouse.containsMouse ? Theme.cardHover : Theme.card)
    border.color: root.active ? "transparent" : Theme.stroke

    Behavior on color {
        ColorAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.cardPad
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.badge; height: Theme.badge; radius: Theme.badge / 2
            color: root.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize
                color: Theme.text
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - Theme.badge - 12

            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.sublabel
                visible: root.sublabel !== ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                color: root.active ? Qt.rgba(1, 1, 1, 0.75) : Theme.textDim
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled()
    }
}
