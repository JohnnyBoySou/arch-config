import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Painel de energia. A maquina e um desktop: nao ha bateria de sistema nem
// backlight interno, entao o painel mostra o que de fato existe — perfil/governor,
// temperaturas, frequencia, brilho por DDC/CI e baterias de perifericos.
// As secoes de perfil e brilho so aparecem se as ferramentas estiverem instaladas.
Scope {
    id: root

    property bool open: false
    property bool closeArmed: false

    property bool hasProfiles: false
    property bool hasDdc: false
    property string profile: ""
    property var profiles: []
    property string governor: ""
    property var governors: []
    property int cores: 0
    property int freqMhz: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int nvmeTemp: 0
    property var batteries: []

    property int brightness: -1
    property int pendingBrightness: -1

    readonly property int panelWidth: 380

    signal closed()

    function close() { root.closed() }

    function tempColor(t) {
        if (t <= 0) return Theme.textDim
        if (t < 60) return Theme.success
        if (t < 80) return Theme.warning
        return Theme.danger
    }

    function profileLabel(p) {
        if (p === "power-saver") return "Economia"
        if (p === "balanced") return "Equilibrado"
        if (p === "performance") return "Desempenho"
        return p
    }

    function batteryLabel(level) {
        const map = {
            "Full": "Cheia", "High": "Alta", "Normal": "Normal",
            "Low": "Baixa", "Critical": "Crítica", "Unknown": "Desconhecida"
        }
        return map[level] || level
    }

    function batteryColor(level) {
        if (level === "Low") return Theme.warning
        if (level === "Critical") return Theme.danger
        return Theme.success
    }

    Process {
        id: pollProc
        command: ["sh", "-c",
            "command -v powerprofilesctl >/dev/null 2>&1 && echo ppd=1 || echo ppd=0;" +
            "if command -v powerprofilesctl >/dev/null 2>&1; then" +
            "  echo \"profile=$(powerprofilesctl get 2>/dev/null)\";" +
            "  echo \"profiles=$(powerprofilesctl list 2>/dev/null | sed -n 's/^[ *]*\\([a-z-]*\\):$/\\1/p' | tr '\\n' ' ')\";" +
            "fi;" +
            "command -v ddcutil >/dev/null 2>&1 && echo ddc=1 || echo ddc=0;" +
            "echo \"governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)\";" +
            "echo \"governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)\";" +
            "echo \"cores=$(nproc)\";" +
            "tot=0; n=0;" +
            "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do" +
            "  [ -r \"$f\" ] || continue; v=$(cat \"$f\"); tot=$((tot+v)); n=$((n+1));" +
            "done;" +
            "[ \"$n\" -gt 0 ] && echo \"freq=$((tot/n/1000))\";" +
            "for h in /sys/class/hwmon/hwmon*; do" +
            "  nm=$(cat \"$h/name\" 2>/dev/null);" +
            "  [ -r \"$h/temp1_input\" ] || continue;" +
            "  t=$(awk '{printf \"%.0f\", $1/1000}' \"$h/temp1_input\" 2>/dev/null);" +
            "  case \"$nm\" in" +
            "    k10temp|coretemp) echo \"cpu_temp=$t\" ;;" +
            "    amdgpu)           echo \"gpu_temp=$t\" ;;" +
            "    nvme)             echo \"nvme_temp=$t\" ;;" +
            "  esac;" +
            "done;" +
            "for b in /sys/class/power_supply/*; do" +
            "  [ -r \"$b/model_name\" ] || continue;" +
            "  echo \"bat=$(cat \"$b/model_name\" 2>/dev/null | tr -s ' ')|$(cat \"$b/capacity_level\" 2>/dev/null)|$(cat \"$b/status\" 2>/dev/null)\";" +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const bats = []
                let gpu = 0
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i <= 0) continue
                    const k = line.slice(0, i)
                    const v = line.slice(i + 1).trim()
                    if (k === "ppd") root.hasProfiles = v === "1"
                    else if (k === "ddc") root.hasDdc = v === "1"
                    else if (k === "profile") root.profile = v
                    else if (k === "profiles") root.profiles = v.split(/\s+/).filter(x => x)
                    else if (k === "governor") root.governor = v
                    else if (k === "governors") root.governors = v.split(/\s+/).filter(x => x)
                    else if (k === "cores") root.cores = parseInt(v) || 0
                    else if (k === "freq") root.freqMhz = parseInt(v) || 0
                    else if (k === "cpu_temp") root.cpuTemp = parseInt(v) || 0
                    // Ha duas GPUs (dedicada e integrada): vale a mais quente.
                    else if (k === "gpu_temp") gpu = Math.max(gpu, parseInt(v) || 0)
                    else if (k === "nvme_temp") root.nvmeTemp = parseInt(v) || 0
                    else if (k === "bat") {
                        const p = v.split("|")
                        if (p[0]) bats.push({ name: p[0].trim(), level: p[1] || "", status: p[2] || "" })
                    }
                }
                root.gpuTemp = gpu
                root.batteries = bats
                if (root.hasDdc && root.brightness < 0 && !brightnessReadProc.running)
                    brightnessReadProc.running = true
            }
        }
    }

    Process {
        id: profileProc
        onExited: pollProc.running = true
    }

    // Leitura do brilho pelo barramento I2C: lenta, so uma vez ao abrir.
    Process {
        id: brightnessReadProc
        command: ["sh", "-c", "ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim())
                if (!isNaN(v)) root.brightness = v
            }
        }
    }

    Process { id: brightnessWriteProc }

    // Arrastar o slider dispara muitas escritas; o I2C nao acompanha.
    Timer {
        id: brightnessDebounce
        interval: 260
        onTriggered: {
            if (root.pendingBrightness < 0 || brightnessWriteProc.running) return
            brightnessWriteProc.command = ["ddcutil", "setvcp", "10",
                                           root.pendingBrightness.toString()]
            brightnessWriteProc.running = true
            root.pendingBrightness = -1
        }
    }

    function setProfile(p) {
        if (profileProc.running) return
        profileProc.command = ["powerprofilesctl", "set", p]
        profileProc.running = true
    }

    Timer {
        running: root.open
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }

    onOpenChanged: {
        if (open) {
            root.closeArmed = false
            closeArmTimer.restart()
        }
    }

    Timer {
        id: closeArmTimer
        interval: 220
        onTriggered: root.closeArmed = true
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "power-panel-catcher"
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
        id: panelWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.panelWidth + 16
        implicitHeight: body.implicitHeight + 56
        anchors { top: true; right: true }
        margins { top: 44; right: 8 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "power-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            MouseArea { anchors.fill: parent }

            component SectionTitle: Text {
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
                color: Theme.textDim
            }

            // Linha de temperatura com barra proporcional (0–100 °C).
            component TempRow: Item {
                property string label: ""
                property int value: 0

                width: parent ? parent.width : 0
                height: 30
                visible: value > 0

                Text {
                    id: tempLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 58
                    text: parent.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textDim
                }

                Rectangle {
                    anchors.left: tempLabel.right
                    anchors.right: tempValue.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    radius: 2.5
                    color: Qt.rgba(1, 1, 1, 0.10)

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, parent.parent.value / 100))
                        color: root.tempColor(parent.parent.value)
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }

                Text {
                    id: tempValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: parent.value + " °C"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.DemiBold
                    color: root.tempColor(parent.value)
                }
            }

            Column {
                id: body
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.pad
                spacing: 14

                Text {
                    text: "Energia"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                // ── perfil de energia ──
                SectionTitle { text: "PERFIL" }

                Row {
                    width: parent.width
                    spacing: 6
                    visible: root.hasProfiles

                    Repeater {
                        model: root.profiles

                        Rectangle {
                            required property string modelData
                            readonly property bool selected: modelData === root.profile

                            width: root.profiles.length > 0
                                   ? (parent.width - 6 * (root.profiles.length - 1)) / root.profiles.length
                                   : 0
                            height: 34
                            radius: 10
                            color: selected ? Qt.rgba(0.039, 0.518, 1.0, 0.32)
                                            : (profArea.containsMouse ? Theme.cardHover : Theme.card)
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.stroke

                            Text {
                                anchors.centerIn: parent
                                text: root.profileLabel(parent.modelData)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                color: parent.selected ? Theme.text : Theme.textDim
                            }

                            MouseArea {
                                id: profArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setProfile(parent.modelData)
                            }
                        }
                    }
                }

                // Sem o daemon, o governor e so leitura: escrever em
                // scaling_governor exige root.
                Column {
                    width: parent.width
                    spacing: 4
                    visible: !root.hasProfiles

                    Text {
                        width: parent.width
                        text: "Governor: " + (root.governor || "—")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.text
                    }

                    Text {
                        width: parent.width
                        text: "Instale power-profiles-daemon para trocar de perfil por aqui."
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }

                // ── processador ──
                SectionTitle { text: "PROCESSADOR" }

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: Theme.radiusCard
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.stroke

                    Row {
                        anchors.centerIn: parent
                        spacing: 26

                        Column {
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.freqMhz >= 1000
                                      ? (root.freqMhz / 1000).toFixed(2).replace(".", ",") + " GHz"
                                      : root.freqMhz + " MHz"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "frequência média"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }

                        Column {
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.cores
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "threads"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }
                    }
                }

                // ── temperaturas ──
                SectionTitle { text: "TEMPERATURA" }

                Column {
                    width: parent.width
                    spacing: 0

                    TempRow { label: "CPU";  value: root.cpuTemp }
                    TempRow { label: "GPU";  value: root.gpuTemp }
                    TempRow { label: "NVMe"; value: root.nvmeTemp }
                }

                // ── brilho ──
                SectionTitle {
                    text: "BRILHO"
                    visible: root.hasDdc
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.hasDdc

                    SliderRow {
                        width: parent.width
                        icon: "󰃟"
                        fill: Theme.warning
                        value: root.brightness >= 0 ? root.brightness / 100 : 0
                        onMoved: (v) => {
                            root.brightness = Math.round(Math.max(0, Math.min(1, v)) * 100)
                            root.pendingBrightness = root.brightness
                            brightnessDebounce.restart()
                        }
                    }

                    Text {
                        text: root.brightness >= 0
                              ? root.brightness + "%  ·  via DDC/CI"
                              : "lendo do monitor…"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }

                Text {
                    width: parent.width
                    visible: !root.hasDdc
                    text: "Brilho: instale ddcutil e carregue o módulo i2c-dev para controlar o monitor por DDC/CI."
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }

                // ── perifericos ──
                SectionTitle {
                    text: "PERIFÉRICOS"
                    visible: root.batteries.length > 0
                }

                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.batteries.length > 0

                    Repeater {
                        model: root.batteries

                        Item {
                            required property var modelData
                            width: parent ? parent.width : 0
                            height: 22

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: levelText.left
                                anchors.rightMargin: 10
                                text: parent.modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            // O driver HID++ so expoe faixa, nao porcentagem:
                            // mostrar um numero aqui seria inventar precisao.
                            Text {
                                id: levelText
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.batteryLabel(parent.modelData.level)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.DemiBold
                                color: root.batteryColor(parent.modelData.level)
                            }
                        }
                    }
                }
            }
        }
    }
}
