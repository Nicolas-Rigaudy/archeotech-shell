pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons

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

    // NB: Paths.cache is a file:// URL; strip it so thumb is a plain path and
    // the delegate's "file://" + thumb doesn't double up to "file://file///…".
    readonly property string _thumbsDir:
        (Commons.Paths.cache + "").replace(/^file:\/\//, "") + "/archeotech/wallpaper-thumbs"

    Component.onCompleted: refresh()

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
        onExited: root.list = scanProc._buf || []
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
