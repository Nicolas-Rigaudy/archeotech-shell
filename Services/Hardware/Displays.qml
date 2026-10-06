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
    // 20 s (GNOME's figure), counted from when the change has APPLIED: a mode
    // or refresh switch can take a couple of seconds to settle on the screen.
    readonly property int  confirmSeconds: 20
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

    // ── Profiles (item_135 wave 2) ────────────────────────────────────────────
    // Saved layouts per monitor SET, owned by scripts/display-profile.py (also
    // run by the hotplug daemon, so profiles apply with or without the shell).
    // This checkout's copy is used, so it works before install.sh links it.
    readonly property string _profileTool: decodeURIComponent(Qt.resolvedUrl("../../scripts/display-profile.py").toString().replace("file://", ""))
    property var    profiles: []          // [{ name, monitors: [connector…] }]
    property string activeProfile: ""     // the profile matching the connected monitors
    property bool   autoApply: true
    // Set when the profile tool could not be read (shown instead of a false
    // "No profiles yet"), e.g. a pinned checkout that predates the tool.
    property string profileError: ""
    property bool _profileAgain: false
    property var _profileReader: Process {
        command: ["python3", root._profileTool, "status", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    root.profiles = d.profiles || []
                    root.activeProfile = d.active || ""
                    root.autoApply = d.autoApply !== false
                    root.profileError = ""
                } catch (e) {
                    root.profileError = "Could not read display profiles"
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.profileError = "Could not read display profiles (display-profile.py exit " + code + ")"
            if (root._profileAgain) { root._profileAgain = false; running = true }
        }
    }
    function refreshProfiles() { if (_profileReader.running) _profileAgain = true; else _profileReader.running = true }
    property var _profileRunner: Commons.CommandRunner { label: "display-profile" }
    property var _afterProfile: Connections {
        target: root._profileRunner
        function onFinished(argv, code) { root.refreshProfiles(); root.refresh() }
    }
    function saveProfile(name) {
        name = (name || "").trim()
        if (name) _profileRunner.run(["python3", root._profileTool, "save", name])
    }
    function deleteProfile(name) { _profileRunner.run(["python3", root._profileTool, "delete", name]) }
    function setAutoApply(on) { _profileRunner.run(["python3", root._profileTool, "set-auto", on ? "on" : "off"]) }
    // A different SET of screens (dock/undock, possibly with the hotplug daemon
    // applying a profile) makes a pending revert snapshot stale: reverting would
    // put a pre-dock layout back over the new one, so drop the countdown.
    property string _outputSet: ""
    onOutputsChanged: {
        var set = root.outputs.map(o => o.name).sort().join(",")
        if (root._outputSet !== "" && set !== root._outputSet && root.pendingConfirm) root.keep()
        root._outputSet = set
        refreshProfiles()
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
            var isApply = JSON.stringify(argv) === JSON.stringify(root._applyArgv)
            if (isApply && code === 0 && root.pendingConfirm) {
                root.confirmLeft = root.confirmSeconds
                root._countdown.restart()
            }
            if (code !== 0 && isApply) {
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
            // The countdown starts once wlr-randr returns (see _afterApply).
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
