import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Central de som — substitui o pavucontrol.
// Saida, entrada e volume por aplicativo, com medidor de nivel ao vivo.
Scope {
    id: root

    property bool open: false
    property bool closeArmed: false

    readonly property int panelWidth: 400
    readonly property int panelRight: 8
    readonly property int panelTop: 44

    signal closed()

    function close() { root.closed() }

    // Mantem os volumes de todos os nos sincronizados, nao so os padrao.
    PwObjectTracker { objects: Pipewire.nodes.values }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property var sinks: Pipewire.nodes.values.filter(n =>
        n && n.ready && n.isSink && !n.isStream && n.audio)

    readonly property var sources: Pipewire.nodes.values.filter(n =>
        n && n.ready && !n.isSink && !n.isStream && n.audio
        && n.properties && n.properties["media.class"] === "Audio/Source")

    // media.class distingue reproducao de gravacao sem ambiguidade.
    readonly property var playbackStreams: Pipewire.nodes.values.filter(n =>
        n && n.ready && n.isStream && n.audio
        && n.properties && n.properties["media.class"] === "Stream/Output/Audio")

    readonly property var recordStreams: Pipewire.nodes.values.filter(n =>
        n && n.ready && n.isStream && n.audio
        && n.properties && n.properties["media.class"] === "Stream/Input/Audio")

    function labelFor(node) {
        if (!node) return "Indisponível"
        return node.description || node.nickname || node.name || "Desconhecido"
    }

    function appLabel(node) {
        if (!node) return ""
        const p = node.properties || ({})
        return p["application.name"] || node.description || node.name || "Aplicativo"
    }

    function appIconName(node) {
        const p = (node && node.properties) || ({})
        return p["application.icon_name"] || p["application.process.binary"] || ""
    }

    // Icone por tipo de dispositivo, deduzido do nome do no do PipeWire.
    function deviceGlyph(node) {
        const n = ((node && node.name) || "").toLowerCase()
        if (n.indexOf("hdmi") >= 0 || n.indexOf("displayport") >= 0) return "󰍹"
        if (n.indexOf("usb") >= 0) return "󰋋"
        if (n.indexOf("bluez") >= 0) return "󰂯"
        return "󰓃"
    }

    function setVolume(node, value) {
        if (!node || !node.audio) return
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted
    }

    function volumeGlyph(node) {
        if (!node || !node.audio) return "󰖁"
        if (node.audio.muted) return "󰝟"
        const v = node.audio.volume
        return v < 0.01 ? "󰕿" : (v < 0.5 ? "󰖀" : "󰕾")
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

    // Medidores só rodam com o painel aberto, para não custar CPU à toa.
    PwNodePeakMonitor {
        id: sinkPeak
        node: root.open ? root.sink : null
        enabled: root.open && root.sink !== null
    }

    PwNodePeakMonitor {
        id: sourcePeak
        node: root.open ? root.source : null
        enabled: root.open && root.source !== null
    }

    // ── captura de clique fora ──────────────────────────────
    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sound-panel-catcher"
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

    // ── painel ──────────────────────────────────────────────
    PanelWindow {
        id: panelWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.panelWidth + 16
        implicitHeight: Math.min(screen.height - root.panelTop - 24, body.implicitHeight + 56)
        anchors { top: true; right: true }
        margins { top: root.panelTop; right: root.panelRight }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sound-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            MouseArea { anchors.fill: parent }

            // ── medidor de nivel ──
            component PeakMeter: Item {
                property real level: 0
                property color tint: Theme.accent
                property bool active: true

                implicitHeight: 4

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.10)

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        // Escala levemente comprimida: o pico bruto quase nao sai do chao.
                        width: parent.width * Math.max(0, Math.min(1, Math.pow(parent.parent.level, 0.6)))
                        color: parent.parent.active ? parent.parent.tint : Theme.textDim
                        opacity: 0.9
                        Behavior on width { NumberAnimation { duration: 70 } }
                    }
                }
            }

            // ── titulo de secao ──
            component SectionTitle: Text {
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
                color: Theme.textDim
            }

            // ── linha de dispositivo selecionavel ──
            component DeviceRow: Rectangle {
                property var node: null
                property bool selected: false
                signal picked()

                width: parent ? parent.width : 0
                height: 36
                radius: 10
                color: selected ? Qt.rgba(0.039, 0.518, 1.0, 0.30)
                                : (rowArea.containsMouse ? Theme.cardHover : "transparent")
                border.width: 1
                border.color: selected ? Theme.accent : Qt.rgba(1, 1, 1, 0.07)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    spacing: 9

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.deviceGlyph(parent.parent.node)
                        font.family: Theme.iconFamily
                        font.pixelSize: 15
                        color: parent.parent.selected ? Theme.accent : Theme.textDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 50
                        text: root.labelFor(parent.parent.node)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.text
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰄬"
                    visible: parent.selected
                    font.family: Theme.iconFamily
                    font.pixelSize: 13
                    color: Theme.accent
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.picked()
                }
            }

            Flickable {
                id: scroll
                anchors.fill: parent
                anchors.margins: Theme.pad
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: scroll.width
                    spacing: 16

                    // ── cabecalho ──
                    Item {
                        width: parent.width
                        height: 26

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Som"
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: 8
                            color: advArea.containsMouse ? Theme.cardHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: Theme.iconFamily
                                font.pixelSize: 14
                                color: advArea.containsMouse ? Theme.text : Theme.textDim
                            }

                            MouseArea {
                                id: advArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Escotilha para os casos raros (perfis, roteamento fino).
                                onClicked: {
                                    root.close()
                                    advancedProc.running = true
                                }
                            }
                        }
                    }

                    // ── saida ──
                    SectionTitle { text: "SAÍDA" }

                    Column {
                        width: parent.width
                        spacing: 9

                        SliderRow {
                            width: parent.width
                            icon: root.volumeGlyph(root.sink)
                            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                            muted: root.sink && root.sink.audio ? root.sink.audio.muted : false
                            onMoved: (v) => root.setVolume(root.sink, v)
                            onIconClicked: root.toggleMute(root.sink)
                        }

                        Item {
                            width: parent.width
                            height: 14

                            PeakMeter {
                                anchors.left: parent.left
                                anchors.right: pctLabel.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                level: sinkPeak.peak
                                active: root.sink && root.sink.audio && !root.sink.audio.muted
                                tint: Theme.success
                            }

                            Text {
                                id: pctLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.sink && root.sink.audio
                                      ? Math.round(root.sink.audio.volume * 100) + "%" : "—"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                            }
                        }

                        Repeater {
                            model: root.sinks

                            DeviceRow {
                                required property var modelData
                                node: modelData
                                selected: root.sink && modelData.id === root.sink.id
                                onPicked: Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }

                    // ── entrada ──
                    SectionTitle { text: "ENTRADA" }

                    Column {
                        width: parent.width
                        spacing: 9

                        SliderRow {
                            width: parent.width
                            icon: root.source && root.source.audio && root.source.audio.muted
                                  ? "󰍭" : "󰍬"
                            value: root.source && root.source.audio ? root.source.audio.volume : 0
                            muted: root.source && root.source.audio ? root.source.audio.muted : true
                            fill: Theme.warning
                            onMoved: (v) => root.setVolume(root.source, v)
                            onIconClicked: root.toggleMute(root.source)
                        }

                        // Medidor do microfone: confirma na hora se ele capta.
                        Item {
                            width: parent.width
                            height: 14

                            PeakMeter {
                                anchors.left: parent.left
                                anchors.right: micLabel.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                level: sourcePeak.peak
                                active: root.source && root.source.audio && !root.source.audio.muted
                                tint: Theme.warning
                            }

                            Text {
                                id: micLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.recordStreams.length > 0
                                      ? root.recordStreams.length + " em uso" : "ocioso"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: root.recordStreams.length > 0 ? Theme.warning : Theme.textDim
                            }
                        }

                        Repeater {
                            model: root.sources

                            DeviceRow {
                                required property var modelData
                                node: modelData
                                selected: root.source && modelData.id === root.source.id
                                onPicked: Pipewire.preferredDefaultAudioSource = modelData
                            }
                        }
                    }

                    // ── por aplicativo ──
                    SectionTitle {
                        text: "APLICATIVOS"
                        visible: root.playbackStreams.length > 0
                    }

                    Column {
                        width: parent.width
                        spacing: 12
                        visible: root.playbackStreams.length > 0

                        Repeater {
                            model: root.playbackStreams

                            Column {
                                required property var modelData
                                width: parent ? parent.width : 0
                                spacing: 6

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Image {
                                        id: appIcon
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                        fillMode: Image.PreserveAspectFit
                                        source: {
                                            const n = root.appIconName(parent.parent.modelData)
                                            return n ? Quickshell.iconPath(n, true) : ""
                                        }
                                    }

                                    // Glifo generico quando o app nao tem icone no tema.
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: appIcon.status !== Image.Ready
                                        text: "󰝚"
                                        font.family: Theme.iconFamily
                                        font.pixelSize: 14
                                        color: Theme.textDim
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 70
                                        text: root.appLabel(parent.parent.modelData)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.text
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.parent.modelData.audio
                                              ? Math.round(parent.parent.modelData.audio.volume * 100) + "%" : ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.textDim
                                    }
                                }

                                SliderRow {
                                    width: parent.width
                                    icon: root.volumeGlyph(parent.modelData)
                                    value: parent.modelData.audio ? parent.modelData.audio.volume : 0
                                    muted: parent.modelData.audio ? parent.modelData.audio.muted : false
                                    onMoved: (v) => root.setVolume(parent.parent.modelData, v)
                                    onIconClicked: root.toggleMute(parent.parent.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: advancedProc
        command: ["pavucontrol"]
    }
}
