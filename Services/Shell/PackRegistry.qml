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

    function rescan() { if (!_scan.running) _scan.running = true }

    property Process _scan: Process {
        running: false
        command: ["bash", "-c",
            "scan(){ [ -d \"$1\" ] || return; for d in \"$1\"/*/; do m=\"${d}pack.json\"; " +
            "[ -f \"$m\" ] || continue; " +
            "jq -c --arg dir \"$d\" '{dir:$dir, id, name, tier, minShellVersion, inherits}' \"$m\" 2>/dev/null; " +
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
