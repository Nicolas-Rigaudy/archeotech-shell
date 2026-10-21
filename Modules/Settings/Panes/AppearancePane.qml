import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence
import "../../../Services/Shell" as ShellServices
import "../../../Services/Theming" as Theming
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

        Divider { }   // frame separator under the pane header

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
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Commons.Appearance.spacing.s6; leftMargin: Commons.Appearance.spacing.s6; rightMargin: Commons.Appearance.spacing.s6 }
                width: root.width - 48
                spacing: Commons.Appearance.spacing.s3

                // ── Theme pack (adr_027 Layer A) ──────────────────────────────
                // At the top — it drives the whole look. Same SegmentedControl
                // language as the Mode/Theme pickers — no native dropdown popup
                // (which mispositions in a layer-shell window).
                SectionLabel { text: "THEME PACK"; SearchTarget { key: "appearance.pack"; target: packPicker } }
                SegmentedControl {
                    id: packPicker
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

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }

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

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true; visible: root._hasPackSettings }

                // ── Colour scheme (family → flavor + light/dark + schedule) ───
                // Shared ColorSchemeBody (also powers the bottom Appearance
                // switcher in compact mode). Provides its own section labels.
                // Hidden when the active pack owns its palette (e.g. Grimdark) —
                // the Catppuccin pickers don't apply; the pack's register does.
                Appearance.ColorSchemeBody {
                    id: schemeBody
                    Layout.fillWidth: true
                    SearchTarget { key: "appearance.theme"; target: schemeBody }
                    visible: !Commons.Appearance.packOwnsPalette
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true; visible: !Commons.Appearance.packOwnsPalette }

                // ── Style ─────────────────────────────────────────────────────
                // Flat mode + glass opacity are the BASE look's material controls —
                // hidden when a pack is active, since the pack owns material (adr_027).
                SectionLabel { text: "STYLE"; visible: root._activePack === "" }
                SettingsCard {
                    visible: root._activePack === ""
                    // Glass opacity (item_139): panels, cards and kitty. Options come
                    // from themes/glass-presets.json (the same table Appearance reads).
                    ButtonGroupRow {
                        label: "Opacity"
                        configKey: "appearance.glass"
                        // "" and an explicit "glass" are both the default preset:
                        // compare what is applied, not the stored string.
                        modified: Commons.Appearance.effectiveGlassPreset !== Commons.Appearance.glassDefault
                        resetHint: "Reset to " + _optionLabel(Commons.Appearance.glassDefault, "default")
                        description: "How much wallpaper shows through panels, cards and kitty"
                        options: Commons.Appearance.glassPresets
                        currentValue: Commons.Appearance.effectiveGlassPreset
                        onSelected: v => Persistence.Config.set("appearance.glass", v)
                    }
                    // Layer blur source (item_116): only while the preset blurs.
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: Commons.Appearance.layerBlur }
                    Divider { visible: Commons.Appearance.layerBlur }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: Commons.Appearance.layerBlur }
                    ButtonGroupRow {
                        visible: Commons.Appearance.layerBlur
                        label: "Behind windows"
                        configKey: "appearance.glassBlur"
                        description: "What frosted panels show over a window"
                        options: [
                            { value: "xray",    label: "X-ray" },
                            { value: "windows", label: "Blur" }
                        ]
                        currentValue: Commons.Appearance.effectiveGlassBlur
                        onSelected: v => Persistence.Config.set("appearance.glassBlur", v)
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Divider { }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    // Text size (item_110 wave 2): multiplies every step of the type scale.
                    ButtonGroupRow {
                        label: "Text size"
                        configKey: "appearance.fontScale"
                        description: "Scales all text and icons in the shell"
                        options: [
                            { value: "0.9", label: "Small" },
                            { value: "1",   label: "Default" },
                            { value: "1.1", label: "Large" },
                            { value: "1.2", label: "Larger" }
                        ]
                        currentValue: String(Commons.Appearance.fontScale)
                        onSelected: v => Persistence.Config.set("appearance.fontScale", Number(v))
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Divider { }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    // Depth: the same pick-one-of-N selector as Opacity / Text size
                    // (was a Flat mode toggle); still the appearance.flatMode bool.
                    ButtonGroupRow {
                        label: "Depth"
                        configKey: "appearance.flatMode"
                        resetHint: "Reset to 3D"
                        description: "Flat drops the glass sheen and card shadows"
                        options: [
                            { value: "3d",   label: "3D" },
                            { value: "flat", label: "Flat" }
                        ]
                        currentValue: Persistence.Config.get("appearance.flatMode") ? "flat" : "3d"
                        onSelected: v => Persistence.Config.set("appearance.flatMode", v === "flat")
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Divider { }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    // Motion (item_114): one speed multiplier, one accessibility switch.
                    ButtonGroupRow {
                        label: "Animation speed"
                        configKey: "appearance.animScale"
                        description: "How long panels, fades and slides take; Off makes everything instant"
                        options: [
                            { value: "0",   label: "Off" },
                            { value: "0.5", label: "Quick" },
                            { value: "1",   label: "Normal" },
                            { value: "1.5", label: "Slow" }
                        ]
                        currentValue: String(Commons.Appearance.animScale)
                        onSelected: v => Persistence.Config.set("appearance.animScale", Number(v))
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Divider { }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    ButtonGroupRow {
                        label: "Reduce motion"
                        configKey: "appearance.reducedMotion"
                        resetHint: "Reset to Off"
                        description: "Slides and pops become instant and scrolling text stops; fades stay"
                        options: [{ value: "off", label: "Off" }, { value: "on", label: "On" }]
                        currentValue: Persistence.Config.get("appearance.reducedMotion") ? "on" : "off"
                        onSelected: v => Persistence.Config.set("appearance.reducedMotion", v === "on")
                    }
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true; visible: root._activePack === "" }

                // ── Wallpaper ─────────────────────────────────────────────────
                // Shares the exact WallpaperPickerBody the quick-switcher tab
                // uses (Sprint 24/26). Settings stacks; the quick panel tabs.
                SectionLabel { text: "WALLPAPER"; SearchTarget { key: "appearance.wallpaper"; target: wallBody } }

                // Per-mode wallpapers (item_140): each mode remembers its own; the
                // selected card is the one the carousel below sets.
                SettingsCard {
                    id: wallModes
                    SearchTarget { key: "wallpaper.modes"; target: wallModes }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Each mode keeps its own wallpaper and switches with the theme. Pick a card, then a wallpaper."
                        color: Commons.Appearance.colors.textMuted
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Appearance.WallpaperSlots {
                        id: wallSlots
                        Layout.fillWidth: true
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                }

                Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }

                Appearance.WallpaperPickerBody {
                    id: wallBody
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    embedded: true
                    carouselHeight: 200
                    slot: wallSlots.selected
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }

                // ── Logo ──────────────────────────────────────────────────────
                SectionLabel { text: "LOGO"; SearchTarget { key: "appearance.logo"; target: logoBody } }

                Appearance.LogoCarousel {
                    id: logoBody
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                }

            }
        }
    }

}
