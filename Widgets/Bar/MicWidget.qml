import QtQuick
import "../../Commons" as Commons
import "../../Services/Media" as MediaServices

// Microphone mute toggle. Icon-only (no value text). BarPill handles the H/V fork.
BarPill {
    id: root
    icon: MediaServices.Audio.micMuted ? "󰍭" : "󰍬"
    iconColor: MediaServices.Audio.micMuted ? Commons.Appearance.colors.red : Commons.Appearance.colors.overlay1

    onClicked: MediaServices.Audio.toggleMicMute()
    onEntered: if (holderRoot && holderRoot.horizontal) holderRoot.showPopup(root, "MICROPHONE",
        MediaServices.Audio.micMuted ? "󰍭  Muted" : "󰍬  Active", "", "Click to toggle")
    onExited: if (holderRoot) holderRoot.hidePopup(root)

    Connections {
        target: MediaServices.Audio
        function onMicMutedChanged() {
            if (root.hovered && root.holderRoot && root.holderRoot._popupVisible)
                root.holderRoot._popupPrimary = MediaServices.Audio.micMuted ? "󰍭  Muted" : "󰍬  Active"
        }
    }
}
