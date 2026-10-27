.pragma library
// Notification history on disk (item_119): the notification center's list is
// saved to ~/.local/share/archeotech/notifications.json so it survives a shell
// reload or restart. Pure, so tests/qml can check it without the shell.

// Newest entries kept; older ones are dropped on save.
var HISTORY_LIMIT = 100

var FIELDS = ["id", "appIcon", "appName", "summary", "body", "urgency", "timestamp"]

function _entry(e) {
    var out = {}
    for (var i = 0; i < FIELDS.length; i++) {
        var k = FIELDS[i]
        out[k] = e[k] !== undefined && e[k] !== null ? e[k] : (k === "urgency" ? 0 : (k === "id" ? -1 : ""))
    }
    return out
}

// history (oldest first, entries may carry a live _notif) → file text.
function serialize(history) {
    var list = (history || []).slice(-HISTORY_LIMIT).map(_entry)
    return JSON.stringify({ version: 1, history: list }, null, 2)
}

// File text → history entries (oldest first, no _notif). Bad or foreign
// content restores nothing rather than failing.
function restore(text) {
    if (!text || !String(text).trim()) return []
    var parsed
    try { parsed = JSON.parse(text) } catch (e) { return [] }
    if (!parsed || !Array.isArray(parsed.history)) return []
    return parsed.history
        .filter(function (e) { return e && typeof e === "object" && (e.summary || e.body) })
        .slice(-HISTORY_LIMIT)
        .map(_entry)
}

// After a reload the server still tracks the notifications it kept
// (keepOnReload): re-attach each to its restored entry by id, so dismissing it
// from the center still closes it for the app. tracked: [{ id, … }].
function reattach(history, tracked) {
    var byId = {}
    for (var i = 0; i < (tracked || []).length; i++)
        if (tracked[i]) byId[tracked[i].id] = tracked[i]
    return history.map(function (e) {
        if (e._notif || e.id === undefined || e.id < 0 || !byId[e.id]) return e
        var c = {}
        for (var k in e) c[k] = e[k]
        c._notif = byId[e.id]
        return c
    })
}
