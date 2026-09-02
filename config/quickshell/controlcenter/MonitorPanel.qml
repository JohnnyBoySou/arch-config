import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Painel de monitores. O estado todo vive no `monitor-layout`; aqui só se
// desenha o mapa e se chamam os subcomandos.
//
// Posição é aplicada e salva na hora — dá para desfazer a olho nu. Modo,
// escala, rotação e ligar/desligar passam por uma confirmação de 15 s: se ela
// estourar, um `monitor-layout revert` recarrega o .conf em disco, que ainda
// descreve o último estado bom. É a rede de segurança contra ficar sem imagem.
Scope {
    id: root

    property bool open: false
    property bool closeArmed: false

    property var monitors: []
    property string primary: ""
    property bool menubarOnPrimary: false
    property string selectedName: ""
    property string statusText: ""
    property bool statusIsError: false
    property bool busy: false
    property bool dragging: false

    property bool confirming: false
    property int secondsLeft: 0

    readonly property string tool: Quickshell.env("HOME") + "/.local/bin/monitor-layout"
    readonly property int panelWidth: 460
    readonly property int mapHeight: 196
    readonly property int mapPad: 14
    readonly property int snapDistance: 40   // em pixels reais de área de trabalho

    readonly property var rotations: [
        { "label": "0°", "value": 0 },
        { "label": "90°", "value": 1 },
        { "label": "180°", "value": 2 },
        { "label": "270°", "value": 3 }
    ]

    readonly property var placed: monitors.filter(m => m.enabled && !m.mirror)
    readonly property var selected: {
        for (let i = 0; i < monitors.length; i++)
            if (monitors[i].name === root.selectedName) return monitors[i]
        return null
    }

    signal closed()

    function close() {
        if (!root.confirming) root.closed()
    }

    // ── geometria do mapa ────────────────────────────────────────────────

    readonly property real spanLeft: placed.length ? Math.min(...placed.map(m => m.x)) : 0
    readonly property real spanTop: placed.length ? Math.min(...placed.map(m => m.y)) : 0
    readonly property real spanRight: placed.length
        ? Math.max(...placed.map(m => m.x + m.logicalWidth)) : 1920
    readonly property real spanBottom: placed.length
        ? Math.max(...placed.map(m => m.y + m.logicalHeight)) : 1080

    readonly property real mapScale: {
        const w = Math.max(1, spanRight - spanLeft)
        const h = Math.max(1, spanBottom - spanTop)
        const availableW = root.panelWidth - Theme.pad * 2 - root.mapPad * 2
        const availableH = root.mapHeight - root.mapPad * 2
        return Math.min(availableW / w, availableH / h)
    }
    readonly property real mapOffsetX:
        (root.panelWidth - Theme.pad * 2 - (spanRight - spanLeft) * mapScale) / 2
    readonly property real mapOffsetY:
        (root.mapHeight - (spanBottom - spanTop) * mapScale) / 2

    function toMapX(realX) { return mapOffsetX + (realX - spanLeft) * mapScale }
    function toMapY(realY) { return mapOffsetY + (realY - spanTop) * mapScale }
    function toRealX(mapX) { return Math.round((mapX - mapOffsetX) / mapScale + spanLeft) }
    function toRealY(mapY) { return Math.round((mapY - mapOffsetY) / mapScale + spanTop) }

    // Encaixa nas bordas das vizinhas: primeiro encosta lado a lado, depois
    // alinha os cantos. Sem isto o arraste quase nunca fecha o pixel certo.
    function snap(name, x, y, width, height) {
        let bestX = x
        let bestY = y
        let deltaX = root.snapDistance
        let deltaY = root.snapDistance

        for (const other of root.placed) {
            if (other.name === name) continue
            const candidatesX = [
                other.x + other.logicalWidth,      // encosta à direita da outra
                other.x - width,                   // encosta à esquerda
                other.x,                           // alinha pela esquerda
                other.x + other.logicalWidth - width
            ]
            for (const candidate of candidatesX) {
                const distance = Math.abs(candidate - x)
                if (distance < deltaX) { deltaX = distance; bestX = candidate }
            }
            const candidatesY = [
                other.y + other.logicalHeight,
                other.y - height,
                other.y,
                other.y + other.logicalHeight - height
            ]
            for (const candidate of candidatesY) {
                const distance = Math.abs(candidate - y)
                if (distance < deltaY) { deltaY = distance; bestY = candidate }
            }
        }
        return { "x": bestX, "y": bestY }
    }

    // ── escalas que dão pixel inteiro (mesma conta do monitor-layout) ────

    function validScales(width) {
        const result = []
        if (!width || width <= 0) return result
        for (let step = 120; step <= 360; step++) {
            const scale = step / 120
            if (Math.abs(width / scale - Math.round(width / scale)) < 1e-6)
                result.push(Math.round(scale * 10000) / 10000)
        }
        return result
    }

    function nativeWidth(monitor) {
        if (!monitor) return 0
        if (monitor.mode !== "preferred")
            return parseInt(monitor.mode.split("@")[0].split("x")[0])
        return monitor.current.width || monitor.logicalWidth
    }

    function formatScale(value) {
        return Math.round(value * 100) + "%"
    }

    // ── chamadas ao CLI ──────────────────────────────────────────────────

    function reload() {
        if (!loadProc.running) loadProc.running = true
    }

    function report(message, isError) {
        root.statusText = message
        root.statusIsError = isError === true
        statusTimer.restart()
    }

    // Aplica e salva já: usado por posição, que é reversível a olho nu.
    function applyNow(args) {
        if (root.busy || root.confirming) return
        root.busy = true
        setProc.needsConfirm = false
        setProc.command = [root.tool, "set"].concat(args)
        setProc.running = true
    }

    // Aplica e abre a contagem regressiva: modo, escala, rotação, ligar/desligar.
    function applyWithConfirm(args) {
        if (root.busy || root.confirming) return
        root.busy = true
        setProc.needsConfirm = true
        setProc.command = [root.tool, "set"].concat(args)
        setProc.running = true
    }

    function keep() {
        countdown.stop()
        root.confirming = false
        if (!commitProc.running) {
            root.busy = true
            commitProc.running = true
        }
    }

    function revert() {
        countdown.stop()
        root.confirming = false
        if (!revertProc.running) {
            root.busy = true
            revertProc.running = true
        }
    }

    function setPrimary(name) {
        if (root.busy || root.confirming) return
        root.busy = true
        primaryProc.command = [root.tool, "primary", name]
        primaryProc.running = true
    }

    function toggleMenubar() {
        if (root.busy || root.confirming) return
        root.busy = true
        menubarProc.command = [root.tool, "menubar",
                               root.menubarOnPrimary ? "false" : "true"]
        menubarProc.running = true
    }

    Process {
        id: loadProc
        command: [root.tool, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const view = JSON.parse(text)
                    root.monitors = view.monitors
                    root.primary = view.primary
                    root.menubarOnPrimary = view.menubar_on_primary
                    if (!root.selected && view.monitors.length > 0)
                        root.selectedName = view.monitors[0].name
                } catch (error) {
                    root.report("Não foi possível ler os monitores", true)
                }
            }
        }
    }

    Process {
        id: setProc
        property bool needsConfirm: false
        stdout: StdioCollector { }
        stderr: StdioCollector { id: setError }
        onExited: (code) => {
            root.busy = false
            if (code !== 0) {
                const message = setError.text.trim().replace(/^monitor-layout:\s*/, "")
                root.report(message || "O Hyprland recusou a mudança", true)
                root.reload()
                return
            }
            if (setProc.needsConfirm) {
                root.confirming = true
                root.secondsLeft = 15
                countdown.restart()
                root.reload()
            } else {
                root.busy = true
                commitProc.running = true
            }
        }
    }

    Process {
        id: commitProc
        command: [root.tool, "commit"]
        stdout: StdioCollector { }
        stderr: StdioCollector { id: commitError }
        onExited: (code) => {
            root.busy = false
            if (code !== 0)
                root.report(commitError.text.trim() || "Não foi possível salvar", true)
            else
                root.report("Configuração salva", false)
            root.reload()
        }
    }

    Process {
        id: revertProc
        command: [root.tool, "revert"]
        stdout: StdioCollector { }
        stderr: StdioCollector { }
        onExited: {
            root.busy = false
            root.report("Revertido para a última configuração salva", false)
            root.reload()
        }
    }

    Process {
        id: primaryProc
        stdout: StdioCollector { }
        stderr: StdioCollector { id: primaryError }
        onExited: (code) => {
            root.busy = false
            if (code !== 0)
                root.report(primaryError.text.trim() || "Não foi possível definir", true)
            else
                root.report("Menubar e dock migraram para o monitor principal", false)
            root.reload()
        }
    }

    Process {
        id: menubarProc
        stdout: StdioCollector { }
        stderr: StdioCollector { }
        onExited: {
            root.busy = false
            root.reload()
        }
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft -= 1
            if (root.secondsLeft <= 0) root.revert()
        }
    }

    Timer {
        id: statusTimer
        interval: 6000
        onTriggered: root.statusText = ""
    }

    Timer {
        id: closeArmTimer
        interval: 220
        onTriggered: root.closeArmed = true
    }

    // Só atualiza sozinho quando não há nada em curso, senão o mapa salta
    // debaixo do cursor no meio do arraste.
    Timer {
        running: root.open && !root.dragging && !root.confirming && !root.busy
        interval: 4000
        repeat: true
        onTriggered: root.reload()
    }

    onOpenChanged: {
        if (open) {
            root.closeArmed = false
            closeArmTimer.restart()
            root.statusText = ""
            root.reload()
        } else if (root.confirming) {
            root.revert()
        }
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "monitor-panel-catcher"
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
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.panelWidth + 16
        implicitHeight: Math.min(screen.height - 60, body.implicitHeight + 56)
        anchors { top: true; right: true }
        margins { top: 44; right: 8 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "monitor-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            MouseArea { anchors.fill: parent }

            // Pílula selecionável usada nos modos, escalas e rotações.
            component Chip: Rectangle {
                id: chip
                property string label: ""
                property bool selected: false
                property bool enabled: true
                signal picked()

                implicitWidth: chipText.implicitWidth + 20
                height: 28
                radius: 9
                opacity: chip.enabled ? 1 : 0.4
                color: chip.selected
                    ? Theme.accent
                    : (chipMouse.containsMouse ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.07))
                border.width: 1
                border.color: chip.selected ? Theme.accent : Theme.stroke

                Behavior on color { ColorAnimation { duration: Theme.anim } }

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.label
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: chip.enabled && !root.busy && !root.confirming
                    onClicked: chip.picked()
                }
            }

            // Rótulo à esquerda, conteúdo à direita.
            component Field: Item {
                property string label: ""
                default property alias content: holder.data

                width: parent ? parent.width : 0
                height: Math.max(30, holder.childrenRect.height)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    text: parent.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textDim
                }

                Item {
                    id: holder
                    anchors.left: parent.left
                    anchors.leftMargin: 78
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: childrenRect.height
                }
            }

            // Campo numérico de coordenada.
            component CoordInput: Rectangle {
                id: coord
                property string axis: "x"
                property int value: 0
                signal committed(int value)

                width: 78
                height: 28
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: coordInput.activeFocus ? Theme.accent : Theme.stroke

                TextInput {
                    id: coordInput
                    anchors.fill: parent
                    anchors.margins: 8
                    verticalAlignment: TextInput.AlignVCenter
                    text: coord.value.toString()
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    selectByMouse: true
                    validator: IntValidator { bottom: -32768; top: 32767 }
                    enabled: !root.busy && !root.confirming

                    // editingFinished também dispara ao perder o foco, então sem
                    // este sinalizador um valor velho no campo virava um commit.
                    property bool edited: false
                    onTextEdited: coordInput.edited = true
                    onEditingFinished: {
                        if (!coordInput.edited) {
                            coordInput.text = coord.value.toString()
                            return
                        }
                        coordInput.edited = false
                        const parsed = parseInt(coordInput.text)
                        if (!isNaN(parsed) && parsed !== coord.value)
                            coord.committed(parsed)
                        else
                            coordInput.text = coord.value.toString()
                    }
                }
            }

            Flickable {
                id: scroller
                anchors.fill: parent
                anchors.margins: Theme.pad
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

            Column {
                id: body
                width: scroller.width
                spacing: 12

                // ── cabeçalho ──
                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        text: "Monitores"
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        text: {
                            const active = root.monitors.filter(m => m.connected && m.enabled)
                            const suffix = root.primary ? " · principal: " + root.primary
                                                        : " · nenhuma principal definida"
                            return active.length + (active.length === 1 ? " tela ativa" : " telas ativas") + suffix
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }

                // ── mapa arrastável ──
                Rectangle {
                    width: parent.width
                    height: root.mapHeight
                    radius: Theme.radiusCard
                    color: Qt.rgba(0, 0, 0, 0.22)
                    border.width: 1
                    border.color: Theme.stroke
                    clip: true

                    Repeater {
                        model: root.placed

                        Rectangle {
                            id: screen
                            required property var modelData

                            x: root.toMapX(modelData.x)
                            y: root.toMapY(modelData.y)
                            width: Math.max(28, modelData.logicalWidth * root.mapScale)
                            height: Math.max(20, modelData.logicalHeight * root.mapScale)
                            radius: 8
                            color: modelData.name === root.selectedName
                                ? Qt.rgba(0.039, 0.518, 1, 0.30) : Theme.card
                            border.width: modelData.name === root.selectedName ? 2 : 1
                            border.color: modelData.name === root.selectedName
                                ? Theme.accent : Theme.stroke

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (modelData.primary ? "★ " : "") + modelData.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.logicalWidth + "×" + modelData.logicalHeight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                cursorShape: Qt.OpenHandCursor
                                enabled: !root.busy && !root.confirming
                                drag.target: screen
                                drag.threshold: 4

                                // Sem isto um clique simples — que só seleciona —
                                // também gravaria a posição, e com o retângulo
                                // ainda em animação a conta sai errada.
                                property bool moved: false
                                drag.onActiveChanged: if (drag.active) dragArea.moved = true

                                onPressed: {
                                    root.selectedName = screen.modelData.name
                                    root.dragging = true
                                    dragArea.moved = false
                                }
                                onReleased: {
                                    root.dragging = false
                                    if (!dragArea.moved) {
                                        root.reload()
                                        return
                                    }
                                    const target = root.snap(
                                        screen.modelData.name,
                                        root.toRealX(screen.x),
                                        root.toRealY(screen.y),
                                        screen.modelData.logicalWidth,
                                        screen.modelData.logicalHeight)
                                    if (target.x === screen.modelData.x
                                        && target.y === screen.modelData.y) {
                                        root.reload()   // devolve o retângulo ao lugar
                                        return
                                    }
                                    root.applyNow([screen.modelData.name,
                                                   "--x", target.x.toString(),
                                                   "--y", target.y.toString()])
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Arraste para posicionar · clique para ajustar"
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textDim
                }

                // ── faixa de confirmação ──
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: Theme.radiusCard
                    visible: root.confirming
                    color: Qt.rgba(1, 0.62, 0.04, 0.20)
                    border.width: 1
                    border.color: Theme.warning

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Manter esta configuração? (" + root.secondsLeft + ")"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Chip {
                            label: "Reverter"
                            enabled: true
                            onPicked: root.revert()
                        }
                        Chip {
                            label: "Manter"
                            selected: true
                            enabled: true
                            onPicked: root.keep()
                        }
                    }
                }

                // ── monitor selecionado ──
                Rectangle {
                    width: parent.width
                    height: detail.implicitHeight + 26
                    radius: Theme.radiusCard
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.stroke
                    visible: root.selected !== null

                    Column {
                        id: detail
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 13
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 8

                            Column {
                                width: parent.width - primaryChip.width - 8
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: root.selected ? root.selected.name : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: {
                                        if (!root.selected) return ""
                                        const info = root.selected
                                        if (!info.connected) return "desconectado"
                                        if (!info.enabled) return "desligado"
                                        return info.description || info.model
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: root.selected && !root.selected.enabled
                                        ? Theme.warning : Theme.textDim
                                    elide: Text.ElideRight
                                }
                            }

                            Chip {
                                id: primaryChip
                                anchors.verticalCenter: parent.verticalCenter
                                label: root.selected && root.selected.primary
                                    ? "★ Principal" : "Tornar principal"
                                selected: root.selected ? root.selected.primary : false
                                enabled: root.selected !== null
                                    && !root.selected.primary
                                    && root.selected.enabled
                                onPicked: root.setPrimary(root.selected.name)
                            }
                        }

                        // ── modo ──
                        Text {
                            text: "Resolução e taxa"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textDim
                        }

                        Flow {
                            id: modeFlow
                            width: parent.width
                            spacing: 6

                            Chip {
                                label: "Automático"
                                selected: root.selected
                                    ? root.selected.mode === "preferred" : false
                                onPicked: root.applyWithConfirm(
                                    [root.selected.name, "--mode", "preferred"])
                            }

                            Repeater {
                                model: root.selected ? root.selected.availableModes : []

                                Chip {
                                    required property string modelData
                                    label: modelData.replace("@", " · ").replace(/\.00$/, "") + "Hz"
                                    selected: root.selected
                                        ? root.selected.mode === modelData : false
                                    onPicked: root.applyWithConfirm(
                                        [root.selected.name, "--mode", modelData])
                                }
                            }
                        }

                        // ── escala ──
                        Field {
                            label: "Escala"

                            Row {
                                spacing: 6

                                Repeater {
                                    model: root.validScales(root.nativeWidth(root.selected))

                                    Chip {
                                        required property real modelData
                                        label: root.formatScale(modelData)
                                        selected: root.selected
                                            ? Math.abs(root.selected.scale - modelData) < 1e-4
                                            : false
                                        onPicked: root.applyWithConfirm(
                                            [root.selected.name, "--scale", modelData.toString()])
                                    }
                                }
                            }
                        }

                        // ── posição ──
                        Field {
                            label: "Posição"

                            Row {
                                spacing: 8

                                CoordInput {
                                    axis: "x"
                                    value: root.selected ? root.selected.x : 0
                                    onCommitted: (value) => root.applyNow(
                                        [root.selected.name, "--x", value.toString()])
                                }
                                CoordInput {
                                    axis: "y"
                                    value: root.selected ? root.selected.y : 0
                                    onCommitted: (value) => root.applyNow(
                                        [root.selected.name, "--y", value.toString()])
                                }
                            }
                        }

                        // ── rotação ──
                        Field {
                            label: "Rotação"

                            Row {
                                spacing: 6

                                Repeater {
                                    model: root.rotations

                                    Chip {
                                        required property var modelData
                                        label: modelData.label
                                        selected: root.selected
                                            ? root.selected.transform === modelData.value : false
                                        onPicked: root.applyWithConfirm(
                                            [root.selected.name,
                                             "--transform", modelData.value.toString()])
                                    }
                                }
                            }
                        }

                        // ── espelhar ──
                        Field {
                            label: "Espelhar"

                            Row {
                                spacing: 6

                                Chip {
                                    label: "Não"
                                    selected: root.selected ? root.selected.mirror === "" : true
                                    onPicked: root.applyWithConfirm(
                                        [root.selected.name, "--mirror", ""])
                                }

                                Repeater {
                                    model: root.monitors.filter(
                                        m => root.selected && m.name !== root.selected.name
                                             && m.connected && m.enabled)

                                    Chip {
                                        required property var modelData
                                        label: modelData.name
                                        selected: root.selected
                                            ? root.selected.mirror === modelData.name : false
                                        onPicked: root.applyWithConfirm(
                                            [root.selected.name, "--mirror", modelData.name])
                                    }
                                }
                            }
                        }

                        // ── VRR e energia da saída ──
                        Field {
                            label: "Saída"

                            Row {
                                spacing: 6

                                Chip {
                                    label: root.selected && root.selected.enabled
                                        ? "Ligada" : "Desligada"
                                    selected: root.selected ? root.selected.enabled : false
                                    enabled: root.selected !== null && root.selected.connected
                                    onPicked: root.applyWithConfirm(
                                        [root.selected.name,
                                         root.selected.enabled ? "--disable" : "--enable"])
                                }
                                Chip {
                                    label: "VRR"
                                    selected: root.selected ? root.selected.vrr : false
                                    enabled: root.selected !== null && root.selected.enabled
                                    onPicked: root.applyWithConfirm(
                                        [root.selected.name,
                                         root.selected.vrr ? "--no-vrr" : "--vrr"])
                                }
                            }
                        }
                    }
                }

                // ── menubar no principal ──
                Rectangle {
                    width: parent.width
                    height: 46
                    radius: Theme.radiusCard
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.stroke

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.right: menubarChip.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Menubar só no principal"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.text
                        }
                        Text {
                            width: parent.width
                            text: root.primary
                                ? "A dock já segue o monitor principal"
                                : "Defina um monitor principal primeiro"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                    }

                    Chip {
                        id: menubarChip
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        label: root.menubarOnPrimary ? "Ligado" : "Desligado"
                        selected: root.menubarOnPrimary
                        enabled: root.primary !== ""
                        onPicked: root.toggleMenubar()
                    }
                }

                Text {
                    width: parent.width
                    height: 16
                    text: root.statusText
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: root.statusIsError ? Theme.danger : Theme.textDim
                    elide: Text.ElideRight
                }
            }
            }
        }
    }
}
