import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Painel de rede. A maquina usa systemd-networkd numa conexao cabeada
// (sem Wi-Fi e sem Bluetooth), entao o painel detalha o enlace real:
// enderecos, rota, DNS e trafego ao vivo lido de /sys/class/net.
Scope {
    id: root

    property bool open: false
    property bool closeArmed: false

    property string iface: ""
    property string state: ""
    property string ip4: ""
    property string ip6: ""
    property string gateway: ""
    property string dns: ""
    property string mac: ""
    property int linkSpeed: 0
    property string duplex: ""

    property real rxRate: 0
    property real txRate: 0
    property real rxTotal: 0
    property real txTotal: 0
    property real prevRx: -1
    property real prevTx: -1

    readonly property int panelWidth: 380
    readonly property bool connected: state === "up" || state === "routable"
    // A NIC negocia abaixo de 1 Gb/s: quase sempre cabo ou porta do switch.
    readonly property bool slowLink: connected && linkSpeed > 0 && linkSpeed < 1000

    signal closed()

    function close() { root.closed() }

    function formatBytes(n) {
        if (!n || n < 1024) return Math.round(n || 0) + " B"
        const units = ["KB", "MB", "GB", "TB"]
        let v = n / 1024
        let i = 0
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
        return (v >= 100 ? Math.round(v) : v.toFixed(1)).toString().replace(".", ",")
            + " " + units[i]
    }

    function formatRate(n) { return root.formatBytes(n) + "/s" }

    FileView { id: rxFile; path: root.iface ? "/sys/class/net/" + root.iface + "/statistics/rx_bytes" : ""; blockLoading: true }
    FileView { id: txFile; path: root.iface ? "/sys/class/net/" + root.iface + "/statistics/tx_bytes" : ""; blockLoading: true }

    Process {
        id: infoProc
        command: ["sh", "-c",
            "IF=$(ip -o -4 route show default | awk '{print $5; exit}');" +
            "[ -z \"$IF\" ] && IF=$(ip -o link show up | awk -F': ' '$2!=\"lo\"{print $2; exit}');" +
            "echo \"iface=$IF\";" +
            "echo \"state=$(cat /sys/class/net/$IF/operstate 2>/dev/null)\";" +
            "echo \"ip=$(ip -o -4 addr show dev $IF 2>/dev/null | awk '{print $4; exit}')\";" +
            "echo \"ip6=$(ip -o -6 addr show dev $IF scope global 2>/dev/null | awk '{print $4; exit}')\";" +
            "echo \"gw=$(ip -o -4 route show default | awk '{print $3; exit}')\";" +
            "echo \"dns=$(resolvectl dns \"$IF\" 2>/dev/null | sed 's/.*: //' | tr '\\n' ' ' | sed 's/ *$//')\";" +
            "echo \"mac=$(cat /sys/class/net/$IF/address 2>/dev/null)\";" +
            "echo \"speed=$(cat /sys/class/net/$IF/speed 2>/dev/null)\";" +
            "echo \"duplex=$(cat /sys/class/net/$IF/duplex 2>/dev/null)\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) map[line.slice(0, i)] = line.slice(i + 1).trim()
                }
                root.iface = map["iface"] || ""
                root.state = map["state"] || ""
                root.ip4 = map["ip"] || ""
                root.ip6 = map["ip6"] || ""
                root.gateway = map["gw"] || ""
                root.dns = map["dns"] || ""
                root.mac = map["mac"] || ""
                root.linkSpeed = parseInt(map["speed"]) || 0
                root.duplex = map["duplex"] || ""
            }
        }
    }

    function sampleTraffic() {
        if (!root.iface) return
        rxFile.reload()
        txFile.reload()
        const rx = parseFloat(rxFile.text())
        const tx = parseFloat(txFile.text())
        if (isNaN(rx) || isNaN(tx)) return
        root.rxTotal = rx
        root.txTotal = tx
        if (root.prevRx >= 0) {
            // Contadores reiniciam se a interface cair; delta negativo vira zero.
            root.rxRate = Math.max(0, rx - root.prevRx)
            root.txRate = Math.max(0, tx - root.prevTx)
        }
        root.prevRx = rx
        root.prevTx = tx
    }

    Timer {
        running: root.open
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleTraffic()
    }

    Timer {
        running: root.open
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!infoProc.running) infoProc.running = true
    }

    onOpenChanged: {
        if (open) {
            root.closeArmed = false
            closeArmTimer.restart()
            root.prevRx = -1
            root.prevTx = -1
            root.rxRate = 0
            root.txRate = 0
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
        WlrLayershell.namespace: "network-panel-catcher"
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
        WlrLayershell.namespace: "network-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            MouseArea { anchors.fill: parent }

            // Par rotulo/valor das linhas de detalhe.
            component InfoRow: Item {
                property string label: ""
                property string value: ""
                property color tint: Theme.text

                width: parent ? parent.width : 0
                height: 22
                visible: value !== ""

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    text: parent.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textDim
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 78
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.value
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: parent.tint
                    elide: Text.ElideRight
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
                    text: "Rede"
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                // ── estado do enlace ──
                Rectangle {
                    width: parent.width
                    height: 58
                    radius: Theme.radiusCard
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.stroke

                    Rectangle {
                        id: statusDot
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.connected ? Theme.success : Theme.danger
                    }

                    Column {
                        anchors.left: statusDot.right
                        anchors.leftMargin: 11
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.iface || "sem interface"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            width: parent.width
                            text: {
                                if (!root.connected) return "desconectado"
                                let s = "Ethernet"
                                if (root.linkSpeed > 0)
                                    s += " · " + (root.linkSpeed >= 1000
                                                  ? (root.linkSpeed / 1000) + " Gb/s"
                                                  : root.linkSpeed + " Mb/s")
                                if (root.duplex) s += " " + root.duplex + " duplex"
                                return s
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: root.slowLink ? Theme.warning : Theme.textDim
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.slowLink
                    text: "Enlace abaixo de 1 Gb/s — normalmente cabo ou porta do switch."
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.warning
                }

                // ── trafego ──
                Row {
                    width: parent.width
                    spacing: Theme.gap

                    component TrafficBox: Rectangle {
                        property string glyph: ""
                        property string rate: ""
                        property string total: ""
                        property color tint: Theme.accent

                        height: 62
                        radius: Theme.radiusCard
                        color: Theme.card
                        border.width: 1
                        border.color: Theme.stroke

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.parent.glyph
                                    font.family: Theme.iconFamily
                                    font.pixelSize: 13
                                    color: parent.parent.parent.tint
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.parent.rate
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.total
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                            }
                        }
                    }

                    TrafficBox {
                        width: (parent.width - Theme.gap) / 2
                        glyph: "󰇚"
                        tint: Theme.success
                        rate: root.formatRate(root.rxRate)
                        total: root.formatBytes(root.rxTotal) + " recebidos"
                    }

                    TrafficBox {
                        width: (parent.width - Theme.gap) / 2
                        glyph: "󰕒"
                        tint: Theme.accent
                        rate: root.formatRate(root.txRate)
                        total: root.formatBytes(root.txTotal) + " enviados"
                    }
                }

                // ── enderecos ──
                Text {
                    text: "ENDEREÇO"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.DemiBold
                    color: Theme.textDim
                }

                Column {
                    width: parent.width
                    spacing: 1

                    InfoRow { label: "IPv4";    value: root.ip4 }
                    InfoRow { label: "IPv6";    value: root.ip6 }
                    InfoRow { label: "Gateway"; value: root.gateway }
                    InfoRow { label: "DNS";     value: root.dns }
                    InfoRow { label: "MAC";     value: root.mac; tint: Theme.textDim }
                }
            }
        }
    }
}
