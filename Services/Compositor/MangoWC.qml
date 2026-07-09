pragma Singleton
import QtQuick
import Quickshell.Io

// MangoWC IPC service — streams compositor state via mmsg -w.
//
// mmsg watch-mode line format:
//   <output> tag    <num> <selected> <occupied> <urgent>
//   <output> title  <text...>
//   <output> appid  <text...>
//   <output> layout <symbol>
//   <output> selmon <0|1>
//   <output> float  <0|1>        (focused client floating state)
//   <output> fullscreen <0|1>    (focused client fullscreen state)
//   <output> kblayout <name>     (active keyboard layout)

QtObject {
    id: root

    // ── Output registry ────────────────────────────────────────────────────────
    // Map of output name → OutputState QtObject. Use outputFor() to access.
    property var _outputs: ({})

    // Convenience: name of the currently focused output
    property string focusedOutput: ""

    // Component template for per-output state objects
    property Component _outputComponent: Component {
        QtObject {
            property string name:          ""
            property var    tags:          []   // [{num, selected, occupied, urgent}]
            property string title:         ""
            property string appid:         ""
            property string layout:        ""
            property bool   focused:       false
            property bool   floating:      false
            property bool   fullscreen:    false
            property string keyboardLayout: ""
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

    // ── Public accessors ───────────────────────────────────────────────────────

    function outputFor(name) {
        return _outputs[name] || null
    }

    function tagsFor(name) {
        var o = _outputs[name]
        return o ? o.tags : []
    }

    function titleFor(name) {
        var o = _outputs[name]
        return o ? o.title : ""
    }

    function layoutFor(name) {
        var o = _outputs[name]
        return o ? o.layout : ""
    }

    function isFloating(name) {
        var o = _outputs[name]
        return o ? o.floating : false
    }

    function isFullscreen(name) {
        var o = _outputs[name]
        return o ? o.fullscreen : false
    }

    function keyboardLayoutFor(name) {
        var o = _outputs[name]
        return o ? o.keyboardLayout : ""
    }

    // ── Watch stream ───────────────────────────────────────────────────────────

    Component.onCompleted: _watch.running = true

    property var _watch: Process {
        // -O output name  -t tags  -l layout  -c title+appid
        // -f floating      -m fullscreen       -k keyboard layout
        // -w watch mode    (selmon included implicitly with -O in watch mode)
        command: ["mmsg", "-w", "-O", "-t", "-l", "-c", "-f", "-m", "-k"]
        running: false
        stdout: SplitParser {
            onRead: line => root._parseLine(line.trim())
        }
        onExited: (code, status) => {
            // Exponential backoff: 500ms → 1s → 2s → 4s → cap 8s
            _restartTimer.interval = Math.min(_restartTimer.interval * 2, 8000)
            _restartTimer.start()
        }
    }

    property var _restartTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: {
            root._watch.running = true
            interval = 500 // reset after successful start
        }
    }

    // ── Line parser ────────────────────────────────────────────────────────────

    function _parseLine(line) {
        if (!line || line.startsWith("+") || line.startsWith("-")) return

        var parts = line.split(" ")
        if (parts.length < 2) return

        var outputName = parts[0]
        var field      = parts[1]
        var entry      = _ensureOutput(outputName)

        if (field === "tag" && parts.length >= 6) {
            var num      = parseInt(parts[2])
            var selected = parts[3] === "1"
            var occupied = parts[4] === "1"
            var urgent   = parts[5] === "1"
            var tags = entry.tags.slice()
            var found = false
            for (var i = 0; i < tags.length; i++) {
                if (tags[i].num === num) {
                    tags[i] = { num: num, selected: selected, occupied: occupied, urgent: urgent }
                    found = true
                    break
                }
            }
            if (!found) tags.push({ num: num, selected: selected, occupied: occupied, urgent: urgent })
            tags.sort((a, b) => a.num - b.num)
            entry.tags = tags

        } else if (field === "title") {
            entry.title = parts.slice(2).join(" ")

        } else if (field === "appid") {
            entry.appid = parts.slice(2).join(" ")

        } else if (field === "layout") {
            entry.layout = parts[2] || ""

        } else if (field === "selmon") {
            entry.focused = parts[2] === "1"
            if (entry.focused) root.focusedOutput = outputName

        } else if (field === "float") {
            entry.floating = parts[2] === "1"

        } else if (field === "fullscreen") {
            entry.fullscreen = parts[2] === "1"

        } else if (field === "kblayout") {
            entry.keyboardLayout = parts.slice(2).join(" ")
        }
    }

    // ── Actions ────────────────────────────────────────────────────────────────

    // Switch to tag N on a given output (1-based)
    function switchTag(outputName, tagNum) {
        _cmd("mmsg -o " + outputName + " -s -t " + tagNum)
    }

    // Toggle tag N on a given output (adds/removes without deselecting others)
    function toggleTag(outputName, tagNum) {
        _cmd("mmsg -o " + outputName + " -s -t ^" + tagNum)
    }

    // Send a dispatch command to MangoWC (e.g. "togglefloating", "fullscreen 0")
    // Up to 5 comma-separated args supported by mmsg -d protocol
    function dispatch(command) {
        var parts = command.split(" ")
        var cmd   = parts[0]
        var args  = parts.slice(1).join(",")
        var mmsg  = args.length > 0
            ? "mmsg -s -d " + cmd + "," + args
            : "mmsg -s -d " + cmd
        _cmd(mmsg)
    }

    // Convenience dispatches
    function toggleFloating()  { dispatch("togglefloating") }
    function toggleFullscreen() { dispatch("fullscreen 0") }
    function closeWindow()     { dispatch("killclient") }

    // Live-set the focused scroller window's width fraction (0..1).
    function setProportion(p) { dispatch("set_proportion " + Number(p).toFixed(2)) }

    // Persist the scroller default into mango's config.conf so windows opened in
    // future sessions inherit it. Mango re-reads this global only on reload/login,
    // so it affects *new* windows from then on — not the current ones. The sed is
    // surgical (anchored single key line) and --follow-symlinks keeps the dotfiles
    // symlink intact (it edits the repo file the symlink points at).
    function setDefaultProportion(p) {
        var v = Number(p).toFixed(2)
        _cmd("sed --follow-symlinks -i "
             + "'s|^scroller_default_proportion=.*|scroller_default_proportion=" + v + "|' "
             + "\"$HOME/.config/mango/config.conf\"")
    }

    property var _cmdRunner: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("MangoWC: command exited with code " + code)
        }
    }

    function _cmd(shellCmd) {
        _cmdRunner.cmd = shellCmd
        _cmdRunner.running = true
    }
}
