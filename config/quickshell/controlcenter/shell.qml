//  Centro de Controle — Quickshell
//  Abre/fecha com:  qs -c controlcenter ipc call cc toggle
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    property bool open: false
    property bool wallpaperOpen: false
    property bool workspaceEditorOpen: false
    property bool appearanceOpen: false
    property bool desktopWidgetsVisible: true

    // ── controle externo (menubar Waybar / atalho de teclado) ──
    IpcHandler {
        target: "cc"

        function toggle(): void { root.open = !root.open }
        function show(): void   { root.open = true }
        function hide(): void   { root.open = false }
    }

    IpcHandler {
        target: "wallpapers"

        function toggle(): void { root.wallpaperOpen = !root.wallpaperOpen }
    }

    IpcHandler {
        target: "workspaceeditor"

        function toggle(): void { root.workspaceEditorOpen = !root.workspaceEditorOpen }
        function openEditor(): void { root.workspaceEditorOpen = true }
        function show(): void { root.workspaceEditorOpen = true }
        function hide(): void { root.workspaceEditorOpen = false }
    }

    IpcHandler {
        target: "desktopwidgets"

        function toggle(): void { root.desktopWidgetsVisible = !root.desktopWidgetsVisible }
        function show(): void { root.desktopWidgetsVisible = true }
        function hide(): void { root.desktopWidgetsVisible = false }
    }

    IpcHandler {
        target: "appearance"

        function toggle(): void { root.appearanceOpen = !root.appearanceOpen }
        function openPanel(): void { root.appearanceOpen = true }
        function closePanel(): void { root.appearanceOpen = false }
    }

    WallpaperGallery {
        open: root.wallpaperOpen
        onClosed: root.wallpaperOpen = false
    }

    WorkspaceEditor {
        open: root.workspaceEditorOpen
        onClosed: root.workspaceEditorOpen = false
    }

    DesktopWidgets {
        shown: root.desktopWidgetsVisible
    }

    AppearanceSettings {
        open: root.appearanceOpen
        onClosed: root.appearanceOpen = false
    }

    // ── áudio: acompanha a saída padrão do PipeWire ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // ── estado de rede e Não Perturbe ──
    property string netIface: "--"
    property string netAddr: ""
    property bool netUp: false
    property bool dnd: false
    property bool gameMode: false
    property bool recording: false

    Process {
        id: netProc
        command: ["sh", "-c",
            "ip -br -4 addr show scope global up 2>/dev/null | grep -v '^lo' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 3) {
                    root.netUp = true
                    root.netIface = parts[0]
                    root.netAddr = parts[2].split("/")[0]
                } else {
                    root.netUp = false
                    root.netIface = "Desconectado"
                    root.netAddr = ""
                }
            }
        }
    }

    Process {
        id: dndProc
        command: ["swaync-client", "-D"]
        stdout: StdioCollector {
            onStreamFinished: root.dnd = text.trim() === "true"
        }
    }

    Process {
        id: gameModeProc
        command: ["sh", "-c",
            "hyprctl getoption animations:enabled -j 2>/dev/null | grep -q '\"int\": 0' && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: root.gameMode = text.trim() === "true"
        }
    }

    Process {
        id: recordingProc
        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null && echo true || echo false"]
        stdout: StdioCollector {
            onStreamFinished: root.recording = text.trim() === "true"
        }
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function toggleGameMode() {
        if (root.gameMode) {
            root.run("hyprctl reload")
            root.gameMode = false
        } else {
            root.run("hyprctl --batch \"keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:allow_tearing 1\"")
            root.gameMode = true
        }
    }

    function refreshState() {
        if (!netProc.running) netProc.running = true
        if (!dndProc.running) dndProc.running = true
        if (!gameModeProc.running) gameModeProc.running = true
        if (!recordingProc.running) recordingProc.running = true
    }

    onOpenChanged: if (open) refreshState()

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        onTriggered: root.refreshState()
    }

    // ── camada invisível que fecha o painel ao clicar fora ──
    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "cc-catcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.open = false
        }
    }

    // ── o painel ──
    PanelWindow {
        id: panel
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: 4; right: 8 }
        implicitWidth: Theme.panelWidth
        implicitHeight: content.implicitHeight + Theme.pad * 2
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "controlcenter"

        Rectangle {
            id: shell
            anchors.fill: parent
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            // animação de entrada, no estilo do macOS
            opacity: root.open ? 1 : 0
            transform: Translate { y: root.open ? 0 : -8 }

            Behavior on opacity {
                NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
            }

            Column {
                id: content
                // ancorar só no topo/laterais: a altura do painel deriva do
                // implicitHeight desta coluna, então anchors.fill seria circular
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.pad
                spacing: Theme.gap

                Row {
                    width: parent.width
                    height: 36

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - settingsButton.width
                        spacing: 1

                        Text {
                            text: "Centro de Controle"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            text: "Controles rápidos do sistema"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                        }
                    }

                    Rectangle {
                        id: settingsButton
                        width: 36
                        height: 36
                        radius: 14
                        color: settingsMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.width: 1
                        border.color: Theme.stroke

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.family: Theme.iconFamily
                            font.pixelSize: 17
                            color: Theme.text
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.open = false
                                root.appearanceOpen = true
                            }
                        }
                    }
                }

                // ── linha de ladrilhos ──
                Row {
                    width: parent.width
                    spacing: Theme.gap

                    Tile {
                        width: (parent.width - Theme.gap) / 2
                        icon: root.netUp ? "󰈀" : "󰤭"
                        label: "Rede"
                        sublabel: root.netUp ? (root.netIface + " · " + root.netAddr) : "Desconectado"
                        active: root.netUp
                        interactive: false
                    }

                    Tile {
                        width: (parent.width - Theme.gap) / 2
                        icon: root.dnd ? "󰂛" : "󰂚"
                        label: "Não Perturbe"
                        sublabel: root.dnd ? "Silenciado" : "Ativo"
                        active: root.dnd
                        activeColor: Theme.warning
                        onToggled: {
                            root.dnd = !root.dnd
                            root.run("swaync-client -d -sw")
                        }
                    }
                }

                // ── ações rápidas próprias deste desktop ──
                Row {
                    width: parent.width
                    spacing: Theme.gap

                    Tile {
                        width: (parent.width - Theme.gap) / 2
                        icon: root.gameMode ? "󰊴" : "󰍹"
                        label: "Modo Jogo"
                        sublabel: root.gameMode ? "Efeitos reduzidos" : "Visual completo"
                        active: root.gameMode
                        activeColor: Theme.success
                        onToggled: root.toggleGameMode()
                    }

                    Tile {
                        width: (parent.width - Theme.gap) / 2
                        icon: "󰸉"
                        label: "Wallpaper"
                        sublabel: "Abrir galeria"
                        onToggled: {
                            root.open = false
                            root.wallpaperOpen = true
                        }
                    }
                }

                // ── saída e entrada PipeWire ──
                LabeledSlider {
                    width: parent.width
                    label: "Saída"
                    detail: root.sink ? (root.sink.description || root.sink.nickname || "") : "Indisponível"
                    icon: {
                        if (!root.sink || !root.sink.audio) return "󰕿"
                        if (root.sink.audio.muted) return "󰝟"
                        const v = root.sink.audio.volume
                        return v < 0.01 ? "󰕿" : (v < 0.5 ? "󰖀" : "󰕾")
                    }
                    value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                    muted: root.sink && root.sink.audio ? root.sink.audio.muted : false
                    onMoved: (v) => {
                        if (root.sink && root.sink.audio) {
                            root.sink.audio.muted = false
                            root.sink.audio.volume = v
                        }
                    }
                    onIconClicked: {
                        if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted
                    }
                }

                LabeledSlider {
                    width: parent.width
                    label: "Microfone"
                    detail: root.source ? (root.source.description || root.source.nickname || "") : "Indisponível"
                    icon: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
                    value: root.source && root.source.audio ? root.source.audio.volume : 0
                    muted: root.source && root.source.audio ? root.source.audio.muted : true
                    fill: Theme.accent
                    onMoved: (v) => {
                        if (root.source && root.source.audio) {
                            root.source.audio.muted = false
                            root.source.audio.volume = v
                        }
                    }
                    onIconClicked: {
                        if (root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted
                    }
                }

                AudioDevices { width: parent.width }

                // ── tocando agora ──
                MediaCard { width: parent.width }

                // ── estatísticas ──
                SysStats {
                    width: parent.width
                    visible: root.open
                }

                // ── ações ──
                Row {
                    width: parent.width

                    ActionButton {
                        width: parent.width / 5
                        icon: "󰄀"; label: "Capturar"
                        onActivated: {
                            root.open = false
                            root.run("sleep 0.2; $HOME/.local/bin/screenshot region")
                        }
                    }
                    ActionButton {
                        width: parent.width / 5
                        icon: root.recording ? "󰓛" : "󰑋"
                        label: root.recording ? "Parar" : "Gravar"
                        backgroundColor: root.recording ? Qt.rgba(1, 0.27, 0.23, 0.32) : Theme.card
                        iconColor: root.recording ? Theme.danger : Theme.text
                        hoverColor: Qt.rgba(1, 0.27, 0.23, 0.42)
                        onActivated: {
                            root.open = false
                            root.run("$HOME/.local/bin/screenrecord region")
                        }
                    }
                    ActionButton {
                        width: parent.width / 5
                        icon: "󰕮"; label: "Widgets"
                        backgroundColor: root.desktopWidgetsVisible
                            ? Qt.rgba(0.039, 0.518, 1, 0.30) : Theme.card
                        iconColor: root.desktopWidgetsVisible ? Theme.accent : Theme.text
                        onActivated: root.desktopWidgetsVisible = !root.desktopWidgetsVisible
                    }
                    ActionButton {
                        width: parent.width / 5
                        icon: "󰌾"; label: "Bloquear"
                        onActivated: { root.open = false; root.run("hyprlock") }
                    }
                    ActionButton {
                        width: parent.width / 5
                        icon: "󰐥"; label: "Energia"
                        hoverColor: Qt.rgba(1, 0.27, 0.23, 0.35)
                        onActivated: { root.open = false; root.run("/home/sousa/.local/bin/power-menu") }
                    }
                }
            }
        }
    }
}
