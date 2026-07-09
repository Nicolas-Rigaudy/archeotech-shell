import QtQuick
import "../../Commons" as Commons
import "../../Services/Hardware" as HardwareServices
import "../../Services/Persistence" as Persistence

// Battery percentage + charging state. Hidden when no battery present.
// Not clickable — hover-only popup; icon keeps its state colour (no hover tint).
BarPill {
    id: root
    visible: HardwareServices.Battery.present && Persistence.Config.get("bar.modules.battery", true)
    interactive: false
    highlightOnHover: false

    readonly property bool _low: HardwareServices.Battery.percent <= 20
    icon: HardwareServices.Battery.icon()
    iconColor: _low ? Commons.Appearance.colors.red : Commons.Appearance.colors.green
    text: HardwareServices.Battery.percent + "%"
    textColor: _low ? Commons.Appearance.colors.red : Commons.Appearance.colors.overlay1

    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "BATTERY",
        HardwareServices.Battery.icon() + "  " + HardwareServices.Battery.percent + "%",
        HardwareServices.Battery.charging ? "󰂄  Charging" : "󱉞  On battery", "")
    onExited: if (holderRoot) holderRoot.hidePopup(root)
}
