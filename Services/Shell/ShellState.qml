pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    property var stateMap: ({})

    // Sprint 26 follow-up B — `side` disambiguates which holder shows the panel
    // when the same opener sits on 2+ sides (e.g. settings on both strips).
    // "" = wildcard (bar/IPC openers that don't belong to a side) → any hosting
    // strip shows it, the pre-B behaviour.
    function _emptyForScreens(screens) {
        var m = {}
        for (var i = 0; i < screens.length; i++) {
            m[screens[i].name] = { open: "", side: "" }
        }
        return m
    }

    function _clone() {
        var copy = {}
        for (var k in stateMap) copy[k] = { open: stateMap[k].open, side: stateMap[k].side || "" }
        return copy
    }

    function _commit(m) { root.stateMap = m }

    function getState(screenName) {
        return stateMap[screenName] || { open: "" }
    }

    function isOpen(screenName, panel) {
        var s = stateMap[screenName]
        return !!s && s.open === panel
    }

    function anyOpen(screenName) {
        var s = stateMap[screenName]
        return !!s && s.open !== ""
    }

    function activePanel(screenName) {
        var s = stateMap[screenName]
        return s ? s.open : ""
    }

    // Which side currently shows the active panel on this screen ("" = wildcard).
    function activeSide(screenName) {
        var s = stateMap[screenName]
        return s ? (s.side || "") : ""
    }

    function open(screenName, panel, side) {
        var m = _clone()
        if (!m[screenName]) m[screenName] = { open: "", side: "" }
        m[screenName].open = panel
        m[screenName].side = side || ""
        _commit(m)
    }

    function close(screenName) {
        var m = _clone()
        if (!m[screenName]) m[screenName] = { open: "", side: "" }
        m[screenName].open = ""
        m[screenName].side = ""
        _commit(m)
    }

    function toggle(screenName, panel, side) {
        if (isOpen(screenName, panel)) close(screenName)
        else open(screenName, panel, side)
    }

    function closeAllAcross() {
        var m = _clone()
        for (var k in m) m[k].open = ""
        _commit(m)
    }

    // True if `panel` is open on any screen — used by IPC toggles that want
    // global "is this panel showing somewhere?" semantics.
    function isOpenAnywhere(panel) {
        for (var k in stateMap) if (stateMap[k].open === panel) return true
        return false
    }

    // True if any screen has any panel open — drives the mutual exclusion
    // with the Settings window.
    function anyOpenAnywhere() {
        for (var k in stateMap) if (stateMap[k].open !== "") return true
        return false
    }

    // Open the same panel on all screens (IPC entry point — no per-screen
    // routing yet). `side` is the holder that should show it ("" = wildcard).
    function openGlobal(panel, side) {
        var screens = Quickshell.screens
        var s = side || ""
        var m = {}
        for (var i = 0; i < screens.length; i++) m[screens[i].name] = { open: panel, side: s }
        _commit(m)
    }

    function toggleGlobal(panel, side) {
        var s = side || ""
        // Find where this panel is currently open (side is uniform — panels are
        // global). Close if it's open on a compatible side (same, or either
        // wildcard); switch sides if open on a *different* concrete side; else open.
        var openSide = null
        for (var k in stateMap) if (stateMap[k].open === panel) { openSide = (stateMap[k].side || ""); break }
        if (openSide !== null && (s === "" || openSide === "" || openSide === s)) closeAllAcross()
        else openGlobal(panel, s)
    }

    property Connections _screensConn: Connections {
        target: Quickshell
        function onScreensChanged() {
            var current = Quickshell.screens
            var existing = root.stateMap
            var next = {}
            for (var i = 0; i < current.length; i++) {
                var name = current[i].name
                next[name] = existing[name] || { open: "", side: "" }
            }
            root.stateMap = next
        }
    }

    Component.onCompleted: {
        root.stateMap = _emptyForScreens(Quickshell.screens)
        console.log("[ShellState] initialised for screens:", Quickshell.screens.map(function(s) { return s.name }).join(" "))
    }
}
