pragma Singleton
import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property bool dndEnabled:  false
    property int  unreadCount: 0
    readonly property int count: history.length
    property var  history: []

    signal arrived(var notification)

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: false

        onNotification: notif => {
            root.history = root.history.concat([{
                appIcon:   notif.appIcon   || "",
                appName:   notif.appName   || "",
                summary:   notif.summary   || "",
                body:      notif.body      || "",
                urgency:   notif.urgency   || 0,
                timestamp: Qt.formatTime(new Date(), "HH:mm"),
                _notif:    notif
            }])
            root.unreadCount++
            root.arrived(notif)
        }
    }

    function clearAll() {
        for (var i = root.history.length - 1; i >= 0; i--)
            root.history[i]._notif.dismiss()
        root.history = []
        root.unreadCount = 0
    }

    function dismiss(index) {
        root.history[index]._notif.dismiss()
        var h = root.history.slice()
        h.splice(index, 1)
        root.history = h
        if (root.unreadCount > 0) root.unreadCount--
    }
}
