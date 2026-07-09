import QtQuick
import "../../Commons" as Commons

// Settings gear — toggles the Settings panel. Icon-only vertical (BarPill).
BarPill {
    id: root
    icon: "󰒓"
    iconColor: Commons.Appearance.colors.subtext1

    onClicked: {
        if (holderRoot) { holderRoot.dismissPopups(); holderRoot.togglePanel("settings", "") }
    }
    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "SETTINGS", "󰒓  Settings", "", "Click to toggle")
    onExited:  if (holderRoot) holderRoot.hidePopup(root)
}
