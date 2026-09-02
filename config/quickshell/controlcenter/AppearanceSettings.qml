import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool open: false
    property int rounding: 12
    property int gapsIn: 5
    property int gapsOut: 8
    property int inactiveOpacity: 97
    property bool blurEnabled: true
    property int blurSize: 7
    property int blurPasses: 3
    property bool shadowEnabled: true
    property bool animationsEnabled: true
    property string statusText: "Alterações salvas automaticamente"

    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/hypr-appearance"
    readonly property color glass: Qt.rgba(0.055, 0.055, 0.065, 0.82)
    readonly property color surface: Qt.rgba(1, 1, 1, 0.075)
    readonly property bool busy: statusProc.running || settingProc.running || resetProc.running

    signal closed()

    function close() {
        root.closed()
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function setOption(key, value) {
        if (root.busy) return
        root.statusText = "Aplicando…"
        settingProc.command = [root.tool, "set", key, String(value)]
        settingProc.running = true
    }

    function parseStatus(text) {
        const values = {}
        for (const line of text.trim().split("\n")) {
            const separator = line.indexOf("=")
            if (separator > 0)
                values[line.slice(0, separator)] = line.slice(separator + 1)
        }
        root.rounding = Number(values.rounding ?? root.rounding)
        root.gapsIn = Number(values.gaps_in ?? root.gapsIn)
        root.gapsOut = Number(values.gaps_out ?? root.gapsOut)
        root.inactiveOpacity = Math.round(Number(values.inactive_opacity ?? 0.97) * 100)
        root.blurEnabled = values.blur_enabled === "1"
        root.blurSize = Number(values.blur_size ?? root.blurSize)
        root.blurPasses = Number(values.blur_passes ?? root.blurPasses)
        root.shadowEnabled = values.shadow_enabled === "1"
        root.animationsEnabled = values.animations_enabled === "1"
    }

    onOpenChanged: if (open) refresh()

    Process {
        id: statusProc
        command: [root.tool, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
        onExited: (code) => {
            if (code !== 0) root.statusText = "Não foi possível ler a configuração"
        }
    }

    Process {
        id: settingProc
        onExited: (code) => {
            root.statusText = code === 0
                ? "Aplicado e salvo na configuração"
                : "Não foi possível aplicar este ajuste"
            if (code === 0) root.refresh()
        }
    }

    Process {
        id: resetProc
        command: [root.tool, "reset"]
        onExited: (code) => {
            root.statusText = code === 0
                ? "Padrão visual restaurado"
                : "Não foi possível restaurar o padrão"
            if (code === 0) root.refresh()
        }
    }

    component ToggleCard: Rectangle {
        id: toggleCard
        property string glyph: ""
        property string label: ""
        property string description: ""
        property string settingKey: ""
        property bool checked: false

        implicitHeight: 86
        radius: 20
        color: checked ? Qt.rgba(0.039, 0.518, 1, 0.18) : root.surface
        border.width: 1
        border.color: checked ? Qt.rgba(0.039, 0.518, 1, 0.52) : Theme.stroke
        opacity: root.busy ? 0.65 : 1

        Behavior on color { ColorAnimation { duration: Theme.anim } }
        Behavior on border.color { ColorAnimation { duration: Theme.anim } }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: 14
            color: toggleCard.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.09)

            Text {
                anchors.centerIn: parent
                text: toggleCard.glyph
                font.family: Theme.iconFamily
                font.pixelSize: 17
                color: Theme.text
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.right: switchTrack.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: toggleCard.label
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: toggleCard.description
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: switchTrack
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 24
            radius: 12
            color: toggleCard.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: toggleCard.checked ? parent.width - width - 3 : 3
                width: 18
                height: 18
                radius: 9
                color: Theme.text

                Behavior on x {
                    NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.busy
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setOption(toggleCard.settingKey, toggleCard.checked ? 0 : 1)
        }
    }

    component SettingSlider: Item {
        id: settingSlider
        property string label: ""
        property string settingKey: ""
        property real currentValue: 0
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property string suffix: ""
        property real backendScale: 1
        property bool userDragging: false

        implicitHeight: 66

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: settingSlider.label
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: Math.round(slider.value) + settingSlider.suffix
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.accent
        }

        QQC.Slider {
            id: slider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 34
            from: settingSlider.from
            to: settingSlider.to
            stepSize: settingSlider.stepSize
            value: settingSlider.currentValue
            enabled: !root.busy
            onPressedChanged: {
                if (pressed) {
                    settingSlider.userDragging = true
                } else if (settingSlider.userDragging) {
                    settingSlider.userDragging = false
                    root.setOption(settingSlider.settingKey,
                                   Math.round(value) * settingSlider.backendScale)
                }
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.pressed ? 20 : 17
                height: width
                radius: width / 2
                color: Theme.text
                border.width: 3
                border.color: Theme.accent

                Behavior on width { NumberAnimation { duration: Theme.anim } }
            }
        }
    }

    component ActionButton: Rectangle {
        id: actionButton
        property string label: ""
        property string glyph: ""
        property bool primary: false
        signal clicked()

        implicitWidth: actionRow.implicitWidth + 28
        implicitHeight: 40
        radius: 15
        color: primary ? Theme.accent : (actionMouse.containsMouse ? Theme.cardHover : root.surface)
        border.width: primary ? 0 : 1
        border.color: Theme.stroke

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                text: actionButton.glyph
                font.family: Theme.iconFamily
                font.pixelSize: 15
                color: Theme.text
            }
            Text {
                text: actionButton.label
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "appearance-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Item {
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.close()
        }
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Math.min(screen.width - 80, 880)
        implicitHeight: Math.min(screen.height - 70, 680)
        anchors { top: true; left: true }
        margins {
            left: Math.max(20, (screen.width - implicitWidth) / 2)
            top: Math.max(20, (screen.height - implicitHeight) / 2)
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "appearance-settings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            anchors.margins: 16
            radius: 32
            color: root.glass
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
            focus: root.open
            Keys.onEscapePressed: root.close()

            MouseArea {
                anchors.fill: parent
                onClicked: (event) => event.accepted = true
            }

            Row {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 22
                height: 42
                spacing: 12

                Rectangle {
                    width: 38
                    height: 38
                    radius: 14
                    color: Qt.rgba(0.039, 0.518, 1, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(0.039, 0.518, 1, 0.36)

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        font.family: Theme.iconFamily
                        font.pixelSize: 18
                        color: Theme.accent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - closeButton.width - 50
                    spacing: 1

                    Text {
                        text: "Aparência do Hyprland"
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        text: "Ajustes persistentes com aplicação imediata"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }
                }

                ActionButton {
                    id: closeButton
                    glyph: "󰅖"
                    label: ""
                    onClicked: root.close()
                }
            }

            Column {
                anchors.top: header.bottom
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 16
                spacing: 16

                Text {
                    text: "Efeitos"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.textDim
                }

                Row {
                    width: parent.width
                    spacing: 12

                    ToggleCard {
                        width: (parent.width - 24) / 3
                        glyph: "󰽤"
                        label: "Blur"
                        description: "Vidro fosco"
                        settingKey: "blur_enabled"
                        checked: root.blurEnabled
                    }
                    ToggleCard {
                        width: (parent.width - 24) / 3
                        glyph: "󰘓"
                        label: "Sombras"
                        description: "Profundidade"
                        settingKey: "shadow_enabled"
                        checked: root.shadowEnabled
                    }
                    ToggleCard {
                        width: (parent.width - 24) / 3
                        glyph: "󰔎"
                        label: "Animações"
                        description: "Movimento suave"
                        settingKey: "animations_enabled"
                        checked: root.animationsEnabled
                    }
                }

                Row {
                    width: parent.width
                    height: 310
                    spacing: 14

                    Rectangle {
                        width: (parent.width - 14) * 0.56
                        height: parent.height
                        radius: 22
                        color: root.surface
                        border.width: 1
                        border.color: Theme.stroke

                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 4

                            Text {
                                text: "Geometria e janelas"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            SettingSlider {
                                width: parent.width
                                label: "Arredondamento"
                                settingKey: "rounding"
                                currentValue: root.rounding
                                from: 0; to: 30
                            }
                            SettingSlider {
                                width: parent.width
                                label: "Espaço interno"
                                settingKey: "gaps_in"
                                currentValue: root.gapsIn
                                from: 0; to: 30
                            }
                            SettingSlider {
                                width: parent.width
                                label: "Espaço externo"
                                settingKey: "gaps_out"
                                currentValue: root.gapsOut
                                from: 0; to: 40
                            }
                            SettingSlider {
                                width: parent.width
                                label: "Opacidade inativa"
                                settingKey: "inactive_opacity"
                                currentValue: root.inactiveOpacity
                                from: 50; to: 100
                                suffix: "%"
                                backendScale: 0.01
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 14) * 0.44
                        height: parent.height
                        radius: 22
                        color: root.surface
                        border.width: 1
                        border.color: Theme.stroke

                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 5

                            Text {
                                text: "Qualidade do blur"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            SettingSlider {
                                width: parent.width
                                label: "Tamanho"
                                settingKey: "blur_size"
                                currentValue: root.blurSize
                                from: 1; to: 20
                            }
                            SettingSlider {
                                width: parent.width
                                label: "Passadas"
                                settingKey: "blur_passes"
                                currentValue: root.blurPasses
                                from: 1; to: 6
                            }

                            Rectangle {
                                width: parent.width
                                height: 92
                                radius: 17
                                color: Qt.rgba(0.039, 0.518, 1, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(0.039, 0.518, 1, 0.24)

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    wrapMode: Text.WordWrap
                                    text: "Valores maiores deixam o vidro mais suave, mas também usam mais GPU."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textDim
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 22
                height: 42
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - resetButton.width - 10
                    text: root.statusText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: root.statusText.includes("Não") ? Theme.danger : Theme.textDim
                    elide: Text.ElideRight
                }

                ActionButton {
                    id: resetButton
                    glyph: "󰑓"
                    label: "Restaurar padrão"
                    onClicked: if (!root.busy) resetProc.running = true
                }
            }
        }
    }
}
