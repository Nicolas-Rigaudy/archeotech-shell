pragma Singleton
import QtQuick
import Quickshell.Io

// MangoWC IPC service — mangowm 0.15+ `mmsg` JSON IPC (get/watch/dispatch).
// The pre-0.15 flag interface (`mmsg -w -O -t -l -c -f -m -k`, space-delimited
// lines) was removed upstream; this consumes the JSON streams instead.
//
// Two watch streams feed the per-output registry:
//   mmsg watch all-monitors    → {monitors:[{name,active,layout_symbol,
//                                  tags:[{index,is_active,is_urgent,client_count}]}]}
//   mmsg watch focusing-client → {id,title,appid,monitor,is_floating,is_fullscreen,…}
//
// Public API is unchanged from the pre-0.15 service, so call sites need no edits.

QtObject {
    id: root

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
        }
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
    Component.onCompleted: { _watchMonitors.running = true; _watchClient.running = true }

    property var _watchMonitors: Process {
        command: ["mmsg", "watch", "all-monitors"]
        running: false
        stdout: SplitParser { onRead: line => root._parseMonitors(line) }
        onExited: (code, status) => root._scheduleRestart(root._monRestart)
    }
    property var _monRestart: Timer {
        interval: 500; repeat: false
        onTriggered: { root._watchMonitors.running = true; interval = 500 }
    }

    property var _watchClient: Process {
        command: ["mmsg", "watch", "focusing-client"]
        running: false
        stdout: SplitParser { onRead: line => root._parseClient(line) }
        onExited: (code, status) => root._scheduleRestart(root._cliRestart)
    }
    property var _cliRestart: Timer {
        interval: 500; repeat: false
        onTriggered: { root._watchClient.running = true; interval = 500 }
    }

    // Exponential backoff 500ms → cap 8s (reset to 500 on each (re)start attempt).
    function _scheduleRestart(timer) {
        timer.interval = Math.min(timer.interval * 2, 8000)
        timer.start()
    }

    // ── JSON parsers (one full-state object per stream event) ─────────────────────
    function _parseMonitors(line) {
        line = (line || "").trim()
        if (!line || line[0] !== "{") return
        var data
        try { data = JSON.parse(line) } catch (e) { return }
        if (!data || !data.monitors) return
        for (var i = 0; i < data.monitors.length; i++) {
            var m = data.monitors[i]
            var entry = _ensureOutput(m.name)
            entry.layout = m.layout_symbol || ""
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

    property var _cmdRunner: Process {
        property var argv: []
        command: argv
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("MangoWC: command exited with code " + code)
        }
    }

    function _cmd(argv) {
        _cmdRunner.argv = argv
        _cmdRunner.running = true
    }
}
