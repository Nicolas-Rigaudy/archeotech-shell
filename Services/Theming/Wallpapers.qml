pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons
import "../Persistence" as Persistence
import "../Shell" as ShellServices
import "WallpapersLogic.js" as Logic

// Persistent wallpaper catalogue (picker perf). Scanned ONCE at shell startup
// and held here, so opening the picker is instant — the old WallpaperPickerBody
// cleared + re-scanned + rebuilt the grid on every open. Small thumbnails are
// generated once via ImageMagick into a cache dir; the picker loads those, not
// the full-res wallpapers (up to 4K PNG / 6K JPEG). This mirrors Caelestia's
// persistent Wallpapers service — minus the C++ (magick via Process instead).
QtObject {
    id: root

    // [{ path, name, thumb, pack }] — bound by the picker; never cleared on open.
    // `pack` is the id of the active pack that ships the wallpaper, "" for the
    // user's own (~/.config/archeotech/wallpapers). Pack ones come first.
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
    // applied. wallpaper-set.sh stays the one writer: it records the main image
    // in ~/.cache/wallpaper/last-wallpaper (its LAST_WALL) and the screens with
    // their own image in last-screens; the keybind and --restore write them too,
    // so those files, not these properties, are the truth.
    property string currentPath: ""
    property var currentScreens: ({})      // { output: path } with their own image
    property bool _currentRead: false
    // Set as soon as apply() launches: Process.running only turns true once the
    // process has started, and a pick in between would replace the command of
    // a run already launching (and be lost).
    property bool _launched: false
    readonly property bool applying: _launched || _applyProc.running

    // The catalogue thumbnail of a wallpaper (the image itself when it has none).
    function thumbOf(path) {
        const w = root.list.find(e => e.path === path)
        return w && w.thumb ? w.thumb : path
    }
    // The image on one output (item_148): its own, else the main one.
    function shownOn(name) { return Logic.shownOn(root.currentPath, root.currentScreens, name) }

    // Env for any wallpaper-set.sh run (item_148): the fits go in by env
    // because config.json is written on a debounce, so a just-changed Fit
    // would not be on disk yet. Merged over the inherited environment.
    function fitEnv() {
        return { WALLPAPER_CONFIG: Logic.envConfig(Persistence.Config.get("wallpaper.fit"),
            Persistence.Config.get("wallpaper.anchor"), root.screens) }
    }

    function readCurrent() { if (!_currentReader.running) _currentReader.running = true }

    // apply(path[, images]): `path` on every output, `images` ({ output: path })
    // on the outputs with their own (default: the current mode's per-screen
    // images, none in the "same" layout).
    function apply(path, images) {
        if (!path) return
        var im = images !== undefined ? images : root._imagesFor(root.mode)
        // One wallpaper-set at a time; the last request wins once it exits.
        if (applying) { root._pending = { path: path, images: im }; return }
        root.currentPath = path
        root.currentScreens = im
        _applyProc.environment = root.fitEnv()
        _applyProc.command = [Commons.Paths.wallpaperSet].concat(Logic.args(path, im))
        root._launched = true
        _applyProc.running = true
        _launchGuard.restart()
    }
    // A run that never started (no exit follows) must not block later picks.
    property Timer _launchGuard: Timer {
        interval: 5000
        onTriggered: if (root._launched && !root._applyProc.running) {
            root._launched = false
            var next = root._pending
            root._pending = null
            if (next) root.apply(next.path, next.images)
            else root.readCurrent()
        }
    }
    // Re-send the applied wallpaper, e.g. after a Fit setting changed.
    function reapply() { apply(root.currentPath, root.currentScreens) }
    property var _pending: null
    property string _failedSig: ""

    property Process _applyProc: Process {
        running: false
        // A failed run leaves the old wallpaper on screen: re-read what is applied
        // (which also re-checks the mode's slot) rather than trust the pick.
        onRunningChanged: if (running) root._launchGuard.stop()
        onExited: (exitCode) => {
            root._launched = false
            // A plan that failed is not retried by the mode follow (it would loop);
            // a pick from a picker still tries it again.
            root._failedSig = exitCode !== 0 ? Logic.signature(root.currentPath, root.currentScreens) : ""
            var next = root._pending
            root._pending = null
            if (next) root.apply(next.path, next.images)
            else root.readCurrent()
        }
    }
    property Process _currentReader: Process {
        property string _main: ""
        property string _screens: ""
        running: false
        // Section markers keep the two files apart in one run.
        command: ["bash", "-c", "d=\"$HOME/.cache/wallpaper\"; cat \"$d/last-wallpaper\" 2>/dev/null; "
            + "echo @@screens; cat \"$d/last-screens\" 2>/dev/null; true"]
        onStarted: { _main = ""; _screens = ""; _inScreens = false }
        property bool _inScreens: false
        stdout: SplitParser {
            onRead: line => {
                var r = root._currentReader
                if (line === "@@screens") { r._inScreens = true; return }
                if (r._inScreens) r._screens += line + "\n"
                else if (line.trim()) r._main = line.trim()
            }
        }
        onExited: {
            if (_main) root.currentPath = _main
            root.currentScreens = Logic.parseScreens(_screens)
            root._currentRead = true
            root._applyModeSlot()
        }
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

    // ── Per screen (item_148 wave 2) ─────────────────────────────────────────
    // layout "same": one image everywhere; "screens": each output may hold its
    // own light/dark image in wallpaper.screens.<output> (unset = the all-screens
    // one). Fit/anchor per output apply in both layouts. Outputs not in the
    // config (a new monitor, after a dock) get the all-screens image and fit.
    readonly property string layout: Persistence.Config.get("wallpaper.layout")
    readonly property bool perScreen: root.layout === "screens"
    readonly property var screens: Persistence.Config.get("wallpaper.screens")
    function _imagesFor(mode) {
        return Logic.screenImages(root.layout, root.screens, mode, p => root.list.some(w => w.path === p))
    }
    function setLayout(v) {
        if (v === Persistence.Config.defaultFor("wallpaper.layout")) Persistence.Config.reset("wallpaper.layout")
        else Persistence.Config.set("wallpaper.layout", v)
    }
    function _setScreen(name, key, value) {
        var next = Logic.withScreen(root.screens, name, key, value)
        if (Object.keys(next).length) Persistence.Config.set("wallpaper.screens", next)
        else Persistence.Config.reset("wallpaper.screens")
    }
    // The fit/anchor an output uses ("" = the all-screens value), whether it has
    // its own, and setting it ("" output = all screens; "" value = inherit).
    function fitOf(name) { return Logic.fitOf(Persistence.Config.get("wallpaper.fit"), root.screens, name) }
    function anchorOf(name) { return Logic.anchorOf(Persistence.Config.get("wallpaper.anchor"), root.screens, name) }
    function ownFit(name, key) { return !!name && Logic.screenValue(root.screens, name, key || "fit") !== "" }
    function setFit(name, key, value) {
        if (name) root._setScreen(name, key, value)
        else if (!value || value === Persistence.Config.defaultFor("wallpaper." + key)) Persistence.Config.reset("wallpaper." + key)
        else Persistence.Config.set("wallpaper." + key, value)
        root.reapply()
    }

    // The mode is only final once theme.json is read and a configured pack has
    // resolved: before that isLight reads false, and following it would flash the
    // dark slot on a light theme at boot.
    readonly property bool _paletteReady: !!(Commons.Appearance._data && Commons.Appearance._data.mode)
        && (Persistence.Config.get("appearance.activePack", "") === "" || Commons.Appearance.activePackDir !== "")

    // The wallpaper a slot holds ("light" | "dark"; "" = the current mode's), for
    // all screens, or for output `screen` in the per-screen layout ("" = unset,
    // the all-screens one shows).
    function slotPath(slot, screen) {
        var s = slot || root.mode
        if (screen && root.perScreen) return Logic.screenValue(root.screens, screen, s)
        return s === "light" ? root.lightPath : root.darkPath
    }
    // What a picker marks for a slot: the slot's wallpaper, or (an empty slot of
    // the current mode) the one on screen. An output with no image of its own
    // marks the all-screens one.
    function markedPath(slot, screen) {
        var s = slot || root.mode
        if (screen && root.perScreen) {
            const own = root.slotPath(s, screen)
            if (own) return own
        }
        return root.slotPath(s) || (s === root.mode ? root.currentPath : "")
    }

    // A pick from a picker: fills `slot` (default: the current mode's), of output
    // `screen` in the per-screen layout, and is applied only when that slot is
    // the current mode's.
    function choose(path, slot, screen) {
        var s = slot || root.mode
        if (screen && root.perScreen) {
            root._setScreen(screen, s, path)
            if (s === root.mode) {
                const im = Object.assign({}, root._imagesFor(s))
                im[screen] = path
                apply(root.slotPath(s) || root.currentPath || path, im)
            }
            return
        }
        Persistence.Config.set("wallpaper." + s, path)
        if (s === root.mode) apply(path)
    }
    // Back to the all-screens image for one output's slot.
    function clearScreen(screen, slot) {
        var s = slot || root.mode
        root._setScreen(screen, s, "")
        if (s === root.mode) _followMode()
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
        if (root.applying) return
        // Only wallpapers still in the catalogue: a deleted file would leave the
        // screen on the old one while the picker marks the missing one. An empty
        // main slot keeps the image on screen.
        var main = root.slotPath(root.mode)
        if (!main || !root.list.some(w => w.path === main)) main = root.currentPath
        if (!main) return
        var im = root._imagesFor(root.mode)
        var sig = Logic.signature(main, im)
        if (sig === Logic.signature(root.currentPath, root.currentScreens) || sig === root._failedSig) return
        root.apply(main, im)
    }
    onModeChanged: _followMode()
    onLightPathChanged: _followMode()
    onDarkPathChanged: _followMode()
    onLayoutChanged: _followMode()
    onScreensChanged: _followMode()
    on_PaletteReadyChanged: _followMode()
    property Connections _readyConn: Connections {
        target: Persistence.Config
        function onReadyChanged() { root._followMode() }
    }

    // ── Pack wallpapers (item_151) ───────────────────────────────────────────
    // The active pack's own wallpapers (pack.json "wallpapers", a folder in the
    // pack) join the catalogue while that pack is active and leave it when the
    // pack changes. Their thumbs are keyed "pack-<id>-<file>" so a pack's
    // netrunner.png never shares a thumb with a user file of the same name; the
    // user's own ones for the pack (see _packNow) are keyed "pack-<id>~own~<file>".
    readonly property string packId: Persistence.Config.get("appearance.activePack", "")
    readonly property string packDir: ShellServices.PackRegistry.wallpaperDirFor(root.packId)
    onPackDirChanged: refresh()
    onPackIdChanged: refresh()
    // Display name of the active pack ("" for the base look), for picker labels.
    readonly property string packName: {
        var p = root.packId ? ShellServices.PackRegistry.packFor(root.packId) : null
        return p ? (p.name || p.id) : ""
    }

    // What a picker offers for `mode` (owner, 2026-11-06): while the active pack
    // ships wallpapers that suit the mode, only those, with `keep` (the marked
    // one) first so the carousel opens on it and the pack's sit beside it;
    // otherwise every wallpaper that suits the mode. `packOnly` says which one a
    // list is, for the label. Show all lifts both filters.
    function offered(mode, keep) {
        var all = root.list
        if (root.showAll) return { list: all, packOnly: false }
        var m = mode || root.mode
        var pk = all.filter(w => w.pack && w.pack === root.packId && root.suits(w.path, m))
        if (pk.length)
            return { list: all.filter(w => w.path === keep && !w.pack).concat(pk), packOnly: true }
        return { list: all.filter(w => w.path === keep || root.suits(w.path, m)), packOnly: false }
    }
    // Read fresh by each pass (not from bindings, which may not have settled
    // when onPackDirChanged runs): [pack dir, its thumb prefix, pack id,
    // own dir, its thumb prefix]. The own dir is the user's private folder for
    // a pack, ~/.local/share/archeotech/pack-wallpapers/<id>/ (subfolders
    // included): wallpapers that can't ship publicly with the pack (franchise
    // art) but count as the pack's in the pickers. Basenames must be unique
    // across its subfolders (thumbs are keyed by basename).
    function _packNow() {
        var id = root.packId
        if (!id || !/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(id)) return ["", "", "", "", ""]
        var dir = ShellServices.PackRegistry.wallpaperDirFor(id)
        return [dir || "", "pack-" + id + "-", id,
                "pack-wallpapers/" + id, "pack-" + id + "~own~"]
    }

    // Re-scan + regenerate stale thumbs. Runs at startup and when the active
    // pack's wallpapers change; call again only to pick up newly-added
    // wallpapers (reassigns `list`, which rebuilds the grid — so not wired to
    // panel-open, which must stay instant). A call while a scan runs queues one
    // more pass, so a pack switch mid-scan is never lost.
    function refresh() {
        if (root._scan.running) root._scan.again = true
        else root._scan.start()
        if (root._thumbs.running) root._thumbs.again = true
        else root._thumbs.start()
    }

    // Prints "p\t<path>" for the pack's wallpapers ($1, may be empty), "o\t<path>"
    // for the user's own ones for the pack ($2 under ~/.local/share/archeotech,
    // recursive), then "u\t<path>" for the user's. ls1's $3 is unquoted on
    // purpose: '' adds nothing, '-maxdepth 1' splits into two find args.
    property Process _scan: Process {
        id: scanProc
        running: false
        property bool again: false
        property string _pack: ""
        property string _prefix: ""
        property string _ownPrefix: ""
        function start() {
            var pk = root._packNow()
            scanProc._prefix = pk[1]
            scanProc._pack = pk[2]
            scanProc._ownPrefix = pk[4]
            scanProc.command = ["bash", "-c",
                "ls1(){ [ -n \"$2\" ] && [ -d \"$2\" ] || return 0; " +
                "find -L \"$2\" $3 -type f -regextype posix-extended " +
                "-iregex '.*\\.(jpe?g|png|webp)$' | sort | " +
                "while IFS= read -r f; do printf '%s\\t%s\\n' \"$1\" \"$f\"; done; }; " +
                "ls1 p \"$1\" '-maxdepth 1'; " +
                "[ -n \"$2\" ] && ls1 o \"$HOME/.local/share/archeotech/$2\" ''; " +
                "ls1 u \"$HOME/.config/archeotech/wallpapers\" '-maxdepth 1'",
                "_", pk[0], pk[3]]
            scanProc.running = true
        }
        property var _buf: []
        onRunningChanged: if (running) scanProc._buf = []
        stdout: SplitParser {
            onRead: line => {
                var tab = line.indexOf("\t")
                if (tab < 0) return
                var tag = line.substring(0, tab)
                var fromPack = tag === "p" || tag === "o"
                var p = line.substring(tab + 1).trim()
                if (!p || (scanProc._buf || []).some(w => w.path === p)) return
                var slash = p.lastIndexOf("/")
                var dot   = p.lastIndexOf(".")
                var stem  = p.substring(slash + 1, dot >= 0 ? dot : p.length)
                var name  = stem.replace(/[_-]/g, " ")
                // Thumb keyed by full basename (+.jpg) so a.png/a.jpg don't collide.
                var thumb = root._thumbsDir + "/"
                    + (tag === "p" ? scanProc._prefix : tag === "o" ? scanProc._ownPrefix : "")
                    + p.substring(slash + 1) + ".jpg"
                scanProc._buf = (scanProc._buf || []).concat([
                    { path: p, name: name, thumb: thumb, pack: fromPack ? scanProc._pack : "" }])
            }
        }
        onExited: {
            if (scanProc.again) { scanProc.again = false; scanProc.start(); return }
            root.list = scanProc._buf || []; root._scanned = true; root._followMode()
        }
    }

    property Process _thumbs: Process {
        id: thumbsProc
        running: false
        property bool again: false
        // Thumbnail, then its brightness (cached as <thumb>.lum); prints
        // "<wallpaper>\t<lum>" per wallpaper. $1/$2 = the pack's wallpaper dir (may
        // be empty) + thumb prefix, $3/$4 = the user's own dir for the pack +
        // prefix (same keys as the scan).
        function start() {
            var pk = root._packNow()
            thumbsProc.command = ["bash", "-c",
            "export TH=\"$HOME/.cache/archeotech/wallpaper-thumbs\"; mkdir -p \"$TH\"; " +
            "one(){ [ -n \"$1\" ] && [ -d \"$1\" ] || return 0; export PFX=\"$2\"; " +
            "find -L \"$1\" $3 -type f " +
            "-regextype posix-extended -iregex '.*\\.(jpe?g|png|webp)$' -print0 | " +
            "xargs -0 -r -P4 -I{} bash -c '" +
            "t=\"$TH/$PFX$(basename \"$1\").jpg\"; l=\"$t.lum\"; " +
            "{ [ -f \"$t\" ] && [ ! \"$1\" -nt \"$t\" ]; } || " +
            "magick \"$1\" -thumbnail 640x480 -strip -quality 82 \"$t\"; " +
            "{ [ -s \"$l\" ] && [ ! \"$t\" -nt \"$l\" ]; } || " +
            "magick \"$t\" -alpha off -resize 1x1! -colorspace Gray -format \"%[fx:mean]\" info: > \"$l\"; " +
            "printf \"%s\\t%s\\n\" \"$1\" \"$(cat \"$l\")\"' _ {}; }; " +
            "one \"$1\" \"$2\" '-maxdepth 1'; " +
            "[ -n \"$3\" ] && one \"$HOME/.local/share/archeotech/$3\" \"$4\" ''; " +
            "one \"$HOME/.config/archeotech/wallpapers\" '' '-maxdepth 1'",
            "_", pk[0], pk[1], pk[3], pk[4]]
            thumbsProc.running = true
        }
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
        onExited: {
            if (thumbsProc.again) { thumbsProc.again = false; thumbsProc.start(); return }
            root._lum = root._thumbs._buf; root.thumbGen++
        }
    }
}
