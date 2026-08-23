import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence
import "../../../Services/Shell" as ShellServices
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

                // ── Style ─────────────────────────────────────────────────────
                SectionLabel { text: "STYLE" }
                SettingsCard {
                    ToggleRow {
                        label: "Flat mode"
                        description: "Drop the liquid-glass sheen + card shadows for a flatter look (some popups / edit-mode stay glassy until the polish rollout finishes)"
                        checked: Persistence.Config.get("appearance.flatMode", false)
                        onToggled: v => Persistence.Config.set("appearance.flatMode", v)
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Theme pack (adr_027 Layer A) ──────────────────────────────
                SectionLabel { text: "THEME PACK" }
                SettingsCard {
                    DropdownRow {
                        label: "Theme pack"
                        description: "Swap the shell's identity — colours, shape, type — over the base. Base = default glass."
                        currentValue: Persistence.Config.get("appearance.activePack", "")
                        options: {
                            var opts = [{ value: "", label: "Base (glass)" }]
                            var ps = ShellServices.PackRegistry.packs
                            for (var i = 0; i < ps.length; i++)
                                opts.push({ value: ps[i].id, label: ps[i].name || ps[i].id })
                            return opts
                        }
                        onSelected: v => Persistence.Config.set("appearance.activePack", v)
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Behavior ──────────────────────────────────────────────────
                SectionLabel { text: "BEHAVIOR" }
                SettingsCard {
                    ToggleRow {
                        label: "Restart Zen on theme change"
                        description: "Zen only recolors on restart; auto-restart it (debounced) so it follows the theme"
                        checked: Persistence.Config.get("colorScheme.restartZen", true)
                        onToggled: v => Persistence.Config.set("colorScheme.restartZen", v)
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Wallpaper ─────────────────────────────────────────────────
                // Shares the exact WallpaperPickerBody the quick-switcher tab
                // uses (Sprint 24/26). Settings stacks; the quick panel tabs.
                SectionLabel { text: "WALLPAPER" }

                Appearance.WallpaperPickerBody {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    embedded: true
                    carouselHeight: 200
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Logo ──────────────────────────────────────────────────────
                SectionLabel { text: "LOGO" }

                Appearance.LogoCarousel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Typography ────────────────────────────────────────────────
                SectionLabel { text: "TYPOGRAPHY" }

                SettingsCard {
                    SliderRow {
                        label: "Font Size Scale"
                        description: "Scales all text relative to the base size"
                        from: 0.8; to: 1.4; stepSize: 0.05
                        value: Persistence.Config.get("appearance.fontScale", 1.0)
                        valueDisplay: Math.round(value * 100) + "%"
                        onMoved: Persistence.Config.set("appearance.fontScale", value)
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Geometry ──────────────────────────────────────────────────
                SectionLabel { text: "GEOMETRY" }

                SettingsCard {
                    SliderRow {
                        label: "Corner Rounding"
                        description: "Scales all border radii"
                        from: 0.5; to: 2.0; stepSize: 0.1
                        value: Persistence.Config.get("appearance.radiusScale", 1.0)
                        valueDisplay: value.toFixed(1) + "×"
                        onMoved: Persistence.Config.set("appearance.radiusScale", value)
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    SliderRow {
                        label: "Padding Scale"
                        description: "Scales spacing inside panels"
                        from: 0.5; to: 2.0; stepSize: 0.1
                        value: Persistence.Config.get("appearance.paddingScale", 1.0)
                        valueDisplay: value.toFixed(1) + "×"
                        onMoved: Persistence.Config.set("appearance.paddingScale", value)
                    }
                }
            }
        }
    }

}
