pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io
import Quickshell.Services.Notifications
import "../Persistence" as Persistence
import "ClockLogic.js" as Clock
import "NotificationsLogic.js" as Logic

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
        if (Persistence.Config.get("notifications.persistDnd"))
            dndEnabled = Persistence.Config.get("notifications.dnd", false)
        _dndRestored = true
    }
    Component.onCompleted: _restoreDnd()
    Connections {
        target: Persistence.Config
        function onReadyChanged() { root._restoreDnd() }
    }
    onDndEnabledChanged: {
        if (_dndRestored && Persistence.Config.get("notifications.persistDnd"))
            Persistence.Config.set("notifications.dnd", dndEnabled)
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: false

        onNotification: notif => {
            root.history = root.history.concat([{
                id:        notif.id,
                appIcon:   notif.appIcon   || "",
                appName:   notif.appName   || "",
                summary:   notif.summary   || "",
                body:      notif.body      || "",
                urgency:   notif.urgency   || 0,
                // Fixed at arrival in the current clock.format (not re-rendered later).
                timestamp: Qt.formatTime(new Date(), Clock.timeFormat(Persistence.Config.get("clock.format"), false)),
                _notif:    notif
            }])
            root.unreadCount++
            root.arrived(notif)
        }
    }

    // ── History on disk (item_119) ──────────────────────────────────────────────
    // Survives a shell reload or restart. Restored once, before any write, so an
    // empty startup list never overwrites the saved one; notifications arriving
    // before the read ends are kept after the restored ones. After a reload the
    // server still holds the notifications it kept (keepOnReload), and each is
    // re-attached to its entry so a dismiss still reaches the app.
    property bool _historyRestored: false
    property FileView _historyFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share/archeotech/notifications.json"
        watchChanges: false
        printErrors: false
        onLoaded: {
            var restored = Logic.reattach(Logic.restore(text()), server.trackedNotifications.values)
            root.history = restored.concat(root.history)
            root._historyRestored = true
        }
        onLoadFailed: root._historyRestored = true    // no file yet
    }
    property Timer _historySave: Timer {
        interval: 500
        onTriggered: root._historyFile.setText(Logic.serialize(root.history))
    }
    onHistoryChanged: if (_historyRestored) _historySave.restart()

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
