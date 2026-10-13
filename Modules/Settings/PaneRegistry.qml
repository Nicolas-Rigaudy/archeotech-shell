pragma Singleton
import QtQuick
import "../../Commons" as Commons
import "SettingsSearchLogic.js" as Logic

QtObject {
    readonly property var panes: [
        { id: "appearance",    label: "Appearance",    icon: "󰔯", source: "./Panes/AppearancePane.qml"    },
        { id: "shell",         label: "Shell",         icon: "󰍹", source: "./Panes/ShellPane.qml"         },
        { id: "display",       label: "Display",       icon: "󱄅", source: "./Panes/DisplayPane.qml"       },
        { id: "input",         label: "Input",         icon: "󰌌", source: "./Panes/InputPane.qml"         },
        { id: "notifications", label: "Notifications", icon: "󰂚", source: "./Panes/NotificationsPane.qml" },
        { id: "connections",   label: "Connections",   icon: "󰤨", source: "./Panes/ConnectionsPane.qml"   },
        { id: "audio",         label: "Audio",         icon: "󰕾", source: "./Panes/AudioPane.qml"         },
        { id: "plugins",       label: "Plugins",       icon: "󰏗", source: "./Panes/PluginsPane.qml"       },
        { id: "power",         label: "Power",         icon: "󱐋", source: "./Panes/PowerPane.qml"         },
        { id: "about",         label: "About",         icon: "󰅺", source: "./Panes/AboutPane.qml"         },
    ]

    function indexFor(paneId) {
        for (var i = 0; i < panes.length; i++) {
            if (panes[i].id === paneId) return i
        }
        return 0
    }

    function _paneMeta(id) {
        for (var i = 0; i < panes.length; i++) if (panes[i].id === id) return panes[i]
        return { id: id, label: id, icon: "" }
    }

    // ── Settings search (item_138) ─────────────────────────────────────────────
    // One entry per setting (SettingsSearchLogic.js); picking one opens its pane
    // and reveals the row (State.settingsFocusKey → SearchTarget).
    readonly property var searchIndex: Logic.INDEX

    // Up to 15 ranked results: entry fields + paneLabel, paneIcon.
    function search(query) {
        return Logic.search(query, function (id) { return _paneMeta(id).label }).map(function (e) {
            var m = _paneMeta(e.pane)
            return Object.assign({ paneLabel: m.label, paneIcon: m.icon }, e)
        })
    }

    // Open Settings on `key`'s pane and reveal that row. A request no row takes
    // (e.g. Max volume with no output device) expires, so a row created later
    // never jumps unprompted.
    function focusSetting(key) {
        var e = Logic.entryFor(key)
        if (!e) return false
        Commons.State.settingsFocusKey = key
        Commons.State.settingsFocusSerial++
        Commons.State.settingsOpenPane = e.pane
        _expire.restart()
        return true
    }
    property Timer _expire: Timer { interval: 2000; onTriggered: Commons.State.settingsFocusKey = "" }
}
