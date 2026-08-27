import QtQuick

// Slider horizontal com ícone à esquerda, no estilo do Control Center.
// Implementação própria (sem QtQuick.Controls) para controlar o visual por completo.
Item {
    id: root

    property string icon: ""
    property real value: 0.0        // 0.0 .. 1.0
    property bool muted: false
    property color fill: Theme.text

    signal moved(real newValue)
    signal iconClicked()

    implicitHeight: Theme.sliderHeight

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        border.color: Theme.stroke
        clip: true

        // preenchimento
        Rectangle {
            id: fillRect
            height: parent.height
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
            radius: parent.radius
            color: root.muted ? Qt.rgba(1, 1, 1, 0.22) : root.fill
            opacity: root.muted ? 1.0 : 0.92

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }

        // ícone sobre o preenchimento
        Text {
            id: iconLabel
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            text: root.icon
            font.family: Theme.iconFamily
            font.pixelSize: Theme.iconSize
            // contraste: escuro quando o preenchimento passou por baixo do ícone
            color: (!root.muted && fillRect.width > x + width + 2) ? Theme.bg : Theme.text
        }

        MouseArea {
            id: iconArea
            width: Theme.sliderHeight
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.leftMargin: iconArea.width
            cursorShape: Qt.PointingHandCursor

            function apply(mx) {
                const usable = track.width - iconArea.width
                const v = Math.max(0, Math.min(1, mx / usable))
                root.moved(v)
            }

            onPressed: (e) => apply(e.x)
            onPositionChanged: (e) => { if (pressed) apply(e.x) }
        }
    }
}
