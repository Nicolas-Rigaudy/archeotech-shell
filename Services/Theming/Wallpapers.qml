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
    // Off by default: one wallpaper for both modes, exactly as before. On, the
    // light and dark slots each hold a wallpaper and the one for the theme's mode
    // is applied whenever the mode flips (a theme pick, the day/night schedule, or
    // theme-switch from a terminal: all of them rewrite theme.json, which drives
    // Appearance.isLight). A pack that owns its palette counts as dark. A wallpaper
    // set outside the pickers (wallpaper-picker.sh, a script) fills no slot: the
    // next mode flip puts the mode's slot back.
    readonly property bool perMode: Persistence.Config.get("wallpaper.perMode")
    readonly property string mode: Commons.Appearance.isLight ? "light" : "dark"
    readonly property string lightPath: Persistence.Config.get("wallpaper.light")
    readonly property string darkPath: Persistence.Config.get("wallpaper.dark")

    // The mode is only final once theme.json is read and a configured pack has
    // resolved: before that isLight reads false, and following it would flash the
    // dark slot on a light theme at boot.
    readonly property bool _paletteReady: !!(Commons.Appearance._data && Commons.Appearance._data.mode)
        && (Persistence.Config.get("appearance.activePack", "") === "" || Commons.Appearance.activePackDir !== "")

    // The wallpaper a slot holds: "light" | "dark", or "" for the one a pick
    // without a slot changes (the current mode's slot with per-mode on).
    function slotPath(slot) {
        if (slot === "light") return root.lightPath
        if (slot === "dark") return root.darkPath
        return root.perMode ? root.slotPath(root.mode) : root.currentPath
    }

    // A pick from a picker. With per-mode on it fills `slot` (default: the
    // current mode's) and is applied only when that slot is the current mode's.
    function choose(path, slot) {
        if (root.perMode) {
            var s = slot || root.mode
            Persistence.Config.set("wallpaper." + s, path)
            if (s !== root.mode) return
        }
        apply(path)
    }

    // Turning per-mode on fills empty slots with the applied wallpaper, so nothing
    // changes until a slot gets a different one. Turning it off keeps the slots.
    function setPerMode(on) {
        if (on) {
            if (!root.lightPath && root.currentPath) Persistence.Config.set("wallpaper.light", root.currentPath)
            if (!root.darkPath && root.currentPath) Persistence.Config.set("wallpaper.dark", root.currentPath)
        }
        Persistence.Config.set("wallpaper.perMode", on)
    }

    // Settled, so a theme switch (palette file rewritten, pack resolved at boot)
    // applies once, after the mode has stopped moving. The timer re-reads the
    // applied wallpaper first (it may have changed outside the shell); the reader
    // then applies the mode's slot if it differs.
    function _followMode() { _follow.restart() }
    property Timer _follow: Timer {
        interval: 800
        onTriggered: if (root.perMode) root.readCurrent()
    }
    function _applyModeSlot() {
        if (!root.perMode || !Persistence.Config.ready || !root._currentRead || !root._scanned || !root._paletteReady) return
        var want = root.slotPath(root.mode)
        // Only a wallpaper still in the catalogue: a deleted file would leave
        // the screen on the old one while the picker marks the missing one.
        if (!want || want === root.currentPath || want === root._failedPath || root.applying) return
        if (!root.list.some(w => w.path === want)) return
        root.apply(want)
    }
    onModeChanged: _followMode()
    onPerModeChanged: _followMode()
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
        command: ["bash", "-c",
            "export TH=\"$HOME/.cache/archeotech/wallpaper-thumbs\"; mkdir -p \"$TH\"; " +
            "find -L \"$HOME/.config/archeotech/wallpapers\" -maxdepth 1 -type f " +
            "-regextype posix-extended -iregex '.*\\.(jpe?g|png|webp)$' -print0 | " +
            "xargs -0 -r -P4 -I{} bash -c '" +
            "t=\"$TH/$(basename \"$1\").jpg\"; " +
            "{ [ -f \"$t\" ] && [ ! \"$1\" -nt \"$t\" ]; } || " +
            "magick \"$1\" -thumbnail 640x480 -strip -quality 82 \"$t\"' _ {}"]
        onExited: root.thumbGen++
    }
}
