pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons
import "../Persistence" as Persistence
import "../Compositor" as Compositor

// Night light (item_135): a warm colour temperature, changed LIVE without a
// flash (the old wlsunset presets had to restart the filter, which dropped the
// screen back to neutral between two warm settings).
//
// Backends, picked by compositor (same API either way):
//   mango (any wlroots) → wl-gammarelay-rs: a small daemon on the session bus
//       (rs.wl-gammarelay, object /, interface rs.wl.gammarelay) whose
//       Temperature property is set in place; started on demand.
//   Hyprland → hyprsunset (`hyprctl hyprsunset temperature N` / `identity`).
// Persisted as nightLight.enabled + nightLight.temperature and re-applied at
// login. Off = neutral (6500 K / identity), the daemon keeps running.
QtObject {
    id: root

    readonly property int minTemp: 2500
    readonly property int maxTemp: 6500     // neutral
    readonly property bool hyprland: Compositor.CompositorService.isHyprland
    readonly property string backend: hyprland ? "hyprsunset" : "wl-gammarelay-rs"

    readonly property bool enabled: Persistence.Config.get("nightLight.enabled", false)
    readonly property int  temperature: Persistence.Config.get("nightLight.temperature")
    // Whether the backend binary is installed (checked once at start).
    property bool available: false

    function setEnabled(on) { Persistence.Config.set("nightLight.enabled", !!on); _apply() }
    function setTemperature(k) {
        var t = Math.max(minTemp, Math.min(maxTemp, Math.round(k / 100) * 100))
        Persistence.Config.set("nightLight.temperature", t)
        if (root.enabled) _apply(t)
    }

    // ── Apply ─────────────────────────────────────────────────────────────────
    // Coalescing: while a slider drags, only the newest value is sent.
    property var _runner: Commons.CommandRunner { label: "night light"; coalesce: true }
    readonly property string _bus: "busctl --user"
    readonly property string _obj: "rs.wl-gammarelay / rs.wl.gammarelay"

    function _apply(t) {
        if (!root.available) return
        var k = root.enabled ? (t !== undefined ? t : root.temperature) : root.maxTemp
        if (root.hyprland) {
            _runner.runShell("pgrep -x hyprsunset >/dev/null || { setsid -f hyprsunset >/dev/null 2>&1; sleep 0.5; }; " +
                             (root.enabled ? "hyprctl hyprsunset temperature " + k : "hyprctl hyprsunset identity") + " >/dev/null")
        } else {
            // wlsunset (the old presets) holds the gamma ramp exclusively: stop it.
            _runner.runShell("pkill -x wlsunset 2>/dev/null; " +
                             _bus + " status rs.wl-gammarelay >/dev/null 2>&1 || { setsid -f wl-gammarelay-rs run >/dev/null 2>&1; " +
                             "for i in 1 2 3 4 5 6 7 8 9 10; do " + _bus + " status rs.wl-gammarelay >/dev/null 2>&1 && break; sleep 0.1; done; }; " +
                             _bus + " set-property " + _obj + " Temperature q " + k)
        }
    }

    // ── Start: detect the backend, then re-apply the saved state once config is read.
    property var _probe: Process {
        command: ["bash", "-c", "command -v " + root.backend + " >/dev/null && echo yes || echo no"]
        running: true
        stdout: SplitParser { onRead: line => { root.available = line.trim() === "yes"; root._boot() } }
    }
    property bool _booted: false
    function _boot() {
        if (_booted || !root.available || !Persistence.Config.ready) return
        _booted = true
        if (root.enabled) _apply()
    }
    property var _readyConn: Connections {
        target: Persistence.Config
        function onReadyChanged() { root._boot() }
    }
}
