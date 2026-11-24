import QtQuick
import "../../Commons" as Commons
import "../../Services/System" as SysSvc
import "../../Services/System/StorageLogic.js" as Logic

// Disk use of / (item_184): used % on the bar, red / peach when free space is
// critical / low (same thresholds as disk-alert). Click opens the Storage panel.
BarPill {
    id: root

    readonly property string _level: SysSvc.Storage.level
    readonly property color _tint: _level === "critical" ? Commons.Appearance.colors.red
                                 : _level === "warn" ? Commons.Appearance.colors.peach
                                 : Commons.Appearance.colors.textSecondary
    icon: "󰋊"
    iconColor: _tint
    text: SysSvc.Storage.rootInfo ? SysSvc.Storage.usedPct + "%" : ""
    textColor: _level === "critical" || _level === "warn" ? _tint : Commons.Appearance.colors.textMuted

    onClicked: { if (holderRoot) { holderRoot.dismissPopups(); holderRoot.togglePanel("storage", "") } }
    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "STORAGE",
        _popupPrimary(), _popupSecondary(), "Click to open")
    onExited: if (holderRoot) holderRoot.hidePopup(root)

    function _popupPrimary() {
        var s = SysSvc.Storage
        return "󰋊  " + Logic.formatBytes(s.free) + " free of " + Logic.formatBytes(s.size)
    }
    function _popupSecondary() {
        var s = SysSvc.Storage
        if (s.metadataTight) return "󰀦  btrfs metadata almost full"
        return s.usedPct + "% used"
    }

    Connections {
        target: SysSvc.Storage
        function onRootInfoChanged() {
            if (root.hovered && root.holderRoot && root.holderRoot._popupVisible) {
                root.holderRoot._popupPrimary   = root._popupPrimary()
                root.holderRoot._popupSecondary = root._popupSecondary()
            }
        }
    }
}
