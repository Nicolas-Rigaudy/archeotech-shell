pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons" as Commons
import "DisplaysLogic.js" as Logic

// Display outputs (item_135 wave 1): the REAL state of every connected output,
// read from `wlr-randr --json` (wlr-output-management, so it works under MangoWC
// and Hyprland alike), plus apply-with-revert for the Settings → Display editor.
//
// outputs[]: { name, make, model, serial, description, enabled, x, y,
//              width, height, refresh,          // current mode (physical px)
//              transform, scale,                // "normal" | "90" | "180" | "270" | flipped…
//              modes: [{ width, height, refresh, preferred }] }
// Re-read on start, on every hotplug (Quickshell.screens changes) and after an
// apply. wlr-randr lists only CONNECTED outputs, so an unplugged screen drops out.
QtObject {
    id: root

    property var  outputs: []
    property bool ready: false
    // Set while an applied change awaits "Keep" (revert snapshot = previous outputs).
    property var  revertSnapshot: null
    readonly property bool pendingConfirm: revertSnapshot !== null
    readonly property int  confirmSeconds: 15
    property int  confirmLeft: 0

    // ── Read ──────────────────────────────────────────────────────────────────
    property bool _again: false   // a refresh asked for mid-read runs right after it
    property var _reader: Process {
        command: ["wlr-randr", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
        onExited: (code, status) => { if (root._again) { root._again = false; running = true } }
    }
    function refresh() { if (_reader.running) _again = true; else _reader.running = true }

    function _parse(text) {
        var out = Logic.parse(text)
        if (out === null) return
        // Unchanged state keeps the same array, so polling never rebuilds the
        // editor (that killed a drag in progress and closed open dropdowns).
        if (JSON.stringify(out) !== JSON.stringify(root.outputs)) root.outputs = out
        root.ready = true
    }

    // Debounced re-read on hotplug: the compositor settles the new output first.
    property var _hotplug: Timer { interval: 600; onTriggered: root.refresh() }
    property var _screensConn: Connections {
        target: Quickshell
        function onScreensChanged() { root._hotplug.restart() }
    }
    Component.onCompleted: refresh()

    // ── Geometry helper (DisplaysLogic.js) ────────────────────────────────────
    function logicalSize(o) { return Logic.logicalSize(o) }

    // ── Apply / revert ────────────────────────────────────────────────────────
    property var _runner: Commons.CommandRunner { label: "wlr-randr" }
    property var _applyArgv: null      // the argv of the apply awaiting "Keep"
    property string lastError: ""
    property var _afterApply: Connections {
        target: root._runner
        function onFinished(argv, code) {
            // A failed apply changed nothing: drop the countdown instead of
            // "reverting" a layout that never took effect.
            // Content compare: Process.command hands back a fresh array each read.
            if (code !== 0 && JSON.stringify(argv) === JSON.stringify(root._applyArgv)) {
                root._countdown.stop()
                root.revertSnapshot = null
                root.lastError = "The display settings could not be applied (wlr-randr exit " + code + ")."
            }
            root.refresh()
        }
    }
    // Only outputs that are connected NOW: wlr-randr rejects the whole call when
    // it names an unplugged output (e.g. unplugged during the countdown).
    function _connected(list) {
        var names = {}
        root.outputs.forEach(o => names[o.name] = true)
        return list.filter(o => names[o.name])
    }

    function _argv(list) { return Logic.argv(list) }

    // Apply a staged layout and arm the auto-revert countdown. Refuses a layout
    // with no enabled output (nothing left to click "Revert" on) or overlapping
    // outputs.
    // `confirm`: arm the keep/revert countdown (risky changes: a mode, rotation,
    // scale or a screen turned off can leave a screen blank). Moving screens
    // around applies straight away.
    function apply(staged, confirm) {
        if (root.pendingConfirm) return false   // never overwrite the revert snapshot
        var list = _connected(staged)
        if (!list.some(o => o.enabled) || Logic.hasOverlap(list)) return false
        root.lastError = ""
        root._applyArgv = _argv(list)
        if (confirm) {
            root.revertSnapshot = JSON.parse(JSON.stringify(root.outputs))
            root.confirmLeft = root.confirmSeconds
            _countdown.restart()
        }
        _runner.run(root._applyArgv)
        return true
    }
    function keep() { _countdown.stop(); root.revertSnapshot = null }
    function revert() {
        _countdown.stop()
        var snap = root.revertSnapshot
        root.revertSnapshot = null
        if (!snap) return
        var list = _connected(snap)
        if (list.some(o => o.enabled)) _runner.run(_argv(list))
    }
    property var _countdown: Timer {
        interval: 1000; repeat: true
        onTriggered: {
            root.confirmLeft -= 1
            if (root.confirmLeft <= 0) root.revert()
        }
    }
}
