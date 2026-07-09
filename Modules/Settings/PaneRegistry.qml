pragma Singleton
import QtQuick

QtObject {
    readonly property var panes: [
        { id: "appearance",    label: "Appearance",    icon: "󰔯", source: "./Panes/AppearancePane.qml"    },
        { id: "shell",         label: "Shell",         icon: "󰍹", source: "./Panes/ShellPane.qml"         },
        { id: "display",       label: "Display",       icon: "󱄅", source: "./Panes/DisplayPane.qml"       },
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

    // ── Settings search index (Sprint 24) ──────────────────────────────────────
    // Flat list of notable settings → owning pane. Search matches label +
    // keywords + pane label; clicking a result jumps to the pane. Hand-authored
    // (panes don't self-register searchable items yet); keep in sync when a pane
    // gains a notable control.
    readonly property var searchIndex: [
        { pane: "appearance",    label: "Theme",                 keywords: "color scheme variant macchiato mocha dracula nord gruvbox tokyo monochrome palette" },
        { pane: "appearance",    label: "Wallpaper",             keywords: "background image picker carousel" },
        { pane: "appearance",    label: "Logo overlay",          keywords: "arch rebel imperial emblem sigil" },
        { pane: "appearance",    label: "Font size scale",       keywords: "typography text size scale" },
        { pane: "appearance",    label: "Corner rounding",       keywords: "geometry radius rounded" },
        { pane: "appearance",    label: "Padding scale",         keywords: "geometry spacing density" },
        { pane: "shell",         label: "Edit layout",           keywords: "visual builder customize edit mode bar strips widgets arrange position" },
        { pane: "shell",         label: "Bar height & modules",  keywords: "bar height clock format modules music wifi bluetooth battery toggle" },
        { pane: "display",       label: "Brightness",            keywords: "screen backlight dim" },
        { pane: "display",       label: "Night light",           keywords: "blue light warmth gamma wlsunset temperature" },
        { pane: "display",       label: "Display layout",        keywords: "monitor resolution extend mirror scale arrangement" },
        { pane: "notifications", label: "Do not disturb",        keywords: "dnd silence mute notifications" },
        { pane: "notifications", label: "Notification behaviour", keywords: "toast history clear popups" },
        { pane: "connections",   label: "Wi-Fi",                 keywords: "wifi wireless network connect ssid password" },
        { pane: "connections",   label: "Bluetooth",             keywords: "bt pair device headset connect" },
        { pane: "connections",   label: "VPN",                   keywords: "vpn wireguard tunnel" },
        { pane: "audio",         label: "Output device",         keywords: "sink speakers headphones volume audio sound" },
        { pane: "audio",         label: "Input device",          keywords: "source microphone mic recording" },
        { pane: "plugins",       label: "Plugins & modules",     keywords: "plugin module widget manager install uninstall enable disable verified extension configure" },
        { pane: "power",         label: "Power profile",         keywords: "performance balanced power saver battery" },
        { pane: "power",         label: "Idle & sleep",          keywords: "timeout lock suspend swayidle screen off" },
        { pane: "about",         label: "About",                 keywords: "version system info quickshell archeotech" }
    ]

    // Returns up to 15 ranked results: { pane, label, paneLabel, paneIcon }.
    // Match = every whitespace-delimited query token is a substring of the
    // entry's (label + keywords + pane label). Ranked by total match position
    // (earlier = better), then shorter label.
    function search(query) {
        var q = (query || "").trim().toLowerCase()
        if (q === "") return []
        var tokens = q.split(/\s+/)
        var out = []
        for (var i = 0; i < searchIndex.length; i++) {
            var e = searchIndex[i]
            var meta = _paneMeta(e.pane)
            var hay = (e.label + " " + e.keywords + " " + meta.label).toLowerCase()
            var ok = true, posSum = 0
            for (var t = 0; t < tokens.length; t++) {
                var idx = hay.indexOf(tokens[t])
                if (idx === -1) { ok = false; break }
                posSum += idx
            }
            if (ok) out.push({ pane: e.pane, label: e.label,
                               paneLabel: meta.label, paneIcon: meta.icon,
                               _score: posSum * 100 + e.label.length })
        }
        out.sort(function(a, b) { return a._score - b._score })
        return out.slice(0, 15)
    }
}
