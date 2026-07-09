pragma Singleton
import QtQuick
import Quickshell.Io
import "../Persistence" as Persistence

// Sprint 21 Chunk 2 — community extension discovery.
//
// Scans two roots for self-describing modules (each a folder with a
// `module.json` + entry QML):
//   ~/.config/quickshell/modules/        — repo-tracked / bundled modules
//   ~/.local/share/archeotech/modules/   — user-installed modules
//
// A module is referenced from shell-config.json by `plugin:<id>` (matching
// WidgetRegistry's existing plugin-prefix convention). Built-in bar widgets,
// strip icons and panels are NOT modules — they stay in WidgetRegistry /
// PanelRegistry. This registry is purely the third-party extension layer.
//
// Discovery uses the codebase's standard Process+jq scan idiom (see
// ActiveProjects). jq emits one compact JSON object per module, each tagged
// with its absolute directory so `entryUrl()` can resolve the QML file.
//
// module.json schema — see docs/MODULE_API.md:
//   { id, name, author, version, canLiveIn[], entry, icon, defaultSize{}, panel{}, configSchema{} }
//   canLiveIn ∈ { "bar-zone", "strip-icon", "panel-content", "desktop-widget" }
QtObject {
    id: root

    // Discovered modules: array of the parsed manifest objects, each with an
    // extra `dir` (absolute, trailing slash) injected by the scan.
    property var modules: []
    property bool ready: false

    function _bare(id) {
        return (typeof id === "string" && id.indexOf("plugin:") === 0) ? id.slice(7) : id
    }

    function moduleFor(id) {
        var b = _bare(id)
        for (var i = 0; i < modules.length; i++)
            if (modules[i].id === b) return modules[i]
        return null
    }

    // Absolute file:// URL to a module's entry QML, or "" if unknown.
    function entryUrl(id) {
        var m = moduleFor(id)
        if (!m || !m.dir || !m.entry) return ""
        return "file://" + m.dir + m.entry
    }

    function canLiveIn(id, target) {
        var m = moduleFor(id)
        return !!m && (m.canLiveIn || []).indexOf(target) !== -1
    }

    // Modules accepting any of the given placement targets (for the palette).
    // Disabled modules are excluded so the builder can't place new instances of
    // them (Sprint 26 — enable/disable from the Plugins pane).
    function modulesFor(targets) {
        var out = []
        for (var i = 0; i < modules.length; i++) {
            if (!isEnabled(modules[i].id)) continue
            var cl = modules[i].canLiveIn || []
            for (var j = 0; j < targets.length; j++) {
                if (cl.indexOf(targets[j]) !== -1) { out.push(modules[i]); break }
            }
        }
        return out
    }

    // ── Enable / disable (Sprint 26) ────────────────────────────────────────────
    // Persisted as a list of disabled bare ids in Persistence.Config. Disabled =
    // hidden from the builder palette. ponytail: already-placed instances of a
    // disabled module keep running until removed in Edit Layout — full unload
    // would need per-widget loader gating; add it if a plugin misbehaves badly
    // enough that "stop offering it" isn't enough.
    function isEnabled(id) {
        var dis = Persistence.Config.get("plugins.disabled", [])
        return dis.indexOf(_bare(id)) === -1
    }
    function setEnabled(id, on) {
        var dis = Persistence.Config.get("plugins.disabled", []).slice()
        var b = _bare(id)
        var i = dis.indexOf(b)
        if (on && i !== -1) dis.splice(i, 1)
        else if (!on && i === -1) dis.push(b)
        Persistence.Config.set("plugins.disabled", dis)
    }

    function rescan() { if (!_scan.running) _scan.running = true }

    // FileView-style directory watching isn't available; we rescan on demand
    // (edit-mode open calls rescan()) plus once at startup.
    property Process _scan: Process {
        running: false
        command: ["bash", "-c",
            "scan(){ [ -d \"$1\" ] || return; for d in \"$1\"/*/; do m=\"${d}module.json\"; " +
            "[ -f \"$m\" ] || continue; " +
            "jq -c --arg dir \"$d\" '{dir:$dir, id, name, author, version, canLiveIn, entry, icon, defaultSize, panel, configSchema, verified, description}' \"$m\" 2>/dev/null; " +
            "done; }; " +
            "scan \"$HOME/.config/quickshell/modules\"; " +
            "scan \"$HOME/.local/share/archeotech/modules\""
        ]

        property var _buf: []
        onRunningChanged: if (running) _buf = []

        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (!t) return
                try {
                    var m = JSON.parse(t)
                    if (m && m.id && m.entry) _scan._buf = _scan._buf.concat([m])
                } catch (e) {
                    console.warn("[ModuleRegistry] bad manifest line:", t)
                }
            }
        }
        onExited: {
            root.modules = _scan._buf
            root.ready = true
            console.log("[ModuleRegistry] discovered", root.modules.length, "module(s):",
                root.modules.map(function(m) { return m.id }).join(" "))
        }
    }

    Component.onCompleted: rescan()
}
