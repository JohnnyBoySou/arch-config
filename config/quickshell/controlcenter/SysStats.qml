import QtQuick
import Quickshell.Io

// Rodapé: CPU, memória, disco e tempo ligado — lidos de /proc e do df
Card {
    id: root

    property real cpu: 0
    property real mem: 0
    property string disk: "--"
    property string uptime: "--"

    // estado anterior de /proc/stat para calcular o delta
    property real prevIdle: 0
    property real prevTotal: 0

    implicitHeight: Theme.statsHeight

    FileView { id: statFile;   path: "/proc/stat";    blockLoading: true }
    FileView { id: memFile;    path: "/proc/meminfo"; blockLoading: true }
    FileView { id: uptimeFile; path: "/proc/uptime";  blockLoading: true }

    Process {
        id: dfProc
        command: ["sh", "-c", "df -h --output=pcent / | tail -1 | tr -d ' %'"]
        stdout: StdioCollector {
            onStreamFinished: root.disk = text.trim() + "%"
        }
    }

    function refresh() {
        // ── CPU: delta de jiffies ociosos vs. totais ──
        statFile.reload()
        const cpuLine = statFile.text().split("\n")[0].trim().split(/\s+/)
        if (cpuLine.length > 4) {
            let total = 0
            for (let i = 1; i < cpuLine.length; i++)
                total += parseFloat(cpuLine[i])
            const idle = parseFloat(cpuLine[4]) + parseFloat(cpuLine[5] || 0)

            const dTotal = total - root.prevTotal
            const dIdle = idle - root.prevIdle
            if (root.prevTotal > 0 && dTotal > 0)
                root.cpu = Math.max(0, Math.min(100, 100 * (1 - dIdle / dTotal)))

            root.prevTotal = total
            root.prevIdle = idle
        }

        // ── memória ──
        memFile.reload()
        const mm = memFile.text()
        const grab = (key) => {
            const m = mm.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"))
            return m ? parseFloat(m[1]) : 0
        }
        const totalKb = grab("MemTotal")
        const availKb = grab("MemAvailable")
        if (totalKb > 0)
            root.mem = 100 * (1 - availKb / totalKb)

        // ── tempo ligado ──
        uptimeFile.reload()
        const secs = parseFloat(uptimeFile.text().split(" ")[0])
        const d = Math.floor(secs / 86400)
        const h = Math.floor((secs % 86400) / 3600)
        const m = Math.floor((secs % 3600) / 60)
        root.uptime = d > 0 ? (d + "d " + h + "h") : (h > 0 ? (h + "h " + m + "min") : (m + "min"))

        dfProc.running = true
    }

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.cardPad

        Repeater {
            model: [
                { glyph: "󰘚", label: "CPU",    value: Math.round(root.cpu) + "%" },
                { glyph: "󰍛", label: "Memória", value: Math.round(root.mem) + "%" },
                { glyph: "󰋊", label: "Disco",   value: root.disk },
                { glyph: "󰅐", label: "Ligado",  value: root.uptime }
            ]

            Column {
                required property var modelData
                width: root.width / 4 - 5
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.glyph
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.iconSize
                    color: Theme.textDim
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.value
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }
        }
    }
}
