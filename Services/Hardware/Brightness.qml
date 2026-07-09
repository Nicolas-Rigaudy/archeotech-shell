pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int percent: 50
    property int maxBrightness: 100

    Component.onCompleted: {
        maxReader.running  = true
        currReader.running = true
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

    // ── Actions ────────────────────────────────────────────────────────────────

    property var _cmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: currReader.running = true
    }

    function setBrightness(pct) {
        var clamped = Math.max(1, Math.min(100, Math.round(pct)))
        _cmd.cmd = "brightnessctl set " + clamped + "% -q"
        _cmd.running = true
    }

    function adjust(delta) {
        setBrightness(root.percent + delta)
    }
}
