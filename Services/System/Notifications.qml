pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import "../Persistence" as Persistence

Item {
    id: root

    property bool dndEnabled:  false
    property int  unreadCount: 0
    readonly property int count: history.length
    property var  history: []

    signal arrived(var notification)

    // Settings → "Persist Do Not Disturb": when on, DND survives a restart. The
    // saved state is restored once config.json has been read (Config.ready) and
    // only written after that, so a startup default can never overwrite it.
    property bool _dndRestored: false
    function _restoreDnd() {
        if (_dndRestored || !Persistence.Config.ready) return
        // Assign before marking restored, so onDndEnabledChanged doesn't write the
        // value it was just read from straight back to disk.
        if (Persistence.Config.get("notifications.persistDnd", false))
            dndEnabled = Persistence.Config.get("notifications.dnd", false)
        _dndRestored = true
    }
    Component.onCompleted: _restoreDnd()
    Connections {
        target: Persistence.Config
        function onReadyChanged() { root._restoreDnd() }
    }
    onDndEnabledChanged: {
        if (_dndRestored && Persistence.Config.get("notifications.persistDnd", false))
            Persistence.Config.set("notifications.dnd", dndEnabled)
    }

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

    // Empty the list first so the UI always clears, then best-effort dismiss
    // each backing notif — an already-expired one throws and would otherwise
    // abort the whole batch.
    function clearAll() {
        var h = root.history
        root.history = []
        root.unreadCount = 0
        for (var i = 0; i < h.length; i++) {
            try { h[i]._notif.dismiss() } catch (e) {}
        }
    }

    function dismiss(index) {
        var h = root.history.slice()
        var entry = h[index]
        h.splice(index, 1)
        root.history = h
        if (root.unreadCount > 0) root.unreadCount--
        try { entry._notif.dismiss() } catch (e) {}
    }
}
