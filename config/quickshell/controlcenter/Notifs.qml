pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Servidor de notificacoes proprio, no lugar do swaync.
// Guarda o historico como instantaneos (a notificacao original morre ao ser
// dispensada) e mantem vivas apenas as que ainda estao na tela como toast.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []        // Notification vivas, mais nova primeiro
    property var history: []       // instantaneos, mais novo primeiro

    readonly property int historyCount: history.length
    readonly property int popupCount: popups.length
    readonly property int maxHistory: 100
    readonly property int maxPopups: 4

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true

        onNotification: (notif) => {
            // Sem tracked=true o objeto e destruido assim que este slot retorna.
            notif.tracked = true

            const snap = {
                id: notif.id,
                appName: notif.appName || "Sistema",
                appIcon: notif.appIcon || "",
                summary: notif.summary || "",
                body: notif.body || "",
                image: notif.image || "",
                urgency: notif.urgency,
                time: new Date()
            }
            root.history = [snap].concat(root.history).slice(0, root.maxHistory)

            // Em Nao Perturbe a notificacao entra no historico mas nao aparece.
            // Urgencia critica ignora o DND, como manda a spec.
            if (root.dnd && notif.urgency !== NotificationUrgency.Critical) {
                notif.tracked = false
                return
            }

            root.popups = [notif].concat(root.popups.filter(n => n && n.tracked))
                                 .slice(0, root.maxPopups)
        }
    }

    function dismissPopup(notif) {
        if (!notif) return
        root.popups = root.popups.filter(n => n !== notif)
        if (notif.tracked) notif.dismiss()
    }

    function dismissAllPopups() {
        for (const n of root.popups) if (n && n.tracked) n.dismiss()
        root.popups = []
    }

    function clearHistory() {
        root.history = []
    }

    function removeFromHistory(index) {
        const copy = root.history.slice()
        copy.splice(index, 1)
        root.history = copy
    }

    function toggleDnd() {
        root.dnd = !root.dnd
        if (root.dnd) root.dismissAllPopups()
    }

    // A Waybar redesenha o modulo ao receber RTMIN+8, entao nao precisa
    // ficar chamando o IPC de segundo em segundo.
    Process {
        id: barRefresh
        command: ["pkill", "-RTMIN+8", "waybar"]
    }

    Timer {
        id: barRefreshTimer
        interval: 120
        onTriggered: if (!barRefresh.running) barRefresh.running = true
    }

    // A Waybar sobe antes deste processo: sem um sinal inicial, o modulo
    // ficaria vazio ate a primeira notificacao.
    Component.onCompleted: barRefreshTimer.restart()

    onHistoryCountChanged: barRefreshTimer.restart()
    onDndChanged: barRefreshTimer.restart()

    function timeAgo(date) {
        const secs = Math.floor((Date.now() - date.getTime()) / 1000)
        if (secs < 60) return "agora"
        const mins = Math.floor(secs / 60)
        if (mins < 60) return mins + " min"
        const hours = Math.floor(mins / 60)
        if (hours < 24) return hours + " h"
        return Math.floor(hours / 24) + " d"
    }

    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical) return Theme.danger
        if (urgency === NotificationUrgency.Low) return Theme.textDim
        return Theme.accent
    }
}
