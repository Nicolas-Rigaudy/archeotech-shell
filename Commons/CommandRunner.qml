import QtQuick
import Quickshell.Io

// Runs commands one at a time without ever dropping one.
//
// A single reused Process silently ignores `running = true` while it is still
// busy, so a second command issued during the first was lost (a tag click during
// a window-decoration script; a quick second theme pick that the UI showed but
// never applied). run() queues instead.
//
//   coalesce: false  run every command, in order (compositor actions, theme apply)
//   coalesce: true   while busy keep only the NEWEST pending command (slider-style
//                    setters where intermediate values are worthless: brightness)
//
// run() takes an argv array; runShell() wraps a bash -c string for the call sites
// that build shell pipelines.
QtObject {
    id: root

    property bool   coalesce: false
    property string label: ""          // prefix for the non-zero-exit warning
    readonly property bool busy: _proc.running

    signal finished(var argv, int exitCode)

    property var _pending: []

    property Process _proc: Process {
        running: false
        onExited: (code, status) => {
            if (code !== 0 && root.label)
                console.warn(root.label + ": command exited with code " + code + ":", JSON.stringify(_proc.command))
            root.finished(_proc.command, code)
            root._next()
        }
    }

    function run(argv) {
        _pending = coalesce ? [argv] : _pending.concat([argv])
        if (!_proc.running) _next()
    }

    function runShell(cmd) { run(["bash", "-c", cmd]) }

    // Called from the Process's own onExited: reassigning `command` and restarting
    // there is safe in Quickshell 0.3.1 (harness 2026-09-28, task_038: three
    // back-to-back jobs all ran, in order).
    function _next() {
        if (_pending.length === 0) return
        var argv = _pending[0]
        _pending = _pending.slice(1)
        _proc.command = argv
        _proc.running = true
    }
}
