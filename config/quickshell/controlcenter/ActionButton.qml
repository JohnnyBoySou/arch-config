import QtQuick

// Botão de ação do rodapé (círculo + rótulo)
Item {
    id: root

    property string icon: ""
    property string label: ""
    property color hoverColor: Theme.cardHover
    property color backgroundColor: Theme.card
    property color iconColor: Theme.text

    signal activated()

    implicitHeight: Theme.actionHeight

    Column {
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.actionBadge; height: Theme.actionBadge; radius: Theme.actionBadge / 2
            color: area.containsMouse ? root.hoverColor : root.backgroundColor
            border.width: 1
            border.color: Theme.stroke

            Behavior on color {
                ColorAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize + 2
                color: root.iconColor
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textDim
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
