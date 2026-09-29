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
    textColor: _low ? Commons.Appearance.colors.red : Commons.Appearance.colors.textMuted

    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "BATTERY",
        _popupPrimary(), _popupSecondary(), "")
    onExited: if (holderRoot) holderRoot.hidePopup(root)

    function _popupPrimary()   { return HardwareServices.Battery.icon() + "  " + HardwareServices.Battery.percent + "%" }
    function _popupSecondary()  { return HardwareServices.Battery.charging ? "󰂄  Charging" : "󱉞  On battery" }

    // Keep the popup live while hovered — charge % and charging state can change
    // while the pointer sits on the pill (was a static snapshot taken on enter).
    Connections {
        target: HardwareServices.Battery
        function onPercentChanged()  { root._refreshPopup() }
        function onChargingChanged() { root._refreshPopup() }
    }
    function _refreshPopup() {
        if (root.hovered && root.holderRoot && root.holderRoot._popupVisible) {
            root.holderRoot._popupPrimary   = _popupPrimary()
            root.holderRoot._popupSecondary = _popupSecondary()
        }
    }
}
