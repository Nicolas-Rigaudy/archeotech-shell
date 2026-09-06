import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence
import "../../../Services/Shell" as ShellServices
import "../../../Commons/Primitives"
import "../../../Widgets/Appearance" as Appearance
import "../Widgets"

Item {
    id: root

    // Theme-pack options for the selector: Base + discovered packs (adr_027).
    readonly property var _packModel: {
        var m = [{ id: "", label: "Base" }]
        var ps = ShellServices.PackRegistry.packs
        for (var i = 0; i < ps.length; i++)
            m.push({ id: ps[i].id, label: ps[i].name || ps[i].id })
        return m
    }

    // Active pack + its settings schema (adr_027 Layer D). The schema section
    // shows only when the active pack declares one.
    readonly property string _activePack: Persistence.Config.get("appearance.activePack", "")
    readonly property var _packSchema: ShellServices.PackRegistry.configSchemaFor(_activePack)
    readonly property bool _hasPackSettings: _packSchema && Object.keys(_packSchema).length > 0

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

                // ── Theme pack (adr_027 Layer A) ──────────────────────────────
                // At the top — it drives the whole look. Same SegmentedControl
                // language as the Mode/Theme pickers — no native dropdown popup
                // (which mispositions in a layer-shell window).
                SectionLabel { text: "THEME PACK" }
                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    model: root._packModel
                    currentIndex: {
                        var id = Persistence.Config.get("appearance.activePack", "")
                        for (var i = 0; i < root._packModel.length; i++)
                            if (root._packModel[i].id === id) return i
                        return 0
                    }
                    onActivated: index => Persistence.Config.set("appearance.activePack", root._packModel[index].id)
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }

                // ── Pack settings (adr_027 Layer D) ───────────────────────────
                // Directly under the pack selector — the active pack's own knobs.
                // Rendered from its configSchema via the shared ConfigForm; values
                // persist under packs.<id> and override the matching pack token
                // paths live (real settings, not fake toggles).
                SectionLabel { text: "PACK SETTINGS"; visible: root._hasPackSettings }
                SettingsCard {
                    visible: root._hasPackSettings
                    ConfigForm {
                        Layout.fillWidth: true
                        schema: root._packSchema
                        config: Persistence.Config.get("packs." + root._activePack, ({}))
                        onChanged: cfg => Persistence.Config.set("packs." + root._activePack, cfg)
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true; visible: root._hasPackSettings }

                // ── Colour scheme (family → flavor + light/dark + schedule) ───
                // Shared ColorSchemeBody (also powers the bottom Appearance
                // switcher in compact mode). Provides its own section labels.
                // Hidden when the active pack owns its palette (e.g. Grimdark) —
                // the Catppuccin pickers don't apply; the pack's register does.
                Appearance.ColorSchemeBody {
                    Layout.fillWidth: true
                    visible: !Commons.Appearance.packOwnsPalette
                }

                Item { implicitHeight: 10; Layout.fillWidth: true; visible: !Commons.Appearance.packOwnsPalette }

                // ── Style ─────────────────────────────────────────────────────
                // Flat mode is the BASE look's material control — hidden when a
                // pack is active, since the pack owns material (adr_027).
                SectionLabel { text: "STYLE"; visible: root._activePack === "" }
                SettingsCard {
                    visible: root._activePack === ""
                    ToggleRow {
                        label: "Flat mode"
                        description: "Drop the liquid-glass sheen + card shadows for a flatter look — the shell stays translucent, just without the 3D depth"
                        checked: Persistence.Config.get("appearance.flatMode", false)
                        onToggled: v => Persistence.Config.set("appearance.flatMode", v)
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true; visible: root._activePack === "" }

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
            }
        }
    }

}
