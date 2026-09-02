import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool open: false
    property int workspaceId: 0
    property string workspaceName: ""
    property string selectedColor: "#0A84FF"
    property string statusText: ""
    property bool saving: false
    property bool closeArmed: false
    property bool advancedOpen: false
    property int borderSize: 1
    property int windowRounding: 12
    property int gapsIn: 5
    property int gapsOut: 8
    property string animationStyle: "slidefade 15%"

    readonly property string workspaceTool: Quickshell.env("HOME") + "/.local/bin/workspace-style"
    readonly property int editorLeft: 8
    readonly property int editorTop: 44
    readonly property int editorWidth: 370
    readonly property var palette: [
        "#0A84FF", "#64D2FF", "#30D158", "#FFD60A", "#FF9F0A",
        "#FF453A", "#FF375F", "#BF5AF2", "#AC8E68", "#8E8E93"
    ]
    readonly property var animations: [
        { "label": "Padrão", "value": "default" },
        { "label": "Slide", "value": "slide" },
        { "label": "Suave", "value": "slidefade 15%" },
        { "label": "Vertical", "value": "slidevert" }
    ]
    readonly property bool validName: workspaceName.trim().length > 0
    readonly property bool validColor: /^#[0-9A-Fa-f]{6}$/.test(selectedColor)

    signal closed()

    function close() {
        if (!saving) root.closed()
    }

    function pointInsideEditor(x, y) {
        return x >= root.editorLeft
            && x <= root.editorLeft + root.editorWidth
            && y >= root.editorTop
            && y <= root.editorTop + editorWindow.implicitHeight
    }

    function chooseColor(value) {
        const normalized = value.toUpperCase()
        if (!/^#[0-9A-F]{6}$/.test(normalized)) return
        root.selectedColor = normalized
        if (hexInput.text !== normalized) hexInput.text = normalized
    }

    function loadCurrent() {
        if (!loadProc.running) {
            root.statusText = "Carregando…"
            loadProc.running = true
        }
    }

    function save() {
        const name = root.workspaceName.trim()
        if (!root.validName || !root.validColor || root.workspaceId < 1 || saveProc.running)
            return
        root.saving = true
        root.statusText = "Salvando…"
        saveProc.command = [
            root.workspaceTool,
            "configure",
            root.workspaceId.toString(),
            "--name", name,
            "--color", root.selectedColor,
            "--border-size", root.borderSize.toString(),
            "--rounding", root.windowRounding.toString(),
            "--gaps-in", root.gapsIn.toString(),
            "--gaps-out", root.gapsOut.toString(),
            "--animation", root.animationStyle
        ]
        saveProc.running = true
    }

    onOpenChanged: {
        if (open) {
            root.closeArmed = false
            closeArmTimer.restart()
            root.workspaceId = 0
            root.workspaceName = ""
            root.statusText = ""
            root.saving = false
            root.advancedOpen = false
            root.loadCurrent()
        } else {
            closeArmTimer.stop()
            root.closeArmed = false
        }
    }

    Process {
        id: loadProc
        command: [root.workspaceTool, "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const profile = JSON.parse(text)
                    root.workspaceId = profile.id || 0
                    root.workspaceName = profile.name || ""
                    root.borderSize = profile.border_size ?? 1
                    root.windowRounding = profile.rounding ?? 12
                    root.gapsIn = profile.gaps_in ?? 5
                    root.gapsOut = profile.gaps_out ?? 8
                    root.animationStyle = profile.animation || "slidefade 15%"
                    nameInput.text = root.workspaceName
                    root.chooseColor(profile.color || "#8E8E93")
                    root.statusText = ""
                    nameInput.forceActiveFocus()
                    nameInput.selectAll()
                } catch (error) {
                    root.statusText = "Não foi possível carregar o workspace"
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) root.statusText = "Não foi possível carregar o workspace"
        }
    }

    Process {
        id: saveProc
        stdout: StdioCollector { }
        stderr: StdioCollector { }
        onExited: (code) => {
            root.saving = false
            if (code === 0) {
                root.statusText = "Workspace atualizado"
                closeTimer.start()
            } else {
                root.statusText = "Não foi possível salvar"
            }
        }
    }

    Timer {
        id: closeArmTimer
        interval: 350
        onTriggered: root.closeArmed = true
    }

    Timer {
        id: closeTimer
        interval: 450
        onTriggered: root.closed()
    }

    component AdvancedSlider: Item {
        id: setting
        property string label: ""
        property int currentValue: 0
        property int minimum: 0
        property int maximum: 30
        property string suffix: " px"
        signal edited(int value)

        implicitHeight: 50

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: setting.label
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: setting.currentValue + setting.suffix
            color: root.selectedColor
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        QQC.Slider {
            id: slider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 28
            from: setting.minimum
            to: setting.maximum
            stepSize: 1
            value: setting.currentValue
            enabled: !root.saving
            onMoved: setting.edited(Math.round(value))

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: root.selectedColor
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.pressed ? 18 : 15
                height: width
                radius: width / 2
                color: Theme.text
                border.width: 3
                border.color: root.selectedColor
            }
        }
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        // Fica abaixo do editor: captura apenas o que realmente for clique fora.
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "workspace-editor-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            enabled: root.closeArmed
            onClicked: (mouse) => {
                if (!root.pointInsideEditor(mouse.x, mouse.y)) root.close()
            }
        }

        Item {
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.close()
        }
    }

    PanelWindow {
        id: editorWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        margins { top: root.editorTop; left: root.editorLeft }
        implicitWidth: root.editorWidth
        implicitHeight: editorContent.implicitHeight + 40
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "workspace-editor"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            Column {
                id: editorContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 13
                        color: Qt.rgba(1, 1, 1, 0.10)

                        Text {
                            anchors.centerIn: parent
                            text: root.workspaceId > 0 ? root.workspaceId.toString() : "—"
                            color: root.selectedColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 2

                        Text {
                            text: "Editar workspace"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Nome e cor de identificação"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }
                }

                Text {
                    text: "Nome"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.09)
                    border.width: nameInput.activeFocus ? 2 : 1
                    border.color: nameInput.activeFocus ? root.selectedColor : Theme.stroke

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 13
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        selectionColor: root.selectedColor
                        selectedTextColor: "white"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        maximumLength: 32
                        clip: true
                        enabled: !root.saving
                        onTextEdited: root.workspaceName = text
                        Keys.onReturnPressed: root.save()
                        Keys.onEscapePressed: root.close()
                    }
                }

                Text {
                    text: "Cor da borda"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.DemiBold
                }

                Grid {
                    width: parent.width
                    columns: 10
                    spacing: 8

                    Repeater {
                        model: root.palette

                        Rectangle {
                            required property string modelData
                            width: 25
                            height: 25
                            radius: 999
                            color: modelData
                            border.width: root.selectedColor === modelData ? 3 : 1
                            border.color: root.selectedColor === modelData
                                ? "white" : Qt.rgba(1, 1, 1, 0.20)
                            scale: colorMouse.containsMouse ? 1.12 : 1

                            Behavior on scale {
                                NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                            }

                            MouseArea {
                                id: colorMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.saving
                                onClicked: root.chooseColor(parent.modelData)
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 44
                        height: 40
                        radius: 11
                        color: root.validColor ? root.selectedColor : "transparent"
                        border.width: 1
                        border.color: Theme.stroke
                    }

                    Rectangle {
                        width: parent.width - 54
                        height: 40
                        radius: 11
                        color: Qt.rgba(1, 1, 1, 0.07)
                        border.width: hexInput.activeFocus ? 2 : 1
                        border.color: hexInput.activeFocus && root.validColor
                            ? root.selectedColor : Theme.stroke

                        TextInput {
                            id: hexInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.selectedColor
                            color: Theme.text
                            selectionColor: root.selectedColor
                            selectedTextColor: "white"
                            font.family: Theme.iconFamily
                            font.pixelSize: 13
                            maximumLength: 7
                            clip: true
                            enabled: !root.saving
                            onTextEdited: root.selectedColor = text.toUpperCase()
                            Keys.onReturnPressed: root.save()
                            Keys.onEscapePressed: root.close()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 54
                    radius: 14
                    color: Qt.rgba(0.05, 0.05, 0.06, 0.65)
                    border.width: 2
                    border.color: root.validColor ? root.selectedColor : Theme.stroke

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "●"
                            color: root.validColor ? root.selectedColor : Theme.textDim
                            font.pixelSize: 12
                        }
                        Text {
                            text: root.workspaceName.trim() || "Nome do workspace"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 12
                    color: advancedMouse.containsMouse
                        ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: Theme.stroke

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: "󰒓"
                            color: root.selectedColor
                            font.family: Theme.iconFamily
                            font.pixelSize: 14
                        }
                        Text {
                            text: "Ajustes avançados"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.advancedOpen ? "󰅀" : "󰅂"
                        color: Theme.textDim
                        font.family: Theme.iconFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: advancedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.saving
                        onClicked: root.advancedOpen = !root.advancedOpen
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.advancedOpen

                    AdvancedSlider {
                        width: parent.width
                        label: "Grossura da borda"
                        currentValue: root.borderSize
                        minimum: 0
                        maximum: 8
                        onEdited: (value) => root.borderSize = value
                    }

                    AdvancedSlider {
                        width: parent.width
                        label: "Arredondamento dos cantos"
                        currentValue: root.windowRounding
                        minimum: 0
                        maximum: 30
                        onEdited: (value) => root.windowRounding = value
                    }

                    AdvancedSlider {
                        width: parent.width
                        label: "Espaço entre janelas"
                        currentValue: root.gapsIn
                        minimum: 0
                        maximum: 30
                        onEdited: (value) => root.gapsIn = value
                    }

                    AdvancedSlider {
                        width: parent.width
                        label: "Margem externa"
                        currentValue: root.gapsOut
                        minimum: 0
                        maximum: 40
                        onEdited: (value) => root.gapsOut = value
                    }

                    Text {
                        text: "Animação ao trocar de workspace"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.animations

                            Rectangle {
                                required property var modelData
                                width: (parent.width - 18) / 4
                                height: 34
                                radius: 10
                                color: root.animationStyle === modelData.value
                                    ? root.selectedColor
                                    : (animationMouse.containsMouse
                                        ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.07))
                                border.width: 1
                                border.color: root.animationStyle === modelData.value
                                    ? root.selectedColor : Theme.stroke

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: animationMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.saving
                                    onClicked: root.animationStyle = parent.modelData.value
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 16
                    text: root.statusText
                    color: root.statusText.indexOf("Não") === 0 ? Theme.danger : Theme.textDim
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        id: cancelButton
                        width: (parent.width - 10) / 2
                        height: 42
                        radius: 13
                        color: cancelMouse.containsMouse
                            ? Theme.cardHover : Theme.card
                        opacity: root.saving ? 0.45 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.saving
                            onClicked: root.close()
                        }
                    }

                    Rectangle {
                        id: saveButton
                        width: (parent.width - 10) / 2
                        height: 42
                        radius: 13
                        color: root.validColor
                            ? (saveMouse.containsMouse && saveMouse.enabled
                                ? Qt.lighter(root.selectedColor, 1.12)
                                : root.selectedColor)
                            : Theme.card
                        opacity: saveMouse.enabled ? 1 : 0.40

                        Text {
                            anchors.centerIn: parent
                            text: root.saving ? "Salvando…" : "Salvar"
                            color: "white"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: saveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.validName && root.validColor
                                && root.workspaceId > 0 && !root.saving
                            onClicked: root.save()
                        }
                    }
                }
            }
        }
    }
}
