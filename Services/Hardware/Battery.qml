pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int  percent:  0
    property bool charging: false
    property bool present:  true

    Component.onCompleted: { readLevel.running = true; readStatus.running = true }

    property var readLevel: Process {
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                root.percent  = isNaN(v) ? 0 : v
                root.present  = !isNaN(v)
            }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Battery: readLevel exited with code " + code)
        }
    }

    property var readStatus: Process {
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                root.charging = (s === "Charging" || s === "Full")
            }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Battery: readStatus exited with code " + code)
        }
    }

    property var _timer: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: { readLevel.running = true; readStatus.running = true }
    }

    // Icon helper — call from QML as Battery.icon()
    function icon() {
        if (charging) return "󰂄"
        if (percent > 90) return "󰂂"
        if (percent > 70) return "󰂀"
        if (percent > 50) return "󰁿"
        if (percent > 30) return "󰁼"
        if (percent > 20) return "󰁻"
        if (percent > 10) return "󰁺"
        return "󰂃"
    }
}
