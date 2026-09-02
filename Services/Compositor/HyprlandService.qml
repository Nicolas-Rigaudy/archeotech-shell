pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland backend for CompositorService — built on the built-in
// `Quickshell.Hyprland` service (workspaces / monitors / toplevels / event
// stream), which is live only when the shell runs under Hyprland. Under any
// other compositor its models are empty and this backend is never selected.
//
// Implements the same facade API as MangoService. Where Hyprland has no analogue
// for a MangoWC-specific concept (scroller proportion, layout symbols, per-window
// brackets) the method degrades to a safe no-op / empty result rather than error.
QtObject {
    id: root

    // Hyprland's own list of workspace objects, flattened to a plain array.
    readonly property var _workspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []

    readonly property string focusedOutput: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // Map Hyprland workspaces on a monitor → the {num,selected,occupied,urgent}
    // shape the bar's WorkspacesWidget expects, sorted by id.
    function tagsFor(monitorName) {
        var out = []
        var focused = Hyprland.focusedWorkspace
        for (var i = 0; i < _workspaces.length; i++) {
            var w = _workspaces[i]
            if (w.monitor && w.monitor.name && w.monitor.name !== monitorName) continue
            var count = (w.toplevels && w.toplevels.values) ? w.toplevels.values.length : 0
            out.push({
                num:      w.id,
                selected: !!focused && w.id === focused.id,
                occupied: count > 0,
                urgent:   !!w.urgent
            })
        }
        out.sort(function (a, b) { return a.num - b.num })
        return out
    }

    function titleFor(monitorName) {
        if (focusedOutput !== monitorName) return ""
        var t = Hyprland.activeToplevel
        return t ? (t.title || "") : ""
    }

    // Hyprland has no scroller layout symbol and per-window brackets are a
    // MangoWC-only overlay for now — both degrade to empty (base visuals stand).
    function layoutFor(monitorName)  { return "" }
    function clientsFor(monitorName) { return [] }

    // ── Actions ────────────────────────────────────────────────────────────────
    // Hyprland.dispatch runs `hyprctl dispatch <req>`.
    function switchTag(outputName, tagNum) { Hyprland.dispatch("workspace " + tagNum) }

    // The facade passes MangoWC-flavoured "func args". Translate the ones with a
    // Hyprland analogue; silently ignore mango-only ones (setlayout, proportion).
    function dispatch(command) {
        var parts = String(command).split(" ")
        switch (parts[0]) {
        case "view":           Hyprland.dispatch("workspace " + (parts[1] || "")); break
        case "toggleview":     Hyprland.dispatch("workspace " + (parts[1] || "")); break
        case "togglefloating": Hyprland.dispatch("togglefloating"); break
        case "fullscreen":     Hyprland.dispatch("fullscreen"); break
        case "killclient":     Hyprland.dispatch("killactive"); break
        // setlayout / set_proportion have no Hyprland equivalent → no-op.
        }
    }

    // No scroller model in Hyprland → nothing to proportion.
    function setProportion(p)        {}
    function setDefaultProportion(p) {}

    // Live theme-decoration parity: apply rounding + border width via `hyprctl
    // keyword` (a keyword, not a dispatch, so it goes through a Process helper).
    function applyWindowDecor(radius, bpx) {
        _keyword.argv = ["hyprctl", "keyword", "decoration:rounding", String(Math.round(radius))]
        _keyword.running = true
        _border.argv  = ["hyprctl", "keyword", "general:border_size", String(Math.round(bpx))]
        _border.running = true
    }

    property Process _keyword: Process { property var argv: []; command: argv; running: false }
    property Process _border:  Process { property var argv: []; command: argv; running: false }
}
