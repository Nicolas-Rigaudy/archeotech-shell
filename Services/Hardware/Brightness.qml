pragma Singleton
import QtQuick
import Quickshell.Io

// Screen backlight. `percent` is kept in sync with the REAL device via a udev
// backlight monitor, so external changes (XF86 brightness keys, which run
// `brightnessctl` directly — see mango config.conf) are reflected immediately.
// Without this the stored value went stale and scroll-adjust computed its next
// target from a wrong base, yanking brightness to the wrong level.
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
            onRead: data => {
                var v = parseInt(data.trim())
                if (v > 0) root.maxBrightness = v
            }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Brightness: maxReader exited with code " + code)
        }
    }

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
        onExited: (code, status) => {
            if (code !== 0) console.warn("Brightness: currReader exited with code " + code)
        }
    }

    // Event source: the kernel backlight class emits a udev `change` event on
    // every brightness write (ours or the XF86 keys'), so we re-read on each.
    property var monitor: Process {
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        running: false
        stdout: SplitParser {
            onRead: _line => { if (_line.indexOf("UDEV") !== -1) root.currReader.running = true }
        }
        // Auto-restart if the monitor ever dies, so we never silently go stale.
        onExited: (code, status) => root._monRestart.start()
    }
    property var _monRestart: Timer {
        interval: 1000; repeat: false
        onTriggered: root.monitor.running = true
    }

    // ── Actions ────────────────────────────────────────────────────────────────

    property var _cmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: root.currReader.running = true
    }

    function setBrightness(pct) {
        var clamped = Math.max(1, Math.min(100, Math.round(pct)))
        // Optimistic: update immediately so relative math (adjust) and rapid
        // scrolling accumulate from the intended value, not a stale async read.
        // The udev monitor / currReader then reconciles with the real device.
        root.percent = clamped
        _cmd.cmd = "brightnessctl set " + clamped + "% -q"
        _cmd.running = true
    }

    function adjust(delta) {
        setBrightness(root.percent + delta)
    }
}
