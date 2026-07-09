import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence
import "../../../Widgets/Appearance" as Appearance
import "../Widgets"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰔯"
            title: "Appearance"
            description: "Customize the visual style and typography of the shell"
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: col.implicitHeight + 32
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: col
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 24; leftMargin: 24; rightMargin: 24 }
                width: root.width - 48
                spacing: 12

                // ── Colour scheme (family → flavor + light/dark + schedule) ───
                // Shared ColorSchemeBody (also powers the bottom Appearance
                // switcher in compact mode). Provides its own section labels.
                Appearance.ColorSchemeBody {
                    Layout.fillWidth: true
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Behavior ──────────────────────────────────────────────────
                SectionLabel { text: "BEHAVIOR" }
                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: behCol.implicitHeight

                    ColumnLayout {
                        id: behCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                        ToggleRow {
                            label: "Restart Zen on theme change"
                            description: "Zen only recolors on restart; auto-restart it (debounced) so it follows the theme"
                            checked: Persistence.Config.get("colorScheme.restartZen", true)
                            onToggled: v => Persistence.Config.set("colorScheme.restartZen", v)
                        }
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Wallpaper & Logo ──────────────────────────────────────────
                // Embeds the shared WallpaperPickerBody so theme + wallpaper +
                // logo all live in one Appearance pane (Sprint 24). The bottom-
                // strip WallpaperPicker panel reuses the same component.
                SectionLabel { text: "WALLPAPER & LOGO" }

                Appearance.WallpaperPickerBody {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64 + Commons.Appearance.spacing.md + 1
                                          + Commons.Appearance.spacing.md + 200
                    embedded: true
                    carouselHeight: 200
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Typography ────────────────────────────────────────────────
                SectionLabel { text: "TYPOGRAPHY" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: typoCol.implicitHeight

                    ColumnLayout {
                        id: typoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0

                        Item { implicitHeight: 4; Layout.fillWidth: true }
                        SliderRow {
                            label: "Font Size Scale"
                            description: "Scales all text relative to the base size"
                            from: 0.8; to: 1.4; stepSize: 0.05
                            value: Persistence.Config.get("appearance.fontScale", 1.0)
                            valueDisplay: Math.round(value * 100) + "%"
                            onMoved: Persistence.Config.set("appearance.fontScale", value)
                        }
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Geometry ──────────────────────────────────────────────────
                SectionLabel { text: "GEOMETRY" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: geoCol.implicitHeight

                    ColumnLayout {
                        id: geoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0

                        Item { implicitHeight: 4; Layout.fillWidth: true }
                        SliderRow {
                            label: "Corner Rounding"
                            description: "Scales all border radii"
                            from: 0.5; to: 2.0; stepSize: 0.1
                            value: Persistence.Config.get("appearance.radiusScale", 1.0)
                            valueDisplay: value.toFixed(1) + "×"
                            onMoved: Persistence.Config.set("appearance.radiusScale", value)
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.base }
                        SliderRow {
                            label: "Padding Scale"
                            description: "Scales spacing inside panels"
                            from: 0.5; to: 2.0; stepSize: 0.1
                            value: Persistence.Config.get("appearance.paddingScale", 1.0)
                            valueDisplay: value.toFixed(1) + "×"
                            onMoved: Persistence.Config.set("appearance.paddingScale", value)
                        }
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

}
