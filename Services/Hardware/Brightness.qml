pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons

// Screen backlight.
//
// Design (race-free): OUR OWN sets are authoritative — `brightnessctl set N%`
// reliably yields N% (verified: max divides cleanly), so we set `percent`
// optimistically and never read it back. That keeps scroll/adjust exact and
// snappy and — critically — stops a stale readback from clobbering the value
// (the earlier "scroll to 100 lands on 90" bug). EXTERNAL changes (the XF86
// keys run `brightnessctl` directly, see mango config.conf) are picked up via a
// udev backlight monitor, guarded so our own set's echo event is ignored.
QtObject {
    id: root

    property int percent: 50
    property int maxBrightness: 100

    Component.onCompleted: {
        maxReader.running  = true
        currReader.running = true
        monitor.running    = true
    }

    property var maxReader: Process {
        command: ["bash", "-c", "brightnessctl max"]
        running: false
        stdout: SplitParser {
            onRead: data => { var v = parseInt(data.trim()); if (v > 0) root.maxBrightness = v }
        }
    }

    // Reads the real device level → percent. Used at startup and for EXTERNAL
    // changes only (never right after our own set — that would race).
    property var currReader: Process {
        command: ["bash", "-c", "brightnessctl get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                if (root.maxBrightness > 0)
                    root.percent = Math.round(v / root.maxBrightness * 100)
            }
        }
    }

    // Event source: the kernel backlight class emits a udev event on every
    // brightness write. Re-read on external ones; skip the echo from our own set
    // (guarded) so it can't clobber the optimistic value.
    property var monitor: Process {
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        running: false
        stdout: SplitParser {
            onRead: _line => {
                if (_line.indexOf("UDEV") !== -1 && !root._selfGuard.running)
                    root.currReader.running = true
            }
        }
        onExited: (code, status) => root._monRestart.start()
    }
    property var _monRestart: Timer { interval: 1000; repeat: false; onTriggered: root.monitor.running = true }

    // While running, udev events are treated as our own set's echo and ignored.
    property var _selfGuard: Timer { interval: 500; repeat: false }

    // Coalescing: while one write runs, only the newest requested value is kept,
    // so a slider drag ends on the value the user let go at (it used to drop it).
    property var _cmd: Commons.CommandRunner { coalesce: true; label: "Brightness" }

    function setBrightness(pct) {
        var clamped = Math.max(1, Math.min(100, Math.round(pct)))
        root.percent = clamped          // authoritative — set N% yields N%
        root._selfGuard.restart()       // ignore the udev echo from this write
        _cmd.run(["brightnessctl", "set", clamped + "%", "-q"])
    }

    function adjust(delta) { setBrightness(root.percent + delta) }
}
