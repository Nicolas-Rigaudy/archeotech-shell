import QtQuick
import Quickshell.Io
import "../../Commons" as Commons

// Power button — launches wlogout. Icon-only on a vertical bar (BarPill fork).
BarPill {
    id: root
    icon: "󰐥"
    iconColor:  Commons.Appearance.colors.subtext1
    hoverColor: Commons.Appearance.colors.red

    Process { id: powerCmd; command: ["bash", "-c", "wlogout-launch.sh &"]; running: false }

    onClicked: powerCmd.running = true
    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "POWER", "󰐥  Power menu", "", "Click to open")
    onExited:  if (holderRoot) holderRoot.hidePopup(root)
}
