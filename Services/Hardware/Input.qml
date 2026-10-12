pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons" as Commons
import "../Persistence" as Persistence
import "../Compositor" as Compositor

// Keyboards, key repeat and touchpad (item_136), MangoWC.
//
// Real devices come from `mmsg get all-devices` (identifier "vendor:product:name",
// types, and `matched` = a devicerule applies to it). Choices persist in the
// shell config (input.*) and are written to ~/.config/mango/archeotech-input.conf,
// which the mango config pulls in with
// `source-optional=~/.config/mango/archeotech-input.conf` (after its own input
// keys, so these win); mango then reloads. NB mango 0.17.5 resolves a bare
// relative name against its working directory, NOT the config dir (only `./` and
// `~` are): `source-optional=archeotech-input.conf` silently loaded nothing.
//
// Per-keyboard layouts use mango `devicerule`s, which give that keyboard its
// OWN keymap once it (re)appears (replug; next login for a built-in keyboard): the external QWERTY always types QWERTY and the built-in AZERTY
// always types AZERTY, both at once, nothing to switch on dock/undock. A rule
// carries ONE layout (mango rejects "us,fr" in a rule: the comma splits it), so
// French accents on a QWERTY come from the "US International" variant
// (AltGr+e = é). Keyboards left on "Default" keep the global xkb layouts and
// their Alt+Shift switch.
QtObject {
    id: root

    readonly property bool supported: !Compositor.CompositorService.isHyprland

    // Layout choices for one keyboard: value → devicerule options ("" = no rule).
    readonly property var layouts: [
        { value: "default", label: "Default",          rule: "" },
        { value: "fr",      label: "AZERTY",           rule: "kb_layout:fr" },
        { value: "us",      label: "QWERTY",           rule: "kb_layout:us" },
        { value: "us-intl", label: "QWERTY intl",      rule: "kb_layout:us,kb_variant:altgr-intl" }
    ]

    // ── Devices ───────────────────────────────────────────────────────────────
    // One entry per PHYSICAL keyboard: identifier = "vendor:product" (a dongle can
    // expose several keyboard interfaces whose names, and their order, vary:
    // "2.4G Dongle" / "2.4G Dongle Keyboard"); nodes = its interfaces with letter
    // keys, each of which gets the same devicerule.
    property var keyboards: []      // [{ identifier: vp, name, nodes, matched, usable }] (shown)
    property int hiddenCount: 0     // real keyboards the user marked "not a keyboard"
    // Identifiers ("vendor:product:name", decimal) of input nodes that have letter
    // keys (KEY_A/KEY_Q/KEY_Z in /proc/bus/input/devices): media-key devices such
    // as Bluetooth headphones (AVRCP) report "keyboard" to mango but have none.
    property var _letterIds: ({})
    property var _procReader: Process {
        command: ["cat", "/proc/bus/input/devices"]
        running: false
        stdout: StdioCollector { onStreamFinished: root._letterIds = root._parseLetters(this.text) }
        onExited: (code, status) => root._reader.running = true
    }
    function _parseLetters(text) {
        var ids = {}
        text.split("\n\n").forEach(b => {
            var n = /N: Name="([^"]*)"/.exec(b), v = /Vendor=([0-9a-f]+)/.exec(b)
            var p = /Product=([0-9a-f]+)/.exec(b), k = /B: KEY=([0-9a-f ]+)/.exec(b)
            if (!n || !v || !p || !k) return
            // Lowest 64-bit word last; KEY_Q=16, KEY_A=30, KEY_Z=44 all live in it.
            var words = k[1].trim().split(/\s+/)
            var low = words[words.length - 1]
            var bit = i => { var h = low.length - 1 - Math.floor(i / 4); return h >= 0 && ((parseInt(low[h], 16) >> (i % 4)) & 1) === 1 }
            if (bit(16) && bit(30) && bit(44))
                ids[parseInt(v[1], 16) + ":" + parseInt(p[1], 16) + ":" + n[1]] = true
        })
        return ids
    }
    property bool hasTouchpad: false
    property var _reader: Process {
        command: ["mmsg", "get", "all-devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    var list = Array.isArray(d) ? d : (d.devices || [])
                    // Real keyboards only: system buttons, hotkey and virtual
                    // devices all report vendor 0.
                    // One row per physical keyboard (a keyboard can expose several
                    // event nodes: keep the first per vendor:product). Names with a
                    // comma cannot go in a devicerule (it splits the rule): listed
                    // but not configurable.
                    var byVp = {}, order = []
                    list.forEach(x => {
                        if ((x.types || []).indexOf("keyboard") < 0 || x.vendor === 0) return
                        if (!root._letterIds[x.identifier]) return       // no letter keys
                        var vp = x.vendor + ":" + x.product
                        if (!byVp[vp]) { byVp[vp] = { identifier: vp, name: x.name, nodes: [], matched: false, usable: true }; order.push(vp) }
                        var k = byVp[vp]
                        k.nodes.push(x.identifier)
                        k.matched = k.matched || !!x.matched
                        k.usable = k.usable && x.identifier.indexOf(",") < 0
                        if (x.name.length < k.name.length) k.name = x.name      // the plain base name
                    })
                    var next = [], hidden = 0
                    order.forEach(vp => {
                        var k = byVp[vp]
                        k.nodes.sort()
                        if (root.isHidden(vp) && !root.showHidden) { hidden++; return }
                        next.push(k)
                    })
                    root._rememberNodes(next)
                    // Same content → keep the array: no delegate rebuild per poll.
                    if (JSON.stringify(next) !== JSON.stringify(root.keyboards)) root.keyboards = next
                    root.hiddenCount = hidden
                    root.hasTouchpad = list.some(x => (x.types || []).indexOf("trackpad") >= 0)
                } catch (e) {}
            }
        }
    }
    function refresh() { if (root.supported && !_procReader.running && !_reader.running) _procReader.running = true }
    Component.onCompleted: refresh()

    // ── Settings (shell config) ───────────────────────────────────────────────
    // Only keys the user has CHANGED are written; untouched ones stay with the
    // mango config's own values (the defaults shown here are mango's/ours until then).
    readonly property var keyboardLayouts: Persistence.Config.get("input.keyboardLayouts", ({}))
    readonly property int  repeatDelay: Persistence.Config.get("input.repeatDelay", 600)
    readonly property int  repeatRate: Persistence.Config.get("input.repeatRate", 25)
    readonly property bool tapToClick: Persistence.Config.get("input.tapToClick", true)
    readonly property bool naturalScroll: Persistence.Config.get("input.naturalScroll", true)
    readonly property bool disableWhileTyping: Persistence.Config.get("input.disableWhileTyping", true)
    readonly property real pointerSpeed: Persistence.Config.get("input.pointerSpeed", 0)
    function _isSet(key) { return Persistence.Config.get("input." + key, null) !== null }
    // Devices the user marked "not a keyboard" (e.g. a mouse receiver that also
    // advertises a keyboard interface): hidden from the list, any rule kept.
    readonly property var hiddenKeyboards: Persistence.Config.get("input.hiddenKeyboards", [])
    function isHidden(vp) { return root.hiddenKeyboards.some(h => h === vp || root._vpOf(h) === vp) }
    property bool showHidden: false
    onShowHiddenChanged: refresh()
    onHiddenKeyboardsChanged: refresh()
    function setHidden(vp, hide) {
        var l = root.hiddenKeyboards.filter(x => x !== vp && root._vpOf(x) !== vp)
        if (hide) l.push(vp)
        Persistence.Config.set("input.hiddenKeyboards", l)
    }
    // After a reload has finished and the devices were re-read. A keyboard whose
    // rule is not yet `matched` is waiting to be reconnected: mango 0.17.5 applies
    // device rules only when a device appears (reload_config re-applies pointer and
    // touchpad settings, not device rules), so the pane says how to apply it.
    property bool settled: true

    // Choices are keyed by "vendor:product". Older configs keyed them by the full
    // "vendor:product:name" of one interface: still read (and replaced on change).
    function _vpOf(key) { return key.split(":").slice(0, 2).join(":") }
    function layoutFor(vp) {
        var m = root.keyboardLayouts
        if (m[vp]) return m[vp]
        var old = Object.keys(m).find(k => k !== vp && root._vpOf(k) === vp)
        return old ? m[old] : "default"
    }
    function setLayout(vp, value) {
        var m = {}
        Object.keys(root.keyboardLayouts).forEach(k => { if (root._vpOf(k) !== vp) m[k] = root.keyboardLayouts[k] })
        if (value !== "default") m[vp] = value
        Persistence.Config.set("input.keyboardLayouts", m)
        _schedule()
    }
    // Interface names per keyboard, remembered so its rules stay in the conf
    // while it is unplugged (the conf is rewritten on any Input change).
    readonly property var keyboardNodes: Persistence.Config.get("input.keyboardNodes", ({}))
    function _rememberNodes(kbs) {
        var m = Object.assign({}, root.keyboardNodes), changed = false
        kbs.forEach(k => {
            var known = m[k.identifier] || []
            var merged = known.concat(k.nodes.filter(n => known.indexOf(n) < 0)).sort()
            if (JSON.stringify(merged) !== JSON.stringify(known)) { m[k.identifier] = merged; changed = true }
        })
        if (changed) { Persistence.Config.set("input.keyboardNodes", m); _schedule() }
    }
    function set(key, value) { Persistence.Config.set("input." + key, value); _schedule() }

    // Boot: make the conf match the saved choices once (e.g. config.json synced
    // to a machine whose conf is missing). Idempotent: nothing to do, no reload.
    property var _readyConn: Connections {
        target: Persistence.Config
        function onReadyChanged() { if (Persistence.Config.ready) root._bootSync() }
    }
    function _bootSync() {
        if (!root.supported) return
        var any = ["keyboardLayouts", "repeatDelay", "repeatRate", "tapToClick", "naturalScroll",
                   "disableWhileTyping", "pointerSpeed"].some(k => root._isSet(k))
        if (any) _schedule()
    }

    // ── Write + reload ────────────────────────────────────────────────────────
    // One shell chain, so mango never reloads before the file is written: exit
    // when the content is unchanged (no needless reload), else write atomically,
    // reload, and cycle the active keyboard layout back (reload_config resets it
    // to the first layout; same recipe as MangoService.applyWindowDecor).
    // Debounced 900 ms: a slider drag reloads once, after it settles.
    readonly property string _confPath: Quickshell.env("HOME") + "/.config/mango/archeotech-input.conf"
    property var _runner: Commons.CommandRunner { label: "input settings"; coalesce: true }
    property var _apply: Timer {
        interval: 900
        onTriggered: root._runner.run(["bash", "-c",
            "F=\"$1\"; NEW=\"$2\"; mkdir -p \"$(dirname \"$F\")\"; "
          + "[ -f \"$F\" ] && [ \"$(cat \"$F\")\" = \"$NEW\" ] && exit 0; "
          + "printf '%s\\n' \"$NEW\" > \"$F.tmp\" && mv \"$F.tmp\" \"$F\" || exit 1; "
          + "PREV_KB=$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' 2>/dev/null); "
          + "mmsg dispatch reload_config; "
          + "if [ -n \"$PREV_KB\" ]; then for _ in $(seq 1 6); do "
          + "[ \"$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' 2>/dev/null)\" = \"$PREV_KB\" ] && break; "
          + "mmsg dispatch switch_keyboard_layout 2>/dev/null; sleep 0.1; done; fi",
            "input", root._confPath, root.render()])
    }
    property var _afterApply: Connections {
        target: root._runner
        function onFinished(argv, code) { root._reread.restart() }
    }
    property var _reread: Timer { interval: 500; onTriggered: { root.refresh(); root.settled = true } }
    function _schedule() { if (root.supported) { root.settled = false; _apply.restart() } }

    function render() {
        var lines = [
            "# Generated by Archeotech Settings → Input. Change it there, not here:",
            "# this file is rewritten on every change. Pulled in by the mango config",
            "# (source-optional=~/.config/mango/archeotech-input.conf) after its input keys.",
            "# Only settings changed in Settings appear; the rest stay as configured."
        ]
        if (root._isSet("repeatDelay")) lines.push("repeat_delay=" + root.repeatDelay)
        if (root._isSet("repeatRate")) lines.push("repeat_rate=" + root.repeatRate)
        if (root._isSet("tapToClick")) lines.push("tap_to_click=" + (root.tapToClick ? 1 : 0))
        if (root._isSet("naturalScroll")) lines.push("trackpad_natural_scrolling=" + (root.naturalScroll ? 1 : 0))
        if (root._isSet("disableWhileTyping")) lines.push("trackpad_disable_while_typing=" + (root.disableWhileTyping ? 1 : 0))
        if (root._isSet("pointerSpeed")) lines.push("trackpad_accel_speed=" + Number(root.pointerSpeed).toFixed(2))
        // One devicerule per interface of each configured keyboard (interfaces
        // remembered in keyboardNodes; a legacy full-identifier key is its own node).
        var done = {}
        Object.keys(root.keyboardLayouts).sort().forEach(key => {
            var vp = root._vpOf(key)
            if (done[vp]) return
            done[vp] = true
            var l = root.layouts.find(x => x.value === root.layoutFor(vp))
            if (!l || !l.rule) return
            var nodes = (root.keyboardNodes[vp] || []).slice()
            Object.keys(root.keyboardLayouts).forEach(k => { if (k !== vp && root._vpOf(k) === vp && nodes.indexOf(k) < 0) nodes.push(k) })
            nodes.sort().forEach(n => {
                // A comma would split the rule (mango separates rule fields by commas).
                if (n.indexOf(",") >= 0) return
                // A rule's keyboard gets its own keymap AND its own repeat settings.
                lines.push("devicerule=name:" + n + "," + l.rule +
                           ",repeat_delay:" + root.repeatDelay + ",repeat_rate:" + root.repeatRate)
            })
        })
        return lines.join("\n")
    }
}
