import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Núcleo leve dos widgets de desktop: fica acima do wallpaper e abaixo das
// janelas normais. Não depende de API externa e lê os recursos direto do Linux.
Scope {
    id: root

    property bool shown: true

    // Emitido ao clicar no cartao de calendario; o shell abre o CalendarPanel.
    signal calendarClicked()

    // Emitido ao clicar no cartao de recursos; o shell abre o PowerPanel.
    signal powerClicked()
    property date now: new Date()
    property real cpuUsage: 0
    property real memoryUsage: 0
    property real diskUsage: 0
    property real previousCpuTotal: -1
    property real previousCpuIdle: -1

    readonly property int calendarYear: now.getFullYear()
    readonly property int calendarMonth: now.getMonth()
    readonly property int calendarToday: now.getDate()
    readonly property var weekDays: ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"]

    function capitalize(value) {
        return value.length > 0 ? value.charAt(0).toUpperCase() + value.slice(1) : value
    }

    function dayForCell(index) {
        const firstWeekDay = (new Date(root.calendarYear, root.calendarMonth, 1).getDay() + 6) % 7
        const day = index - firstWeekDay + 1
        const monthLength = new Date(root.calendarYear, root.calendarMonth + 1, 0).getDate()
        return day >= 1 && day <= monthLength ? day : 0
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    Process {
        id: statsProc
        command: ["sh", "-c",
            "head -1 /proc/stat; "
            + "awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {print t, a}' /proc/meminfo; "
            + "df -P / | awk 'NR==2 {gsub(/%/, \"\", $5); print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length < 3) return

                const cpu = lines[0].trim().split(/\s+/).slice(1).map(Number)
                const total = cpu.reduce((sum, value) => sum + value, 0)
                const idle = (cpu[3] || 0) + (cpu[4] || 0)
                if (root.previousCpuTotal >= 0 && total > root.previousCpuTotal) {
                    const totalDelta = total - root.previousCpuTotal
                    const idleDelta = idle - root.previousCpuIdle
                    root.cpuUsage = Math.max(0, Math.min(1, (totalDelta - idleDelta) / totalDelta))
                }
                root.previousCpuTotal = total
                root.previousCpuIdle = idle

                const memory = lines[1].trim().split(/\s+/).map(Number)
                if (memory.length >= 2 && memory[0] > 0)
                    root.memoryUsage = Math.max(0, Math.min(1, 1 - memory[1] / memory[0]))

                root.diskUsage = Math.max(0, Math.min(1, Number(lines[2]) / 100))
            }
        }
    }

    component GlassCard: Rectangle {
        radius: 26
        color: Qt.rgba(0.07, 0.07, 0.085, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 25
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.045)
        }
    }

    component ResourceRow: Item {
        id: resourceRow
        property string glyph: ""
        property string label: ""
        property real value: 0
        property color accent: Theme.accent

        implicitHeight: 42

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            text: resourceRow.glyph
            font.family: Theme.iconFamily
            font.pixelSize: 16
            color: resourceRow.accent
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: valueLabel.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                text: resourceRow.label
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.textDim
            }

            Rectangle {
                width: parent.width
                height: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.09)

                Rectangle {
                    width: parent.width * resourceRow.value
                    height: parent.height
                    radius: parent.radius
                    color: resourceRow.accent

                    Behavior on width {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Text {
            id: valueLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(resourceRow.value * 100) + "%"
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }

    PanelWindow {
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 928
        implicitHeight: 210
        anchors { left: true; bottom: true }
        margins {
            left: Math.max(24, (screen.width - implicitWidth) / 2)
            // Reserva a área do dock central para os cartões não se sobreporem.
            bottom: 96
        }
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "desktop-widgets"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 14

            GlassCard {
                width: 250
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 3

                    Item {
                        width: parent.width
                        height: 24

                        Text {
                            text: "󰥔"
                            font.family: Theme.iconFamily
                            font.pixelSize: 16
                            color: Theme.accent
                        }
                        Text {
                            anchors.right: parent.right
                            text: "AGORA"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.textDim
                        }
                    }

                    Text {
                        text: Qt.locale("pt_BR").toString(root.now, "HH:mm")
                        font.family: Theme.fontFamily
                        font.pixelSize: 54
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.capitalize(Qt.locale("pt_BR").toString(root.now, "dddd"))
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: Qt.locale("pt_BR").toString(root.now, "d 'de' MMMM 'de' yyyy")
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }
            }

            GlassCard {
                width: 300
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 1

                    Text {
                        text: "Recursos"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    ResourceRow {
                        width: parent.width
                        glyph: "󰍛"
                        label: "CPU"
                        value: root.cpuUsage
                        accent: Theme.accent
                    }
                    ResourceRow {
                        width: parent.width
                        glyph: "󰘚"
                        label: "Memória"
                        value: root.memoryUsage
                        accent: Theme.success
                    }
                    ResourceRow {
                        width: parent.width
                        glyph: "󰋊"
                        label: "Disco"
                        value: root.diskUsage
                        accent: Theme.warning
                    }
                }

                // Abre o painel de energia (PowerPanel).
                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    color: powerArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.powerClicked()
                }
            }

            GlassCard {
                width: 330
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 5

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.capitalize(Qt.locale("pt_BR").toString(root.now, "MMMM yyyy"))
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Grid {
                        width: parent.width
                        columns: 7

                        Repeater {
                            model: root.weekDays
                            delegate: Text {
                                required property string modelData
                                width: 42
                                height: 19
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Theme.textDim
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 7

                        Repeater {
                            model: 42
                            delegate: Item {
                                required property int index
                                width: 42
                                height: 21
                                readonly property int cellDay: root.dayForCell(index)

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 25
                                    height: 21
                                    radius: 9
                                    visible: parent.cellDay === root.calendarToday
                                    color: Theme.accent
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.cellDay > 0
                                    text: parent.cellDay
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: parent.cellDay === root.calendarToday
                                        ? Font.DemiBold : Font.Normal
                                    color: Theme.text
                                }
                            }
                        }
                    }
                }

                // Abre o calendario navegavel (CalendarPanel).
                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    color: calendarArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                MouseArea {
                    id: calendarArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.calendarClicked()
                }
            }
        }
    }
}
