import QtQuick
import "../../Commons" as Commons
import "../../Services/Networking" as NetworkServices
import "../../Services/Persistence" as Persistence

// Bluetooth toggle + paired-device picker (popup hosted by Bar.qml). Icon-only.
// ponytail: popup anchors on a horizontal X coord (see NetworkWidget note).
BarPill {
    id: root
    visible: Persistence.Config.get("bar.modules.bluetooth", true)
    icon: NetworkServices.Bluetooth.icon()
    iconColor: NetworkServices.Bluetooth.connected ? Commons.Appearance.colors.mauve
             : NetworkServices.Bluetooth.enabled   ? Commons.Appearance.colors.subtext1
             :                                        Commons.Appearance.colors.overlay0

    onClicked: {
        if (!holderRoot) return
        if (holderRoot._btPopupVisible) {
            holderRoot._btPopupVisible = false
        } else {
            var pt = root.mapToItem(holderRoot, root.width / 2, 0)
            holderRoot._btAnchorX        = pt.x
            holderRoot._btPopupVisible   = true
            holderRoot._wifiPopupVisible = false
            holderRoot._calendarVisible  = false
            holderRoot._popupVisible     = false
        }
    }
    onEntered: if (holderRoot && holderRoot.horizontal && !holderRoot._btPopupVisible)
        holderRoot.showPopup(root, "BLUETOOTH",
            NetworkServices.Bluetooth.connected ? "󰂱  " + NetworkServices.Bluetooth.device
                : NetworkServices.Bluetooth.enabled ? "󰂯  On — no device" : "󰂲  Off",
            "", "Click to manage Bluetooth")
    onExited: if (holderRoot) holderRoot.hidePopup(root)
}
