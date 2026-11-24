pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons" as Commons

// Presentation mode (item_187). The dotfiles script presentation-mode.sh does
// the work (mango opacity 1.0 for windows opened from now on, kitty opaque) and
// is the one writer of its state file, $XDG_RUNTIME_DIR/presentation-mode.state
// ("on" / "off"). This singleton only reads that file, so the Super+Shift+O
// keybind and the shell toggles always agree: `active` is never flipped here
// ahead of the script (no fake toggle, design rule 6).
//
// While active, shell.qml also keeps notification popups away (they still land
// in the notification centre); the user's own Do Not Disturb is left alone.
QtObject {
    id: root

    readonly property bool active: _state === "on"
    readonly property bool busy: _run.running
    property string _state: "off"

    readonly property string _script: Commons.Paths.localBin + "/presentation-mode.sh"
    readonly property string _path:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/presentation-mode.state"

    function toggle() { _exec("toggle") }
    function setActive(on) { if (on !== active) _exec(on ? "on" : "off") }

    function _exec(arg) {
        if (_run.running) return
        _run.command = [_script, arg]
        _run.running = true
    }

    // A Process, not execDetached: the file is re-read when the script exits,
    // in case the watch missed the write.
    property Process _run: Process {
        running: false
        onExited: root._file.reload()
    }

    property FileView _file: FileView {
        path: root._path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._state = text().trim() === "on" ? "on" : "off"
        // No file yet (the script has not run this login): create it as "off",
        // so the watch has a file to follow when the keybind first writes it.
        onLoadFailed: {
            root._state = "off"
            setText("off\n")
        }
    }
}
