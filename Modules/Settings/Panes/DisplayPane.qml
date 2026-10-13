import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../Widgets"
import "../../../Services/Hardware" as Hardware
import "../../../Services/Persistence" as Persistence
import "../../../Services/Hardware/DisplaysLogic.js" as Logic

Item {
    id: root

    // ── State ──────────────────────────────────────────────────────────────────

    Component.onCompleted: { Hardware.Displays.refresh(); Hardware.Displays.refreshProfiles(); root._sync() }

    // ── Monitor layout editor (item_135 wave 1) ─────────────────────────────────
    // `staged` is a deep copy of the real outputs (Hardware.Displays) that the
    // editor mutates; it re-syncs from the real state whenever nothing is
    // pending, so a hotplug shows up immediately. Apply sends the whole staged
    // layout in one wlr-randr call and arms a 15 s auto-revert.
    property var    staged: []
    property string selected: ""
    // _edited = the user changed something since the last sync (a hotplug or
    // re-read must not throw that away); dirty = those edits differ from reality.
    property bool   _edited: false
    readonly property bool dirty: _edited && JSON.stringify(staged) !== JSON.stringify(Hardware.Displays.outputs)
    function _sync() {
        root._edited = false
        root.staged = JSON.parse(JSON.stringify(Hardware.Displays.outputs))
        if (!root.staged.some(o => o.name === root.selected))
            root.selected = root.staged.length ? root.staged[0].name : ""
    }
    Connections {
        target: Hardware.Displays
        // A hotplug while editing changes the output set: start again from the
        // real state rather than apply a layout for screens that are gone.
        function onOutputsChanged() {
            var names = l => l.map(o => o.name).sort().join(",")
            if (!root._edited || Hardware.Displays.pendingConfirm
                    || names(root.staged) !== names(Hardware.Displays.outputs)) root._sync()
        }
    }
    // Rotation/position changes made elsewhere are not hotplugs (no screens
    // signal), so re-read while the pane is on screen; edits are never clobbered.
    Timer {
        interval: 2000; repeat: true
        running: root.visible
        onTriggered: Hardware.Displays.refresh()
    }
    readonly property var _sel: staged.find(o => o.name === selected) || null
    readonly property bool _overlap: Logic.hasOverlap(staged)
    readonly property bool _anyOn: staged.some(o => o.enabled)
    readonly property bool _selOn: !!(_sel && _sel.enabled)
    // Edit that may grow the output: re-park it if it now overlaps.
    function _editSize(fn) {
        root._edit(root.selected, o => {
            fn(o)
            var others = root.staged.filter(x => x.name !== o.name)
            if (Logic.hasOverlap(others.concat([o]))) root._parkRight(o)
        })
    }

    // Edit one staged output, then keep the layout normalised at 0,0.
    function _edit(name, fn) {
        var next = JSON.parse(JSON.stringify(root.staged))
        var o = next.find(x => x.name === name)
        if (!o) return
        fn(o)
        root._edited = true
        root.staged = Logic.normalize(next)
    }
    // A newly enabled output, or one that grew (rotation / resolution / scale)
    // into a neighbour, is parked at the right edge; the user drags it from there.
    function _parkRight(o) {
        var right = 0
        root.staged.forEach(x => {
            if (x.enabled && x.name !== o.name) right = Math.max(right, x.x + Hardware.Displays.logicalSize(x).w)
        })
        o.x = right; o.y = 0
    }

    function _modeKey(m) { return m.width + "x" + m.height }
    readonly property var _resOptions: {
        if (!_sel) return []
        var seen = {}, out = []
        _sel.modes.forEach(m => {
            var k = _modeKey(m)
            if (seen[k]) return
            seen[k] = true
            out.push({ value: k, label: m.width + " × " + m.height + (m.preferred ? "  (native)" : "") })
        })
        return out
    }
    readonly property var _rateOptions: {
        if (!_sel) return []
        return _sel.modes.filter(m => m.width === _sel.width && m.height === _sel.height)
                          .map(m => ({ value: String(m.refresh), label: m.refresh.toFixed(2) + " Hz" }))
    }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󱄅"
            title: "Display"
            description: "Arrange your screens, their resolution, rotation and scale, and night light"
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
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Commons.Appearance.spacing.s6; leftMargin: Commons.Appearance.spacing.s6; rightMargin: Commons.Appearance.spacing.s6 }
                width: root.width - 48
                spacing: Commons.Appearance.spacing.s2

                SectionLabel { text: "MONITOR LAYOUT"; SearchTarget { key: "display.layout"; target: layoutCard } }

                SettingsCard {
                    id: layoutCard
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    DisplayArrangement {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        outputs: root.staged
                        selected: root.selected
                        onSelect: name => root.selected = name
                        onMoved: (name, x, y) => root._edit(name, o => { o.x = x; o.y = y })
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Text {
                        Layout.fillWidth: true
                        text: "Drag a screen to arrange it; it snaps flush to its neighbours. Click one to edit it below."
                        color: Commons.Appearance.colors.textMuted
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        wrapMode: Text.WordWrap
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    // Every connected output, including disabled ones (they are not on the canvas).
                    ButtonGroupRow {
                        visible: root.staged.length > 1
                        label: "Screen"
                        options: root.staged.map(o => ({ value: o.name, label: o.name + (o.enabled ? "" : " (off)") }))
                        currentValue: root.selected
                        onSelected: v => root.selected = v
                    }
                }

                SettingsCard {
                    visible: root._sel !== null
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Text {
                        Layout.fillWidth: true
                        text: root._sel ? (root._sel.make + " " + root._sel.model).trim() || root._sel.name : ""
                        color: Commons.Appearance.colors.textPrimary
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeMd
                        font.weight: Commons.Appearance.font.weightMedium
                        elide: Text.ElideRight
                    }
                    ToggleRow {
                        label: "Enabled"
                        description: root._sel && root._sel.modes.length === 0 && !root._sel.enabled
                                     ? "This screen reports no modes and cannot be turned on"
                                     : "Turn this screen on or off (at least one has to stay on)"
                        checked: root._sel ? root._sel.enabled : false
                        enabled: !(root._sel && root._sel.modes.length === 0 && !root._sel.enabled)
                        onToggled: v => root._edit(root.selected, o => { o.enabled = v; if (v) root._parkRight(o) })
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: root._selOn }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0; visible: root._selOn }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: root._selOn }
                    DropdownRow {
                        visible: root._selOn
                        label: "Resolution"
                        options: root._resOptions
                        currentValue: root._sel ? root._modeKey(root._sel) : ""
                        onSelected: v => root._editSize(o => {
                            var best = o.modes.filter(m => root._modeKey(m) === v).sort((a, b) => b.refresh - a.refresh)[0]
                            if (!best) return
                            o.width = best.width; o.height = best.height; o.refresh = best.refresh
                        })
                    }
                    DropdownRow {
                        visible: root._selOn && root._rateOptions.length > 1
                        label: "Refresh rate"
                        options: root._rateOptions
                        currentValue: root._sel ? String(root._sel.refresh) : ""
                        onSelected: v => root._edit(root.selected, o => o.refresh = Number(v))
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: root._selOn }
                    ButtonGroupRow {
                        visible: root._selOn
                        label: "Rotation"
                        options: [
                            { value: "normal", label: "0°" },
                            { value: "90",     label: "90°" },
                            { value: "180",    label: "180°" },
                            { value: "270",    label: "270°" }
                        ]
                        currentValue: root._sel ? root._sel.transform : "normal"
                        onSelected: v => root._editSize(o => o.transform = v)
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: root._selOn }
                    ButtonGroupRow {
                        visible: root._selOn
                        label: "Scale"
                        options: [
                            { value: "1",    label: "100%" },
                            { value: "1.25", label: "125%" },
                            { value: "1.5",  label: "150%" },
                            { value: "2",    label: "200%" }
                        ]
                        currentValue: root._sel ? String(root._sel.scale) : "1"
                        onSelected: v => root._editSize(o => o.scale = Number(v))
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                }

                // Apply / discard, then the keep-or-revert confirmation.
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.dirty || Hardware.Displays.pendingConfirm || Hardware.Displays.lastError !== ""
                    spacing: Commons.Appearance.spacing.s2
                    Text {
                        Layout.fillWidth: true
                        text: Hardware.Displays.pendingConfirm
                              ? "Confirm on screen: reverting in " + Hardware.Displays.confirmLeft + " s"
                              : Hardware.Displays.lastError !== "" && !root.dirty ? Hardware.Displays.lastError
                              : !root._anyOn ? "Turn at least one screen on to apply"
                              : root._overlap ? "Screens overlap: drag them apart to apply" : "Unsaved changes"
                        color: Hardware.Displays.pendingConfirm ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textMuted
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeBase
                    }
                    GlassButton {
                        visible: !Hardware.Displays.pendingConfirm && root.dirty
                        text: "Discard"
                        onClicked: root._sync()
                    }
                    GlassButton {
                        visible: !Hardware.Displays.pendingConfirm && root.dirty
                        text: "Apply"
                        active: !root._overlap && root._anyOn
                        enabled: !root._overlap && root._anyOn
                        onClicked: {
                            var confirm = Logic.risky(Hardware.Displays.outputs, root.staged)
                            if (Hardware.Displays.apply(root.staged, confirm)) root._edited = false
                        }
                    }
                    GlassButton {
                        visible: Hardware.Displays.pendingConfirm
                        text: "Revert"
                        onClicked: Hardware.Displays.revert()
                    }
                    GlassButton {
                        visible: Hardware.Displays.pendingConfirm
                        text: "Keep"
                        active: true
                        onClicked: Hardware.Displays.keep()
                    }
                }

                // ── Profiles (item_135 wave 2) ────────────────────────────────
                // A saved layout per set of monitors; the matching one applies
                // by itself on dock/undock (scripts/display-profile.py).
                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
                SectionLabel { text: "PROFILES"; SearchTarget { key: "display.profiles"; target: profilesCard } }
                SettingsCard {
                    id: profilesCard
                    ToggleRow {
                        label: "Apply profiles automatically"
                        searchKey: "display.autoApply"
                        description: "When screens are plugged in or unplugged, use the saved layout for those screens"
                        checked: Hardware.Displays.autoApply
                        onToggled: v => Hardware.Displays.setAutoApply(v)
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }

                    // Saved profiles; the one for the connected screens is marked.
                    Repeater {
                        model: Hardware.Displays.profiles
                        delegate: RowLayout {
                            id: profRow
                            required property var modelData
                            readonly property bool _cur: modelData.name === Hardware.Displays.activeProfile
                            Layout.fillWidth: true
                            Layout.preferredHeight: Commons.Appearance.spacing.s10
                            spacing: Commons.Appearance.spacing.s3
                            Text {
                                text: profRow._cur ? "󰄬" : "󰍹"
                                color: profRow._cur ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textMuted
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeLg
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: profRow.modelData.name + (profRow._cur ? "  ·  current" : "")
                                    color: profRow._cur ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textPrimary
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeBase
                                    font.weight: profRow._cur ? Commons.Appearance.font.weightMedium : Commons.Appearance.font.weightRegular
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (profRow.modelData.monitors || []).join("  ·  ")
                                    color: Commons.Appearance.colors.textMuted
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    elide: Text.ElideRight
                                }
                            }
                            GlassButton {
                                text: "Delete"
                                onClicked: Hardware.Displays.deleteProfile(profRow.modelData.name)
                            }
                        }
                    }
                    Text {
                        visible: Hardware.Displays.profiles.length === 0 || Hardware.Displays.profileError !== ""
                        Layout.fillWidth: true
                        text: Hardware.Displays.profileError !== "" ? Hardware.Displays.profileError
                              : "No profiles yet. Arrange your screens above, then save the layout here."
                        color: Commons.Appearance.colors.textMuted
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        wrapMode: Text.WordWrap
                    }

                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }

                    // Save the CURRENT (applied) layout. Saving for the same
                    // screens replaces that profile, so prefill its name.
                    TextFieldRow {
                        id: profName
                        label: Hardware.Displays.activeProfile !== "" ? "Update this layout" : "Save this layout as"
                        description: root.dirty || Hardware.Displays.pendingConfirm
                                     ? "Apply or discard your changes first"
                                     : "One profile per set of screens, e.g. Work, Home, Laptop"
                        placeholder: "Work"
                        text: Hardware.Displays.activeProfile
                        // Save always uses profName.value: exactly what the field shows.
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        GlassButton {
                            readonly property bool _ok: profName.value.trim() !== "" && !root.dirty && !Hardware.Displays.pendingConfirm
                            // Saving for screens that already have a profile replaces it.
                            text: Hardware.Displays.activeProfile === "" ? "Save profile"
                                  : profName.value.trim() === Hardware.Displays.activeProfile ? "Update profile"
                                  : "Replace " + Hardware.Displays.activeProfile
                            active: _ok
                            enabled: _ok
                            onClicked: Hardware.Displays.saveProfile(profName.value)
                        }
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
                SectionLabel { text: "NIGHT LIGHT" }

                // Live, flash-free colour temperature (Hardware.NightLight:
                // wl-gammarelay-rs on mango, hyprsunset on Hyprland).
                SettingsCard {
                    ToggleRow {
                        label: "Night light"
                        searchKey: "nightLight.enabled"
                        description: Hardware.NightLight.available
                            ? "Warm the screen colour to reduce blue light"
                            : "Needs " + Hardware.NightLight.backend + " (install it to use night light)"
                        enabled: Hardware.NightLight.available
                        checked: Hardware.NightLight.enabled
                        onToggled: v => Hardware.NightLight.setEnabled(v)
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: Hardware.NightLight.enabled }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0; visible: Hardware.NightLight.enabled }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: Hardware.NightLight.enabled }
                    SliderRow {
                        visible: Hardware.NightLight.enabled
                        label: "Temperature"
                        configKey: "nightLight.temperature"
                        autoReset: false   // applied live through the service
                        onReset: Hardware.NightLight.setTemperature(Persistence.Config.defaultFor("nightLight.temperature"))
                        description: "Lower is warmer; applies as you drag"
                        from: Hardware.NightLight.minTemp
                        to: Hardware.NightLight.maxTemp - 500
                        stepSize: 100
                        value: Hardware.NightLight.temperature
                        format: v => Math.round(v) + " K"
                        onMoved: v => Hardware.NightLight.setTemperature(v)
                    }
                }
            }
        }
    }
}
