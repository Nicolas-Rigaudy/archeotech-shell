import QtQuick
import "../../Commons" as Commons
import "../../Services/Networking" as NetworkServices
import "../../Services/Persistence" as Persistence

// WiFi/ethernet status. Click opens the WiFi popup hosted by Bar.qml
// (state in holderRoot._wifiPopupVisible / _wifiAnchorX). Icon-only (BarPill).
// ponytail: the popup anchors on a horizontal-bar X coord — on a vertical bar
// it would misposition; vertical popup anchoring is a later pass (S26-C note).
BarPill {
    id: root
    visible: Persistence.Config.get("bar.modules.wifi", true)
    icon: NetworkServices.Network.icon()
    iconColor: NetworkServices.Network.connected ? Commons.Appearance.colors.blue : Commons.Appearance.colors.overlay0

    onClicked: {
        if (!holderRoot) return
        if (holderRoot._wifiPopupVisible) {
            holderRoot._wifiPopupVisible = false
        } else {
            var pt = root.mapToItem(holderRoot, root.width / 2, 0)
            holderRoot._wifiAnchorX      = pt.x
            holderRoot._wifiPopupVisible = true
            holderRoot._btPopupVisible   = false
            holderRoot._calendarVisible  = false
            holderRoot._popupVisible     = false
        }
    }
    onEntered: if (holderRoot && holderRoot.horizontal && !holderRoot._wifiPopupVisible)
        holderRoot.showPopup(root, "NETWORK",
            NetworkServices.Network.connected
                ? "󰖩  " + NetworkServices.Network.ssid + "   ·   " + NetworkServices.Network.signal + "%  ·  " + NetworkServices.Network.band
                : "󰖪  Disconnected",
            "", "Click to manage WiFi")
    onExited: if (holderRoot) holderRoot.hidePopup(root)
}
