pragma Singleton
import QtQuick
import Quickshell.Io

// Theme-pack discovery (adr_027 Layer A). Mirrors ModuleRegistry: scans a bundled
// dir + the user XDG dir for `pack.json` manifests. A pack overlays the base
// theme tokens — Commons/Appearance.qml applies the overlay from the pack's dir
// (resolved here via dirFor + pushed onto Appearance.activePackDir in shell.qml,
// since Commons can't import a Service). See docs/THEME_PACK.md.
//
//   <shell dir>/packs/                 — bundled packs (ship with the shell)
//   ~/.local/share/archeotech/packs/   — user-installed packs
//
// pack.json schema: { id, name, tier, minShellVersion, inherits? }
QtObject {
    id: root

    // Bundled packs dir, resolved relative to this file so it works under any
    // `qs -c <name>` location (mirrors ModuleRegistry._bundledDir).
    readonly property string _bundledDir: Qt.resolvedUrl("../../packs").toString().replace(/^file:\/\//, "")

    // Discovered packs: parsed manifests, each with an absolute `dir` (trailing
    // slash) injected by the scan.
    property var packs: []
    property bool ready: false

    function packFor(id) {
        for (var i = 0; i < packs.length; i++)
            if (packs[i].id === id) return packs[i]
        return null
    }

    // Absolute dir (trailing slash) of a pack, or "" for the base look / unknown id.
    function dirFor(id) {
        if (!id) return ""
        var p = packFor(id)
        return p ? p.dir : ""
    }

    // Component ids a pack ships a style delegate for (adr_027 Layer C): the
    // basenames of `<packDir>/styles/*.qml`. Empty for the base look / no styles.
    function stylesFor(id) {
        if (!id) return []
        var p = packFor(id)
        return (p && p.styles) ? p.styles : []
    }

    // Pack-scoped settings schema (adr_027 Layer D): a ConfigForm schema object
    // { "<dotted token path>": {type,label,...} } from pack.json, or {} if none.
    // Rendered in Settings → Appearance when the pack is active; values persist
    // under Config `packs.<id>` and override the matching pack token paths.
    function configSchemaFor(id) {
        var p = packFor(id)
        return (p && p.configSchema) ? p.configSchema : ({})
    }

    // pack.json minShellVersion, or "" if unset (treated as compatible).
    function minVersionFor(id) {
        var p = packFor(id)
        return (p && p.minShellVersion) ? p.minShellVersion : ""
    }

    // Dotted-numeric semver compare: is `a` >= `b`? ("0.3.0" >= "0.3" → true).
    function _verGte(a, b) {
        var pa = String(a).split("."), pb = String(b).split(".")
        var n = Math.max(pa.length, pb.length)
        for (var i = 0; i < n; i++) {
            var x = parseInt(pa[i] || "0", 10), y = parseInt(pb[i] || "0", 10)
            if (x > y) return true
            if (x < y) return false
        }
        return true
    }

    // Style-delegate ids for a pack, but ONLY if the shell satisfies the pack's
    // minShellVersion (adr_027 Layer C versioned contract). Incompatible pack ⇒
    // [] (its delegates are ignored, base visuals stand) + a warning.
    function stylesCompatible(id, shellVer) {
        var mv = minVersionFor(id)
        if (mv && !_verGte(shellVer, mv)) {
            console.warn("[PackRegistry] pack", id, "needs shell >=", mv,
                "but shell is", shellVer, "— style delegates disabled")
            return []
        }
        return stylesFor(id)
    }

    function rescan() { if (!_scan.running) _scan.running = true }

    property Process _scan: Process {
        running: false
        command: ["bash", "-c",
            "scan(){ [ -d \"$1\" ] || return; for d in \"$1\"/*/; do m=\"${d}pack.json\"; " +
            "[ -f \"$m\" ] || continue; " +
            "styles='[]'; " +
            "if [ -d \"${d}styles\" ]; then " +
            "styles=$(cd \"${d}styles\" && ls *.qml 2>/dev/null | sed 's/\\.qml$//' | jq -R . | jq -sc .); " +
            "[ -n \"$styles\" ] || styles='[]'; fi; " +
            "jq -c --arg dir \"$d\" --argjson styles \"$styles\" '{dir:$dir, id, name, tier, minShellVersion, inherits, styles:$styles, configSchema}' \"$m\" 2>/dev/null; " +
            "done; }; " +
            "scan \"" + root._bundledDir + "\"; " +
            "scan \"$HOME/.local/share/archeotech/packs\""
        ]

        property var _buf: []
        onRunningChanged: if (running) _buf = []

        stdout: SplitParser {
            onRead: line => {
                var t = line.trim()
                if (!t) return
                try {
                    var p = JSON.parse(t)
                    if (p && p.id) _scan._buf = _scan._buf.concat([p])
                } catch (e) {
                    console.warn("[PackRegistry] bad manifest line:", t)
                }
            }
        }
        onExited: {
            root.packs = _scan._buf
            root.ready = true
            console.log("[PackRegistry] discovered", root.packs.length, "pack(s):",
                root.packs.map(function(p) { return p.id }).join(" "))
        }
    }

    Component.onCompleted: rescan()
}
