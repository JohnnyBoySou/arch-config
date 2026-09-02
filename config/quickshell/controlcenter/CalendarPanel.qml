import QtQuick
import Quickshell
import Quickshell.Wayland

// Calendario navegavel, aberto pelo cartao de calendario dos widgets de desktop.
// Sem backend de eventos na maquina: mostra datas, semanas e feriados nacionais
// calculados offline (fixos + moveis derivados da Pascoa).
Scope {
    id: root

    property bool open: false
    property bool closeArmed: false

    // Mes/ano em exibicao (independente de "hoje", para permitir navegar).
    property int viewYear: 0
    property int viewMonth: 0
    property int selectedDay: 0

    readonly property date today: new Date()
    readonly property int panelWidth: 460
    readonly property var weekDays: ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"]
    readonly property var locale: Qt.locale("pt_BR")

    signal closed()

    function close() { root.closed() }

    // ── grade do mes ────────────────────────────────────────
    // Coluna 0 = segunda-feira. getDay() devolve 0 para domingo.
    readonly property int firstOffset: (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
    readonly property int daysInPrevMonth: new Date(viewYear, viewMonth, 0).getDate()
    // 6 linhas fixas evitam o painel "pular" de altura ao trocar de mes.
    readonly property int cellCount: 42

    function dayForCell(index) {
        const day = index - root.firstOffset + 1
        return (day >= 1 && day <= root.daysInMonth) ? day : 0
    }

    // Dias vizinhos aparecem esmaecidos, como no calendario do macOS.
    function adjacentDayForCell(index) {
        if (index < root.firstOffset)
            return root.daysInPrevMonth - root.firstOffset + index + 1
        return index - root.firstOffset - root.daysInMonth + 1
    }

    function isToday(day) {
        return day > 0
            && day === root.today.getDate()
            && root.viewMonth === root.today.getMonth()
            && root.viewYear === root.today.getFullYear()
    }

    function isWeekend(index) { return (index % 7) >= 5 }

    // ── navegacao ───────────────────────────────────────────
    function shiftMonth(delta) {
        let m = root.viewMonth + delta
        let y = root.viewYear
        while (m < 0)  { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }
        root.viewMonth = m
        root.viewYear = y
        root.selectedDay = 0
    }

    function shiftYear(delta) {
        root.viewYear += delta
        root.selectedDay = 0
    }

    function goToToday() {
        root.viewYear = root.today.getFullYear()
        root.viewMonth = root.today.getMonth()
        root.selectedDay = root.today.getDate()
    }

    // ── feriados nacionais ──────────────────────────────────
    // Domingo de Pascoa pelo algoritmo de Meeus/Butcher (calendario gregoriano).
    function easterOf(year) {
        const a = year % 19
        const b = Math.floor(year / 100)
        const c = year % 100
        const d = Math.floor(b / 4)
        const e = b % 4
        const f = Math.floor((b + 8) / 25)
        const g = Math.floor((b - f + 1) / 3)
        const h = (19 * a + b - d - g + 15) % 30
        const i = Math.floor(c / 4)
        const k = c % 4
        const l = (32 + 2 * e + 2 * i - h - k) % 7
        const m = Math.floor((a + 11 * h + 22 * l) / 451)
        const month = Math.floor((h + l - 7 * m + 114) / 31)
        const day = ((h + l - 7 * m + 114) % 31) + 1
        return new Date(year, month - 1, day)
    }

    function holidaysFor(year) {
        const fixed = {
            "0-1":   "Confraternização Universal",
            "3-21":  "Tiradentes",
            "4-1":   "Dia do Trabalho",
            "8-7":   "Independência do Brasil",
            "9-12":  "Nossa Senhora Aparecida",
            "10-2":  "Finados",
            "10-15": "Proclamação da República",
            "10-20": "Consciência Negra",
            "11-25": "Natal"
        }
        const easter = root.easterOf(year)
        const moving = [
            [-48, "Carnaval"],
            [-47, "Carnaval"],
            [-2,  "Sexta-feira Santa"],
            [0,   "Páscoa"],
            [60,  "Corpus Christi"]
        ]
        const table = {}
        for (const key in fixed) table[key] = fixed[key]
        for (const [offset, name] of moving) {
            const d = new Date(easter.getFullYear(), easter.getMonth(), easter.getDate() + offset)
            table[d.getMonth() + "-" + d.getDate()] = name
        }
        return table
    }

    readonly property var yearHolidays: holidaysFor(viewYear)

    function holidayName(day) {
        if (day < 1) return ""
        return root.yearHolidays[root.viewMonth + "-" + day] || ""
    }

    // ── rodape ──────────────────────────────────────────────
    readonly property int focusDay: selectedDay > 0
        ? selectedDay
        : (isToday(today.getDate()) ? today.getDate() : 1)

    readonly property string focusLabel: {
        const d = new Date(root.viewYear, root.viewMonth, root.focusDay)
        const text = root.locale.toString(d, "dddd, d 'de' MMMM 'de' yyyy")
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    // Semana ISO-8601: a semana 1 e a que contem a primeira quinta-feira do ano.
    function isoWeek(year, month, day) {
        const date = new Date(year, month, day)
        const thursday = new Date(year, month, day - ((date.getDay() + 6) % 7) + 3)
        const firstThursday = new Date(thursday.getFullYear(), 0, 4)
        const diff = thursday - new Date(firstThursday.getFullYear(), 0,
                                         4 - ((firstThursday.getDay() + 6) % 7) + 3)
        return 1 + Math.round(diff / (7 * 24 * 3600 * 1000))
    }

    onOpenChanged: {
        if (open) {
            root.closeArmed = false
            closeArmTimer.restart()
            root.goToToday()
        }
    }

    // Sem isto, o mesmo clique que abre o painel o fecharia em seguida.
    Timer {
        id: closeArmTimer
        interval: 220
        onTriggered: root.closeArmed = true
    }

    // Mantem "hoje" correto se o painel ficar aberto durante a virada do dia.
    Timer {
        running: root.open
        interval: 60000
        repeat: true
        onTriggered: root.todayTick = !root.todayTick
    }
    property bool todayTick: false

    // ── captura de clique fora ──────────────────────────────
    PanelWindow {
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "calendar-panel-catcher"
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
            Keys.onLeftPressed: root.shiftMonth(-1)
            Keys.onRightPressed: root.shiftMonth(1)
            Keys.onUpPressed: root.shiftYear(-1)
            Keys.onDownPressed: root.shiftYear(1)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Home || event.key === Qt.Key_T) {
                    root.goToToday()
                    event.accepted = true
                }
            }
        }
    }

    // ── painel ──────────────────────────────────────────────
    PanelWindow {
        id: panelWindow
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.panelWidth
        implicitHeight: panelBody.implicitHeight + 36
        anchors { top: true; left: true }
        margins {
            left: Math.max(0, (screen.width - root.panelWidth) / 2)
            top: Math.max(48, (screen.height - panelWindow.implicitHeight) / 2 - 60)
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "calendar-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.margins: 8
            radius: Theme.radiusPanel
            color: Theme.panel
            border.width: 1
            border.color: Theme.stroke

            // Clique dentro do painel nao deve fecha-lo.
            MouseArea { anchors.fill: parent }

            Column {
                id: panelBody
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.pad
                spacing: 14

                // ── cabecalho: mes, ano e navegacao ──
                Item {
                    width: parent.width
                    height: 34

                    component NavButton: Rectangle {
                        property string glyph: ""
                        property real glyphSize: Theme.iconSize
                        signal activated()

                        width: 30
                        height: 30
                        radius: 9
                        color: navArea.containsMouse ? Theme.cardHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.glyph
                            font.family: Theme.iconFamily
                            font.pixelSize: parent.glyphSize
                            color: navArea.containsMouse ? Theme.text : Theme.textDim
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.activated()
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        NavButton {
                            glyph: "󰅁"
                            onActivated: root.shiftMonth(-1)
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                const name = root.locale.standaloneMonthName(root.viewMonth)
                                return name.charAt(0).toUpperCase() + name.slice(1)
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.viewYear
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textDim
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        NavButton {
                            glyph: "󰅂"
                            onActivated: root.shiftMonth(1)
                        }
                    }
                }

                // ── cabecalho dos dias da semana ──
                Row {
                    width: parent.width

                    Repeater {
                        model: root.weekDays

                        Text {
                            required property string modelData
                            required property int index
                            width: panelBody.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                            color: index >= 5 ? Qt.rgba(1, 1, 1, 0.30) : Theme.textDim
                        }
                    }
                }

                // ── grade ──
                Grid {
                    width: parent.width
                    columns: 7
                    rowSpacing: 2

                    Repeater {
                        model: root.cellCount

                        Item {
                            id: cell
                            required property int index

                            readonly property int day: root.dayForCell(index)
                            readonly property bool inMonth: day > 0
                            readonly property bool today: {
                                root.todayTick     // reavalia na virada do dia
                                return root.isToday(day)
                            }
                            readonly property bool selected: inMonth && day === root.selectedDay
                            readonly property string holiday: root.holidayName(day)

                            width: panelBody.width / 7
                            height: 44

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                radius: 18
                                color: {
                                    if (cell.today) return Theme.accent
                                    if (cell.selected) return Qt.rgba(1, 1, 1, 0.18)
                                    if (dayArea.containsMouse && cell.inMonth) return Theme.cardHover
                                    return "transparent"
                                }
                                border.width: cell.selected && !cell.today ? 1 : 0
                                border.color: Theme.stroke

                                Behavior on color {
                                    ColorAnimation { duration: 110 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3
                                text: cell.inMonth ? cell.day : root.adjacentDayForCell(cell.index)
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: cell.today ? Font.Bold
                                           : (cell.holiday !== "" ? Font.DemiBold : Font.Normal)
                                color: {
                                    if (!cell.inMonth) return Qt.rgba(1, 1, 1, 0.18)
                                    if (cell.today) return "#ffffff"
                                    if (cell.holiday !== "") return Theme.warning
                                    if (root.isWeekend(cell.index)) return Qt.rgba(1, 1, 1, 0.45)
                                    return Theme.text
                                }
                            }

                            // Ponto indicando feriado.
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 11
                                width: 4
                                height: 4
                                radius: 2
                                visible: cell.inMonth && cell.holiday !== ""
                                color: cell.today ? "#ffffff" : Theme.warning
                            }

                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: cell.inMonth
                                cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.selectedDay = cell.day
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.stroke
                }

                // ── rodape: data em foco, semana e feriado ──
                Item {
                    width: parent.width
                    height: 40

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: todayButton.left
                        anchors.rightMargin: 12
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.focusLabel
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            readonly property string holiday:
                                root.holidayName(root.focusDay)
                            text: "Semana "
                                + root.isoWeek(root.viewYear, root.viewMonth, root.focusDay)
                                + (holiday !== "" ? "  ·  " + holiday : "")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: holiday !== "" ? Theme.warning : Theme.textDim
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: todayButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 62
                        height: 28
                        radius: 9
                        color: todayArea.containsMouse ? Theme.cardHover : Theme.card
                        border.width: 1
                        border.color: Theme.stroke

                        Text {
                            anchors.centerIn: parent
                            text: "Hoje"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        MouseArea {
                            id: todayArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToToday()
                        }
                    }
                }
            }
        }
    }
}
