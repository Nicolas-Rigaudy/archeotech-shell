import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons
import "../../../../Services/Shell" as ShellServices
import "../../../../Widgets/Appearance" as Appearance

// Appearance quick-switcher panel (Super+W → this; bottom strip). Compact
// version of Settings → Appearance: colour scheme (family/flavor/mode) +
// wallpaper carousel + logos, sharing the exact ColorSchemeBody /
// WallpaperPickerBody components so there's no duplicated logic. A gear
// shortcut opens the full Settings pane (schedule, typography, geometry).
Item {
    id: root
    anchors.fill: parent

    property var panelRoot: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Commons.Appearance.spacing.lg
        spacing: Commons.Appearance.spacing.md

        // Header — title + shortcut to full appearance settings.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "󰏘  Appearance"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.family: Commons.Appearance.font.family
                font.weight: Font.Medium
            }

            Rectangle {
                id: moreBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: _moreRow.implicitWidth + 16; height: 26
                radius: Commons.Appearance.radius.base
                property bool _hovered: false
                color: _hovered ? Commons.Appearance.colors.surface0Alpha : "transparent"
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                RowLayout {
                    id: _moreRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "󰒓"
                        color: moreBtn._hovered ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: 13; font.family: Commons.Appearance.font.family
                    }
                    Text {
                        text: "More"
                        color: moreBtn._hovered ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: moreBtn._hovered = true
                    onExited:  moreBtn._hovered = false
                    onClicked: {
                        Commons.State.settingsOpenPane = "appearance"
                        ShellServices.ShellState.openGlobal("settings")
                    }
                }
            }
        }

        // Colour scheme (family/flavor/mode) — compact, shared with Settings.
        Appearance.ColorSchemeBody {
            Layout.fillWidth: true
            compact: true
        }

        // Wallpaper carousel + logo tiles (shared body, fills remaining space).
        Appearance.WallpaperPickerBody {
            Layout.fillWidth: true
            Layout.fillHeight: true
            panelRoot: root.panelRoot
            embedded: true     // own chrome above; keep logos + carousel
            carouselHeight: 0  // fill remaining height
        }
    }
}
