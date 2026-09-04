pragma Singleton
import QtQuick
import Quickshell.Services.UPower

// Battery state, event-driven off UPower's D-Bus signals — updates INSTANTLY on
// plug/unplug and charge changes, no polling. (Was a 30s sysfs poll, which made
// the bar lag up to 30s behind reality when you plugged in the charger.)
QtObject {
    id: root

    readonly property var _dev: UPower.displayDevice

    readonly property bool present:  _dev ? _dev.isPresent : false

    // Quickshell reports percentage as a 0.0–1.0 ratio; defensively accept a
    // 0–100 value too in case that ever changes.
    readonly property int percent: {
        if (!_dev) return 0
        var p = _dev.percentage
        return Math.round(p <= 1.0 ? p * 100 : p)
    }

    readonly property bool charging: _dev
        ? (_dev.state === UPowerDeviceState.Charging
           || _dev.state === UPowerDeviceState.FullyCharged)
        : false

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
