import QtQuick

// Slider com contexto: evita depender apenas do glifo para distinguir
// saída de áudio e microfone.
Column {
    id: root

    property string label: ""
    property string detail: ""
    property string icon: ""
    property real value: 0.0
    property bool muted: false
    property color fill: Theme.text

    signal moved(real newValue)
    signal iconClicked()

    spacing: 6

    Row {
        id: header
        width: parent.width

        Text {
            width: parent.width * 0.34
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            width: parent.width * 0.66
            text: root.detail
            horizontalAlignment: Text.AlignRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textDim
            elide: Text.ElideRight
        }
    }

    SliderRow {
        id: slider
        width: parent.width
        icon: root.icon
        value: root.value
        muted: root.muted
        fill: root.fill
        onMoved: (newValue) => root.moved(newValue)
        onIconClicked: root.iconClicked()
    }
}
