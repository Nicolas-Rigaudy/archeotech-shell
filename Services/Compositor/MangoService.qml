pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Commons" as Commons

// MangoWC backend for CompositorService — mangowm 0.15+ `mmsg` JSON IPC
// (get/watch/dispatch). The pre-0.15 flag interface was removed upstream; this
// consumes the JSON streams instead. This is the ONLY file that shells out to
// `mmsg`; every widget reaches it through the CompositorService facade so the
// same call sites also work under HyprlandService (item_070).
//
// Two watch streams feed the per-output registry:
//   mmsg watch all-monitors    → {monitors:[{name,active,layout_symbol,
//                                  tags:[{index,is_active,is_urgent,client_count}]}]}
//   mmsg watch focusing-client → {id,title,appid,monitor,is_floating,is_fullscreen,…}

QtObject {
    id: root

    // Only the compositor actually running should do work. Under Hyprland this
    // backend stays inert (no mmsg spawned) — CompositorService routes to
    // HyprlandService instead. Detected via Hyprland's instance-signature env.
    readonly property bool _active: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") === ""

    // ── Output registry ────────────────────────────────────────────────────────
    property var _outputs: ({})
    property string focusedOutput: ""

    property Component _outputComponent: Component {
        QtObject {
            property string name:       ""
            property var    tags:       []   // [{num, selected, occupied, urgent}]
            property string title:      ""
            property string appid:      ""
            property string layout:     ""
            property bool   focused:    false
            property bool   floating:   false
            property bool   fullscreen: false
            // Monitor position/size in the global layout (for coord mapping).
            property int    x:          0
            property int    y:          0
            property int    mw:         0
            property int    mh:         0
        }
    }

    // ── Client (window) geometry ─────────────────────────────────────────────────
    // Live list of all windows with GLOBAL geometry, from `watch all-clients`.
    // Used by the per-window bracket overlay (adr_027 window chrome).
    property var clients: []

    // Visible windows on a monitor, converted to that monitor's LOCAL coords
    // (subtracting its layout offset) so a per-monitor overlay can place chrome
    // directly. Reads `clients` + the monitor's geometry, so bindings on it
    // re-evaluate when either changes.
    function clientsFor(monitorName) {
        var mo = _outputs[monitorName]
        if (!mo) return []
        var out = []
        for (var i = 0; i < clients.length; i++) {
            var c = clients[i]
            if (c.monitor !== monitorName || !c.visible) continue
            out.push({ x: c.x - mo.x, y: c.y - mo.y, width: c.width, height: c.height,
                       focused: c.focused, id: c.id })
        }
        return out
    }

    function _ensureOutput(name) {
        if (!_outputs[name]) {
            var obj = _outputComponent.createObject(root, { name: name })
            _outputs[name] = obj
            _outputs = Object.assign({}, _outputs) // notify registry change
        }
        return _outputs[name]
    }

    // ── Public accessors (unchanged API) ─────────────────────────────────────────
    function outputFor(name)    { return _outputs[name] || null }
    function tagsFor(name)      { var o = _outputs[name]; return o ? o.tags : [] }
    function titleFor(name)     { var o = _outputs[name]; return o ? o.title : "" }
    function layoutFor(name)    { var o = _outputs[name]; return o ? o.layout : "" }
    function isFloating(name)   { var o = _outputs[name]; return o ? o.floating : false }
    function isFullscreen(name) { var o = _outputs[name]; return o ? o.fullscreen : false }

    // ── Watch streams ────────────────────────────────────────────────────────────
    // Only start the mmsg watchers when MangoWC is the active compositor.
    Component.onCompleted: if (_active) { _watchMonitors.running = true; _watchClient.running = true; _watchClients.running = true }

    property var _watchMonitors: Process {
        property double _startedAt: 0
        command: ["mmsg", "watch", "all-monitors"]
        running: false
        onStarted: _startedAt = Date.now()
        stdout: SplitParser { onRead: line => root._parseMonitors(line) }
        onExited: (code, status) => root._scheduleRestart(root._monRestart, _startedAt)
    }
    property var _monRestart: Timer {
        interval: 250; repeat: false
        onTriggered: { root._watchMonitors._startedAt = 0; root._watchMonitors.running = true }
    }

    property var _watchClient: Process {
        property double _startedAt: 0
        command: ["mmsg", "watch", "focusing-client"]
        running: false
        onStarted: _startedAt = Date.now()
        stdout: SplitParser { onRead: line => root._parseClient(line) }
        onExited: (code, status) => root._scheduleRestart(root._cliRestart, _startedAt)
    }
    property var _cliRestart: Timer {
        interval: 250; repeat: false
        onTriggered: { root._watchClient._startedAt = 0; root._watchClient.running = true }
    }

    property var _watchClients: Process {
        property double _startedAt: 0
        command: ["mmsg", "watch", "all-clients"]
        running: false
        onStarted: _startedAt = Date.now()
        stdout: SplitParser { onRead: line => root._parseClients(line) }
        onExited: (code, status) => root._scheduleRestart(root._clisRestart, _startedAt)
    }
    property var _clisRestart: Timer {
        interval: 250; repeat: false
        onTriggered: { root._watchClients._startedAt = 0; root._watchClients.running = true }
    }

    // Exponential backoff 500ms → cap 8s. When mmsg can't reach Mango each watch
    // exits at once; resetting the interval on every trigger kept retries at ~1s
    // forever. A stream that stayed up 10s+ was healthy, so it restarts from 500ms.
    // Each trigger zeroes _startedAt, so a stale start time never counts as uptime.
    function _scheduleRestart(timer, startedAt) {
        timer.interval = (startedAt > 0 && Date.now() - startedAt >= 10000) ? 500 : Math.min(timer.interval * 2, 8000)
        timer.start()
    }

    // ── JSON parsers (one full-state object per stream event) ─────────────────────
    function _parseMonitors(line) {
        line = (line || "").trim()
        if (!line || line[0] !== "{") return
        var data
        try { data = JSON.parse(line) } catch (e) { return }
        if (!data || !data.monitors) return
        var activeMon = ""
        for (var i = 0; i < data.monitors.length; i++) {
            var m = data.monitors[i]
            if (m.active) activeMon = m.name
            var entry = _ensureOutput(m.name)
            entry.layout = m.layout_symbol || ""
            if (m.x !== undefined) entry.x = m.x
            if (m.y !== undefined) entry.y = m.y
            if (m.width !== undefined)  entry.mw = m.width
            if (m.height !== undefined) entry.mh = m.height
            var tags = []
            var src = m.tags || []
            for (var j = 0; j < src.length; j++) {
                var t = src[j]
                tags.push({
                    num:      t.index,
                    selected: !!t.is_active,
                    occupied: (t.client_count || 0) > 0,
                    urgent:   !!t.is_urgent
                })
            }
            entry.tags = tags
        }
        // focusedOutput follows the ACTIVE (focused) output reported by
        // all-monitors — which flags the focused monitor even when it has NO
        // client. focusing-client can't do this: focusing an empty output emits no
        // client event, so focusedOutput would stay on the last output that had a
        // focused window (that's why opening a panel while an empty portrait screen
        // was focused landed on the previous monitor).
        if (activeMon !== "") root.focusedOutput = activeMon
    }

    function _parseClient(line) {
        line = (line || "").trim()
        if (!line || line[0] !== "{") return
        var data
        try { data = JSON.parse(line) } catch (e) { return }
        if (!data) return
        var mon = data.monitor || ""
        // No focused client (empty desktop) → clear the last focused output's title.
        if (data.id === undefined || mon === "") {
            var prev = _outputs[root.focusedOutput]
            if (prev) { prev.title = ""; prev.appid = "" }
            return
        }
        root.focusedOutput = mon
        var entry = _ensureOutput(mon)
        entry.title      = data.title || ""
        entry.appid      = data.appid || ""
        entry.floating   = !!data.is_floating
        entry.fullscreen = !!data.is_fullscreen
        for (var k in _outputs) _outputs[k].focused = (k === mon)
    }

    function _parseClients(line) {
        line = (line || "").trim()
        if (!line || line[0] !== "{") return
        var data
        try { data = JSON.parse(line) } catch (e) { return }
        if (!data || !data.clients) return
        var out = []
        for (var i = 0; i < data.clients.length; i++) {
            var c = data.clients[i]
            out.push({ id: c.id, monitor: c.monitor || "",
                       x: c.x, y: c.y, width: c.width, height: c.height,
                       visible: !!c.is_visible, focused: !!c.is_focused,
                       floating: !!c.is_floating, fullscreen: !!c.is_fullscreen })
        }
        root.clients = out
    }

    // ── Actions ────────────────────────────────────────────────────────────────
    // `view`/`toggleview` act on the focused monitor — mango's dispatch can only
    // target a client, not a monitor, so outputName is advisory (matches the
    // native Super+N bind). Clicking a tag on a non-focused monitor's bar acts on
    // the focused monitor; acceptable for now (see Sprint 29 CompositorService).
    function switchTag(outputName, tagNum) { dispatch("view " + tagNum) }
    function toggleTag(outputName, tagNum) { dispatch("toggleview " + tagNum) }

    // "func arg1 arg2" → `mmsg dispatch func,arg1,arg2` (mango joins args with commas).
    function dispatch(command) {
        var parts = command.split(" ")
        var fn    = parts[0]
        var args  = parts.slice(1).join(",")
        _cmd(args.length > 0 ? ["mmsg", "dispatch", fn + "," + args]
                             : ["mmsg", "dispatch", fn])
    }

    function toggleFloating()   { dispatch("togglefloating") }
    function toggleFullscreen() { dispatch("fullscreen 0") }
    function closeWindow()      { dispatch("killclient") }

    // Live-set the focused scroller window's width fraction (0..1).
    function setProportion(p) { dispatch("set_proportion " + Number(p).toFixed(2)) }

    // Persist the scroller default into mango's config.conf so future sessions
    // inherit it (mango re-reads this global only on reload/login). The sed is
    // surgical (anchored single key line); --follow-symlinks edits the repo file
    // the dotfiles symlink points at, keeping the symlink intact.
    function setDefaultProportion(p) {
        var v = Number(p).toFixed(2)
        _cmd(["bash", "-c",
              "sed --follow-symlinks -i "
              + "'s|^scroller_default_proportion=.*|scroller_default_proportion=" + v + "|' "
              + "\"$HOME/.config/mango/config.conf\""])
    }

    // Apply a theme pack's window decoration to the compositor (adr_027 — the
    // theme touching real windows). border_radius + borderpx are mango globals,
    // live only after `reload_config`. This is IDEMPOTENT: it reads the current
    // config values first and only seds + reloads when something actually differs
    // — so shell startup with a matching config does nothing (no needless reload,
    // no keyboard-layout cycle). reload_config resets the keyboard layout, so the
    // active one is saved and cycled back (matches mango-reload.sh). Surgical
    // anchored seds via --follow-symlinks edit the repo file behind the dotfiles
    // symlink, keeping the symlink intact.
    function applyWindowDecor(radius, borderpx) {
        var r  = Math.round(radius)
        var bp = Math.round(borderpx)
        _cmd(["bash", "-c",
              "CFG=\"$HOME/.config/mango/config.conf\"; [ -f \"$CFG\" ] || exit 0; CH=0; "
            + "if [ \"$(grep -oP '^border_radius=\\K[0-9]+' \"$CFG\")\" != \"" + r + "\" ]; then "
            + "sed --follow-symlinks -i 's|^border_radius=.*|border_radius=" + r + "|' \"$CFG\"; CH=1; fi; "
            + "if [ \"$(grep -oP '^borderpx=\\K[0-9]+' \"$CFG\")\" != \"" + bp + "\" ]; then "
            + "sed --follow-symlinks -i 's|^borderpx=.*|borderpx=" + bp + "|' \"$CFG\"; CH=1; fi; "
            + "if [ \"$CH\" = \"1\" ]; then "
            + "PREV_KB=$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' 2>/dev/null); "
            + "mmsg dispatch reload_config; "
            + "if [ -n \"$PREV_KB\" ]; then for _ in $(seq 1 6); do "
            + "[ \"$(mmsg get keyboardlayout 2>/dev/null | jq -r '.layout // empty' 2>/dev/null)\" = \"$PREV_KB\" ] && break; "
            + "mmsg dispatch switch_keyboard_layout 2>/dev/null; sleep 0.1; done; fi; fi"])
    }

    // Queued, never dropped: a tag click issued while a decoration script is
    // still running used to be lost (a busy Process ignores running = true).
    property var _cmdRunner: Commons.CommandRunner { label: "MangoWC" }

    function _cmd(argv) { _cmdRunner.run(argv) }
}
