import QtQuick
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices
import "../../Services/System" as SystemServices

// Notification bell + unread state. Click toggles the NC panel. Icon-only (BarPill).
BarPill {
    id: root
    readonly property bool _open: ShellServices.ShellState.isOpenAnywhere("nc")
    icon: "󰂚"
    iconColor: _open ? Commons.Appearance.colors.accent
             : SystemServices.Notifications.unreadCount > 0 ? Commons.Appearance.colors.red
             :                                                 Commons.Appearance.colors.subtext1

    onClicked: {
        if (holderRoot) { holderRoot._wifiPopupVisible = false; holderRoot._btPopupVisible = false }
        if (!_open) SystemServices.Notifications.unreadCount = 0
        ShellServices.ShellState.toggleGlobal("nc")
    }
    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "NOTIFICATIONS",
        SystemServices.Notifications.unreadCount > 0
            ? "󰂚  " + SystemServices.Notifications.unreadCount + " unread"
            : "󰂜  All caught up",
        SystemServices.Notifications.dndEnabled ? "󰂛  Do not disturb on" : "",
        "Click to toggle")
    onExited: if (holderRoot) holderRoot.hidePopup(root)
}
