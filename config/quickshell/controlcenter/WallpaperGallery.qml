import QtQuick
import QtQuick.Effects
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel

// Galeria local ligada ao wallpaper-workspace. O download apenas adiciona
// imagens à pasta; a escolha continua sendo por workspace e aplicada pelo awww.
Scope {
    id: root

    property bool open: false
    property string searchText: ""
    property string selectedPath: ""
    property string currentPath: ""
    property string statusText: ""
    property bool downloading: false

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers/anime"
    readonly property string thumbnailDir: Quickshell.env("HOME") + "/.cache/wallpaper/thumbs"
    readonly property string currentLink: Quickshell.env("HOME") + "/.cache/wallpaper/current"
    readonly property string wallpaperTool: Quickshell.env("HOME") + "/.local/bin/wallpaper-workspace"
    readonly property string fetchTool: Quickshell.env("HOME") + "/.local/bin/wallpaper-fetch"
    readonly property string randomTool: Quickshell.env("HOME") + "/.local/bin/wallpaper-random"
    readonly property string thumbnailTool: Quickshell.env("HOME") + "/.local/bin/wallpaper-thumbs"
    readonly property color glass: Qt.rgba(0.055, 0.055, 0.065, 0.78)
    readonly property color glassRaised: Qt.rgba(1, 1, 1, 0.085)
    readonly property color glassHover: Qt.rgba(1, 1, 1, 0.15)
    readonly property string safeSearch: searchText.replace(/[\[\]*?]/g, "").trim()
    readonly property var imageFilters: safeSearch.length > 0
        ? ["*" + safeSearch + "*.jpg"]
        : ["*.jpg"]

    signal closed()

    function close() {
        root.closed()
    }

    function refreshCurrent() {
        if (!currentProc.running) currentProc.running = true
    }

    function applySelected() {
        if (!root.selectedPath || applyProc.running) return
        root.statusText = "Aplicando…"
        applyProc.command = [root.wallpaperTool, "set", root.selectedPath]
        applyProc.running = true
    }

    function downloadMore() {
        if (downloadProc.running) return
        const command = [root.fetchTool, "--quick", "8"]
        if (root.searchText.trim().length > 0)
            command.push(root.searchText.trim())
        root.downloading = true
        root.statusText = "Buscando wallpapers no Wallhaven…"
        downloadProc.command = command
        downloadProc.running = true
    }

    onOpenChanged: {
        if (open) {
            root.selectedPath = ""
            root.statusText = ""
            root.refreshCurrent()
            if (!thumbnailProc.running) thumbnailProc.running = true
        }
    }

    Component.onCompleted: thumbnailProc.running = true

    FolderListModel {
        id: wallpapers
        folder: "file://" + root.thumbnailDir
        nameFilters: root.imageFilters
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Time
        sortReversed: true
    }

    Process {
        id: thumbnailProc
        command: [root.thumbnailTool]
        onRunningChanged: {
            if (running && root.open && !root.statusText)
                root.statusText = "Preparando previews…"
        }
        onExited: (code) => {
            if (root.open && (root.statusText === "Preparando previews…" || code !== 0))
                root.statusText = code === 0
                    ? wallpapers.count + " previews prontos"
                    : "Alguns previews não puderam ser gerados"
        }
    }

    Process {
        id: currentProc
        command: ["readlink", "-f", root.currentLink]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentPath = text.trim()
                if (!root.selectedPath) root.selectedPath = root.currentPath
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: root.statusText = "Wallpaper aplicado neste workspace"
        }
        onExited: (code) => {
            if (code !== 0) root.statusText = "Não foi possível aplicar o wallpaper"
            root.refreshCurrent()
        }
    }

    Process {
        id: randomProc
        command: [root.randomTool]
        stdout: StdioCollector {
            onStreamFinished: root.statusText = "Novo wallpaper sorteado"
        }
        onExited: (code) => {
            if (code !== 0) root.statusText = "Não foi possível sortear o wallpaper"
            root.refreshCurrent()
        }
    }

    Process {
        id: downloadProc
        onExited: (code) => {
            root.downloading = false
            root.statusText = code === 0
                ? "Download concluído · preparando previews…"
                : "Falha ao baixar wallpapers"
            if (code === 0 && !thumbnailProc.running) thumbnailProc.running = true
        }
    }

    component ToolbarButton: Rectangle {
        id: toolbarButton
        property string glyph: ""
        property string label: ""
        property bool primary: false
        signal clicked()

        implicitWidth: buttonRow.implicitWidth + 24
        implicitHeight: 38
        radius: 14
        color: primary ? Theme.accent
                       : (buttonMouse.containsMouse ? root.glassHover : root.glassRaised)
        border.width: primary ? 0 : 1
        border.color: buttonMouse.containsMouse
            ? Qt.rgba(1, 1, 1, 0.22)
            : Theme.stroke
        opacity: enabled ? 1 : 0.45
        scale: buttonMouse.containsMouse && enabled ? 1.035 : 1

        Behavior on color {
            ColorAnimation { duration: Theme.anim }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
        }

        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                visible: toolbarButton.glyph !== ""
                text: toolbarButton.glyph
                font.family: Theme.iconFamily
                font.pixelSize: Theme.iconSize
                color: Theme.text
            }
            Text {
                text: toolbarButton.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: toolbarButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toolbarButton.clicked()
        }
    }

    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper-gallery"
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
        id: galleryWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Math.min(screen.width - 48, 1212)
        implicitHeight: Math.min(screen.height - 48, 812)
        anchors { top: true; left: true }
        margins {
            left: Math.max(20, (screen.width - implicitWidth) / 2)
            top: Math.max(20, (screen.height - implicitHeight) / 2)
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wallpaper-gallery-dialog"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            id: dialog
            anchors.fill: parent
            anchors.margins: 16
            radius: 32
            color: root.glass
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
            focus: root.open
            Keys.onEscapePressed: root.close()

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.72)
                shadowBlur: 0.9
                shadowVerticalOffset: 10
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 31
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.055)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: (event) => event.accepted = true
            }

            Row {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 20
                height: 42
                spacing: 10

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 13
                        color: Qt.rgba(0.039, 0.518, 1, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(0.039, 0.518, 1, 0.34)

                        Text {
                            anchors.centerIn: parent
                            text: "󰸉"
                            font.family: Theme.iconFamily
                            font.pixelSize: 17
                            color: Theme.accent
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wallpapers"
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(220, parent.width - 220 - actions.width - 20)
                    height: 38
                    radius: 14
                    color: root.glassRaised
                    border.width: 1
                    border.color: search.activeFocus
                        ? Qt.rgba(0.039, 0.518, 1, 0.72)
                        : Theme.stroke

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        font.family: Theme.iconFamily
                        font.pixelSize: Theme.iconSize
                        color: Theme.textDim
                    }

                    TextInput {
                        id: search
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.searchText
                        onTextChanged: root.searchText = text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: Theme.text
                        selectionColor: Theme.accent
                        clip: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0 && !search.activeFocus
                        text: "Filtrar localmente ou buscar para baixar"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textDim
                    }
                }

                Row {
                    id: actions
                    height: parent.height
                    spacing: 8

                    ToolbarButton {
                        glyph: "󰑓"
                        label: "Sortear"
                        onClicked: {
                            root.statusText = "Sorteando…"
                            randomProc.running = true
                        }
                    }
                    ToolbarButton {
                        glyph: root.downloading ? "󰦖" : "󰇚"
                        label: root.downloading ? "Baixando" : "Baixar"
                        enabled: !root.downloading
                        onClicked: root.downloadMore()
                    }
                    ToolbarButton {
                        glyph: "󰅖"
                        label: ""
                        onClicked: root.close()
                    }
                }
            }

            GridView {
                id: grid
                anchors.top: header.bottom
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.bottomMargin: 16
                clip: true
                model: wallpapers
                cellWidth: width / 4
                cellHeight: 164
                cacheBuffer: cellHeight * 2
                boundsBehavior: Flickable.StopAtBounds

                QQC.ScrollBar.vertical: QQC.ScrollBar {
                    id: wallpaperScrollBar
                    width: 8
                    policy: QQC.ScrollBar.AlwaysOn

                    contentItem: Rectangle {
                        implicitWidth: 6
                        implicitHeight: 72
                        radius: 3
                        color: wallpaperScrollBar.pressed
                            ? Theme.accent
                            : (wallpaperScrollBar.hovered
                                ? Qt.rgba(0.039, 0.518, 1, 0.72)
                                : Qt.rgba(1, 1, 1, 0.30))

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim }
                        }
                    }

                    background: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.055)
                    }
                }

                delegate: Item {
                    id: wallpaperItem
                    required property string fileName
                    required property url fileUrl
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property string sourceName: fileName.slice(0, -4)
                    readonly property string sourcePath: root.wallpaperDir + "/" + sourceName
                    readonly property bool selected: root.selectedPath === sourcePath
                    readonly property bool current: root.currentPath === sourcePath
                    readonly property bool hovered: cardMouse.containsMouse

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 7
                        radius: 21
                        color: root.glassRaised
                        border.width: wallpaperItem.selected ? 2 : 1
                        border.color: wallpaperItem.selected
                            ? Theme.accent
                            : (wallpaperItem.hovered ? Qt.rgba(1, 1, 1, 0.28) : Theme.stroke)
                        clip: true
                        scale: wallpaperItem.hovered ? 1.018 : 1

                        Behavior on scale {
                            NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: wallpaperItem.selected ? 2 : 0
                            source: wallpaperItem.fileUrl
                            sourceSize.width: 340
                            sourceSize.height: 190
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            scale: wallpaperItem.hovered ? 1.055 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: wallpaperItem.hovered
                                ? Qt.rgba(1, 1, 1, 0.045)
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Theme.anim }
                            }
                        }

                        Rectangle {
                            id: currentBadge
                            visible: wallpaperItem.current
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            width: currentText.implicitWidth + 14
                            height: 24
                            radius: 10
                            color: Theme.accent
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.32)

                            Text {
                                id: currentText
                                anchors.centerIn: parent
                                text: "Atual"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                        }

                        Rectangle {
                            visible: wallpaperItem.selected
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: 28
                            height: 28
                            radius: 11
                            color: Theme.accent
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.34)

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.family: Theme.iconFamily
                                font.pixelSize: 15
                                color: Theme.text
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedPath = wallpaperItem.sourcePath
                            onDoubleClicked: {
                                root.selectedPath = wallpaperItem.sourcePath
                                root.applySelected()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: wallpapers.count === 0
                    text: root.safeSearch.length > 0
                        ? "Nenhum wallpaper corresponde ao filtro"
                        : "Nenhum wallpaper encontrado"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.textDim
                }
            }

            Rectangle {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                height: 54
                radius: 18
                color: root.glassRaised
                border.width: 1
                border.color: Theme.stroke

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: applyButton.left
                    anchors.rightMargin: 16
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.selectedPath
                            ? (root.selectedPath === root.currentPath
                                ? "Wallpaper atual selecionado"
                                : "Wallpaper selecionado")
                            : wallpapers.count + " wallpapers"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideMiddle
                    }
                    Text {
                        width: parent.width
                        text: root.statusText || (wallpapers.count + " wallpapers locais · duplo clique para aplicar")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }

                ToolbarButton {
                    id: applyButton
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    glyph: "󰸉"
                    label: "Aplicar neste workspace"
                    primary: true
                    enabled: root.selectedPath.length > 0 && !applyProc.running
                    onClicked: root.applySelected()
                }
            }
        }
    }
}
