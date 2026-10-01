import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../Widgets"
import "../../../Services/Hardware" as Hardware
import "../../../Services/Hardware/DisplaysLogic.js" as Logic

Item {
    id: root

    // ── State ──────────────────────────────────────────────────────────────────
    property string nightLightMode: "off"

    Component.onCompleted: { nightLightReader.running = true; Hardware.Displays.refresh(); root._sync() }

    // ── Process helpers ────────────────────────────────────────────────────────
    Commons.CommandRunner { id: cmdRunner }
    function run(cmd) { cmdRunner.runShell(cmd) }

    Process {
        id: nightLightReader
        // Real state = the running wlsunset's own -t argument (pgrep -a prints the
        // arguments space-separated; /proc/<pid>/cmdline is NUL-separated, which
        // the old pid-file reader grepped for "-t " and so always read "off").
        command: ["bash", "-c",
            "pgrep -ax wlsunset | grep -oP '(?<=-t )\\d+' | head -1 | grep . || echo off"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var t = data.trim()
                root.nightLightMode = (t === "4500" || t === "3500" || t === "2700") ? t : "off"
            }
        }
    }

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

    // wlsunset is a day/night SCHEDULE (-T day, -t night): `-T 6500 -t 4500`
    // changed nothing during the day. Pinning both ends (-T = -t + 1, it needs
    // T > t) applies the temperature now, all day. setsid -f detaches it from
    // the short-lived runner shell so it keeps running. Read back afterwards.
    function _applyNightLight(mode) {
        root.nightLightMode = mode
        if (mode === "off")
            run("pkill -x wlsunset 2>/dev/null; true")
        else
            run("pkill -x wlsunset 2>/dev/null; sleep 0.2; setsid -f wlsunset -t " + mode + " -T " + (Number(mode) + 1) + " >/dev/null 2>&1")
        _nightPending = true
    }
    // Read back once the command has actually run (the runner queues), plus a
    // beat for the new wlsunset to start.
    property bool _nightPending: false
    Connections {
        target: cmdRunner
        function onFinished(argv, code) { if (root._nightPending) { root._nightPending = false; _nightReadback.restart() } }
    }
    Timer { id: _nightReadback; interval: 400; onTriggered: nightLightReader.running = true }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󱄅"
            title: "Display"
            description: "Arrange your screens, their resolution, rotation and scale, and color temperature"
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

                SectionLabel { text: "MONITOR LAYOUT" }

                SettingsCard {
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

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
                SectionLabel { text: "NIGHT LIGHT" }

                SettingsCard {
                    ButtonGroupRow {
                        label: "Color temperature"
                        description: "Reduce blue light during evening hours"
                        options: [
                            { value: "off",  label: "Off"   },
                            { value: "4500", label: "4500K" },
                            { value: "3500", label: "3500K" },
                            { value: "2700", label: "2700K" }
                        ]
                        currentValue: root.nightLightMode
                        onSelected: v => root._applyNightLight(v)
                    }
                }
            }
        }
    }
}
