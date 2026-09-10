import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons
import "../../../../Commons/Primitives"
import "../../../../Services/Shell" as ShellServices
import "../../../../Widgets/Appearance" as Appearance

// Appearance quick-switcher panel (Super+W). Tabbed: one carousel visible at a
// time (Wallpaper / Theme / Logo) so each gets the full panel height instead of
// being crammed into a vertical stack. All three reuse the shared Carousel, and
// the Theme/Wallpaper/Logo bodies are the exact components Settings uses. A gear
// shortcut opens the full Settings pane (schedule, typography, geometry).
Item {
    id: root
    anchors.fill: parent

    property var panelRoot: null
    property int tab: 0     // 0 wallpaper · 1 theme · 2 logo

    // Orientation follows the holder: horizontal for top/bottom, vertical for
    // left/right. Strip exposes `_horizontal`, BarPanel exposes `horizontal` —
    // accept either so the picker works from both holders on every side.
    readonly property bool _panelHorizontal:
        !panelRoot ? true
        : panelRoot._horizontal !== undefined ? panelRoot._horizontal
        : panelRoot.horizontal  !== undefined ? panelRoot.horizontal
        : true
    readonly property bool _vertical: !_panelHorizontal
    // Along-strip extent for axisSize:"auto" — panel width when horizontal,
    // panel height when vertical (kept modest so a side panel isn't full-screen).
    readonly property real implicitAxis: _vertical ? 620 : 1120

    readonly property var _tabs: [
        { label: "Wallpaper", glyph: "󰸉" },
        { label: "Theme",     glyph: "󰏘" },
        // MDI star — the earlier Font-Logos glyph isn't in the UI font, so it
        // rendered blank in icon-only (vertical) mode.
        { label: "Logo",      glyph: "󰓎" }
    ]

    ColumnLayout {
        anchors.fill: parent
        // Panel content padding + inter-item gap — the shared xl (16) standard so
        // every panel feels equally roomy (see docs/WIDGET_API.md “Panel padding”).
        anchors.margins: Commons.Appearance.spacing.xl
        spacing: Commons.Appearance.spacing.xl

        // Header — tab bar + shortcut to full appearance settings. A RowLayout
        // (not absolute anchors) so the tabs and the More button can never
        // overlap; labels collapse to icons when vertical (narrow side panels).
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                spacing: 6

            // Page selector — shared segmented control (see SegmentedControl).
            SegmentedControl {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                model: root._tabs
                currentIndex: root.tab
                iconOnly: root._vertical
                onActivated: index => root.tab = index
            }

            Rectangle {
                id: moreBtn
                implicitWidth: _moreRow.implicitWidth + 16
                Layout.preferredHeight: 26
                radius: Commons.Appearance.radius.base
                property bool _hovered: false
                color: _hovered ? Commons.Appearance.colors.surface0Alpha : "transparent"
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                Row {
                    id: _moreRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "󰒓"
                        color: moreBtn._hovered ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: 13; font.family: Commons.Appearance.font.family
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: !root._vertical
                        text: "More"
                        color: moreBtn._hovered ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
                        anchors.verticalCenter: parent.verticalCenter
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
            }   // RowLayout
        }       // header Rectangle

        // Active tab fills the rest — each carousel gets the full panel height.
        // No clip here: the horizontal carousel is meant to peek off the left/
        // right edges. In vertical mode the top peek is occluded by the header
        // backing above; the bottom peek shows off the panel.
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tab

            Appearance.WallpaperPickerBody {
                panelRoot: root.panelRoot
                embedded: true
                carouselHeight: 0   // fill
                vertical: root._vertical
            }
            Appearance.ThemeCarousel { vertical: root._vertical }
            Appearance.LogoCarousel {
                panelRoot: root.panelRoot
                vertical: root._vertical
            }
        }
    }
}
