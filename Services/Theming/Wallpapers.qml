pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons
import "../Persistence" as Persistence

// Persistent wallpaper catalogue (picker perf). Scanned ONCE at shell startup
// and held here, so opening the picker is instant — the old WallpaperPickerBody
// cleared + re-scanned + rebuilt the grid on every open. Small thumbnails are
// generated once via ImageMagick into a cache dir; the picker loads those, not
// the full-res wallpapers (up to 4K PNG / 6K JPEG). This mirrors Caelestia's
// persistent Wallpapers service — minus the C++ (magick via Process instead).
QtObject {
    id: root

    // [{ path, name, thumb }] — bound by the picker; never cleared on open.
    property var list: []
    // Bumped when thumbnail generation finishes so delegates retry the thumb.
    property int thumbGen: 0
    property bool _scanned: false

    // NB: Paths.cache is a file:// URL; strip it so thumb is a plain path and
    // the delegate's "file://" + thumb doesn't double up to "file://file///…".
    readonly property string _thumbsDir:
        (Commons.Paths.cache + "").replace(/^file:\/\//, "") + "/archeotech/wallpaper-thumbs"

    Component.onCompleted: { refresh(); readCurrent() }

    // ── Applied wallpaper ─────────────────────────────────────────────────────
    // Shared by every picker (quick switcher, Settings) so they agree on what is
    // applied. wallpaper-set.sh stays the one writer: it records the path in
    // ~/.cache/wallpaper/last-wallpaper (its LAST_WALL), which the keybind and
    // --restore write too, so that file, not this property, is the truth.
    property string currentPath: ""
    property bool _currentRead: false
    readonly property bool applying: _applyProc.running

    function readCurrent() { if (!_currentReader.running) _currentReader.running = true }

    function apply(path) {
        if (!path) return
        // One wallpaper-set at a time; the last request wins once it exits.
        if (applying) { root._pending = path; return }
        root.currentPath = path
        _applyProc.command = [Commons.Paths.wallpaperSet, path]
        _applyProc.running = true
    }
    property string _pending: ""
    property string _failedPath: ""

    property Process _applyProc: Process {
        running: false
        // A failed run leaves the old wallpaper on screen: re-read what is applied
        // (which also re-checks the mode's slot) rather than trust the pick.
        onExited: (exitCode) => {
            // A path that failed is not retried by the mode follow (it would loop);
            // a pick from a picker still tries it again.
            root._failedPath = exitCode !== 0 ? root.currentPath : ""
            var next = root._pending
            root._pending = ""
            if (next) root.apply(next)
            else root.readCurrent()
        }
    }
    property Process _currentReader: Process {
        running: false
        command: ["bash", "-c", "cat \"$HOME/.cache/wallpaper/last-wallpaper\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: line => { var t = line.trim(); if (t) root.currentPath = t }
        }
        onExited: { root._currentRead = true; root._applyModeSlot() }
    }

    // ── Per-mode wallpapers (item_140) ────────────────────────────────────────
    // Each mode remembers its own wallpaper: a pick fills the slot of the mode
    // it was made in (or the slot a Settings card targets), and the slot for the
    // theme's mode is applied whenever the mode flips (a theme pick, the day/night
    // schedule, or theme-switch from a terminal: all of them rewrite theme.json,
    // which drives Appearance.isLight). An empty slot keeps whatever is on screen,
    // so nothing changes until a wallpaper is picked in that mode. A pack that
    // owns its palette counts as dark. A wallpaper set outside the pickers
    // (wallpaper-picker.sh, a script) fills no slot: the next flip puts the
    // mode's slot back.
    readonly property string mode: Commons.Appearance.isLight ? "light" : "dark"
    readonly property string lightPath: Persistence.Config.get("wallpaper.light")
    readonly property string darkPath: Persistence.Config.get("wallpaper.dark")

    // The mode is only final once theme.json is read and a configured pack has
    // resolved: before that isLight reads false, and following it would flash the
    // dark slot on a light theme at boot.
    readonly property bool _paletteReady: !!(Commons.Appearance._data && Commons.Appearance._data.mode)
        && (Persistence.Config.get("appearance.activePack", "") === "" || Commons.Appearance.activePackDir !== "")

    // The wallpaper a slot holds ("light" | "dark"; "" = the current mode's).
    function slotPath(slot) {
        var s = slot || root.mode
        return s === "light" ? root.lightPath : root.darkPath
    }
    // What a picker marks for a slot: the slot's wallpaper, or (an empty slot of
    // the current mode) the one on screen.
    function markedPath(slot) {
        var s = slot || root.mode
        return root.slotPath(s) || (s === root.mode ? root.currentPath : "")
    }

    // A pick from a picker: fills `slot` (default: the current mode's) and is
    // applied only when that slot is the current mode's.
    function choose(path, slot) {
        var s = slot || root.mode
        Persistence.Config.set("wallpaper." + s, path)
        if (s === root.mode) apply(path)
    }

    // ── Brightness (which mode a wallpaper suits) ───────────────────────────
    // Measured once per wallpaper from its thumbnail and cached beside it
    // (<thumb>.lum, mean grey 0..1). Dark ones are offered in dark mode, light
    // ones in light mode, the middle band in both; `showAll` lifts the filter for
    // the session (shared by every picker).
    readonly property real darkMax: 0.35
    readonly property real lightMin: 0.60
    property var _lum: ({})
    property bool showAll: false
    function toneOf(path) {
        var l = root._lum[path]
        if (l === undefined) return "both"
        return l < root.darkMax ? "dark" : (l > root.lightMin ? "light" : "both")
    }
    function suits(path, mode) {
        var t = root.toneOf(path)
        return t === "both" || t === (mode || root.mode)
    }

    // ── Colour preview (item_006) ────────────────────────────────────────────
    // The accent wallpaper-set.sh would extract for a wallpaper, so a picker can
    // show it while it scrolls. Nothing is applied: `--print-color` only reads the
    // image. One lookup at a time, debounced, cached per path for the session.
    property string previewFor: ""
    property var _previewCache: ({})
    readonly property string previewColor: root.previewFor ? (root._previewCache[root.previewFor] || "") : ""

    function preview(path) {
        root.previewFor = path || ""
        if (root.previewFor && !root._previewCache[root.previewFor]) _previewWant.restart()
    }
    property Timer _previewWant: Timer {
        interval: 150
        onTriggered: root._previewNext()
    }
    function _previewNext() {
        if (_previewProc.running) return
        var p = root.previewFor
        if (!p || root._previewCache[p]) return
        _previewProc.target = p
        _previewProc.command = [Commons.Paths.wallpaperSet, "--print-color", p]
        _previewProc.running = true
    }
    property Process _previewProc: Process {
        property string target: ""
        running: false
        stdout: SplitParser {
            onRead: line => {
                var c = line.trim()
                if (!/^#[0-9a-fA-F]{6}$/.test(c)) return
                var next = Object.assign({}, root._previewCache)
                next[root._previewProc.target] = c
                root._previewCache = next
            }
        }
        // The pick moved on while this ran: look the new one up now.
        onExited: root._previewNext()
    }

    // Settled, so a theme switch (palette file rewritten, pack resolved at boot)
    // applies once, after the mode has stopped moving. The timer re-reads the
    // applied wallpaper first (it may have changed outside the shell); the reader
    // then applies the mode's slot if it differs.
    function _followMode() { _follow.restart() }
    property Timer _follow: Timer {
        interval: 800
        onTriggered: root.readCurrent()
    }
    function _applyModeSlot() {
        if (!Persistence.Config.ready || !root._currentRead || !root._scanned || !root._paletteReady) return
        var want = root.slotPath(root.mode)
        // Only a wallpaper still in the catalogue: a deleted file would leave
        // the screen on the old one while the picker marks the missing one.
        if (!want || want === root.currentPath || want === root._failedPath || root.applying) return
        if (!root.list.some(w => w.path === want)) return
        root.apply(want)
    }
    onModeChanged: _followMode()
    onLightPathChanged: _followMode()
    onDarkPathChanged: _followMode()
    on_PaletteReadyChanged: _followMode()
    property Connections _readyConn: Connections {
        target: Persistence.Config
        function onReadyChanged() { root._followMode() }
    }

    // Re-scan + regenerate stale thumbs. Runs once at startup; call again only
    // to pick up newly-added wallpapers (reassigns `list`, which rebuilds the
    // grid — so not wired to panel-open, which must stay instant).
    function refresh() {
        if (!_scan.running)   _scan.running   = true
        if (!_thumbs.running) _thumbs.running = true
    }

    property Process _scan: Process {
        id: scanProc
        running: false
        command: ["bash", "-c",
            "find -L \"$HOME/.config/archeotech/wallpapers\" " +
            "-maxdepth 1 -type f -regextype posix-extended " +
            "-iregex '.*\\.(jpe?g|png|webp)$' | sort"]
        property var _buf: []
        onRunningChanged: if (running) scanProc._buf = []
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim()
                if (!p) return
                var slash = p.lastIndexOf("/")
                var dot   = p.lastIndexOf(".")
                var stem  = p.substring(slash + 1, dot >= 0 ? dot : p.length)
                var name  = stem.replace(/[_-]/g, " ")
                // Thumb keyed by full basename (+.jpg) so a.png/a.jpg don't collide.
                var thumb = root._thumbsDir + "/" + p.substring(slash + 1) + ".jpg"
                scanProc._buf = (scanProc._buf || []).concat([{ path: p, name: name, thumb: thumb }])
            }
        }
        onExited: { root.list = scanProc._buf || []; root._scanned = true; root._followMode() }
    }

    property Process _thumbs: Process {
        running: false
        // Thumbnail, then its brightness (cached as <thumb>.lum); prints
        // "<wallpaper>\t<lum>" per wallpaper.
        command: ["bash", "-c",
            "export TH=\"$HOME/.cache/archeotech/wallpaper-thumbs\"; mkdir -p \"$TH\"; " +
            "find -L \"$HOME/.config/archeotech/wallpapers\" -maxdepth 1 -type f " +
            "-regextype posix-extended -iregex '.*\\.(jpe?g|png|webp)$' -print0 | " +
            "xargs -0 -r -P4 -I{} bash -c '" +
            "t=\"$TH/$(basename \"$1\").jpg\"; l=\"$t.lum\"; " +
            "{ [ -f \"$t\" ] && [ ! \"$1\" -nt \"$t\" ]; } || " +
            "magick \"$1\" -thumbnail 640x480 -strip -quality 82 \"$t\"; " +
            "{ [ -s \"$l\" ] && [ ! \"$t\" -nt \"$l\" ]; } || " +
            "magick \"$t\" -alpha off -resize 1x1! -colorspace Gray -format \"%[fx:mean]\" info: > \"$l\"; " +
            "printf \"%s\\t%s\\n\" \"$1\" \"$(cat \"$l\")\"' _ {}"]
        property var _buf: ({})
        onRunningChanged: if (running) _buf = ({})
        stdout: SplitParser {
            onRead: line => {
                var tab = line.indexOf("\t")
                if (tab < 0) return
                var v = parseFloat(line.substring(tab + 1))
                if (!isNaN(v)) root._thumbs._buf[line.substring(0, tab)] = v
            }
        }
        onExited: { root._lum = root._thumbs._buf; root.thumbGen++ }
    }
}
