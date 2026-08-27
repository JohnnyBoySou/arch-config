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

    // ── controle externo (menubar Waybar / atalho de teclado) ──
    IpcHandler {
        target: "cc"

        function toggle(): void { root.open = !root.open }
        function show(): void   { root.open = true }
        function hide(): void   { root.open = false }
    }

    // ── áudio: acompanha a saída padrão do PipeWire ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink

    // ── estado de rede e Não Perturbe ──
    property string netIface: "--"
    property string netAddr: ""
    property bool netUp: false
    property bool dnd: false

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

    Process { id: runner }
    function run(cmd) {
        runner.command = ["sh", "-c", cmd]
        runner.running = true
    }

    function refreshState() {
        netProc.running = true
        dndProc.running = true
    }

    onOpenChanged: if (open) refreshState()

    Timer {
        interval: 5000
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

                // ── linha de ladrilhos ──
                Row {
                    width: parent.width
                    spacing: Theme.gap

                    Tile {
                        width: (parent.width - Theme.gap) / 2
                        icon: root.netUp ? "󰈀" : "󰤭"
                        label: "Rede"
                        sublabel: root.netUp ? root.netAddr : "Desconectado"
                        active: root.netUp
                        onToggled: root.run("nm-connection-editor || pavucontrol")
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

                // ── volume ──
                SliderRow {
                    width: parent.width
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
                        width: parent.width / 4
                        icon: "󰌾"; label: "Bloquear"
                        onActivated: { root.open = false; root.run("hyprlock") }
                    }
                    ActionButton {
                        width: parent.width / 4
                        icon: "󰤄"; label: "Suspender"
                        onActivated: { root.open = false; root.run("systemctl suspend") }
                    }
                    ActionButton {
                        width: parent.width / 4
                        icon: "󰒓"; label: "Ajustes"
                        onActivated: { root.open = false; root.run("nwg-look") }
                    }
                    ActionButton {
                        width: parent.width / 4
                        icon: "󰐥"; label: "Energia"
                        hoverColor: Qt.rgba(1, 0.27, 0.23, 0.35)
                        onActivated: { root.open = false; root.run("/home/sousa/.local/bin/power-menu") }
                    }
                }
            }
        }
    }
}
