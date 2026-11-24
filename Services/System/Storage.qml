pragma Singleton
import QtQuick
import Quickshell.Io
import "../Persistence" as Persistence
import "StorageLogic.js" as Logic

// Disk space and cleanup sources (item_181, req_018). The work is done by
// scripts/storage-scan.py (read-only: statvfs, du, btrfs filesystem df); this
// singleton runs it, keeps the last result and its time (so a closed and
// reopened panel shows it straight away) and exposes it to QML.
//
// Startup reads free space only (--root, instant), again every 5 minutes for
// the bar widget's level (item_184). The poll stays on even with no widget:
// it is one statvfs plus, on btrfs, two `btrfs filesystem` reads, so gating it
// is not worth a consumer count. The full scan (entries + a size tree of $HOME, up to the
// helper's 25 s timeout) runs on rescan() only: the Storage panel calls it.
// Cleanup sources: the helper's shipped list plus
// ~/.config/archeotech/storage-sources.json (docs/STORAGE.md).
QtObject {
    id: root

    // ── Free space of / ───────────────────────────────────────────────────────
    property var    rootInfo: null        // helper's "root" object; null until the first read
    readonly property real size:         rootInfo ? rootInfo.size : 0
    readonly property real used:         rootInfo ? rootInfo.used : 0
    readonly property real free:         rootInfo ? rootInfo.free : 0
    readonly property int  freePct:      rootInfo ? rootInfo.free_pct : 0
    readonly property int  usedPct:      rootInfo ? rootInfo.used_pct : 0
    readonly property string fstype:     rootInfo ? rootInfo.fstype || "" : ""
    // btrfs only (-1 elsewhere): metadata free and device space not yet allocated.
    readonly property real metadataFree: rootInfo && rootInfo.btrfs_metadata_free != null ? rootInfo.btrfs_metadata_free : -1
    readonly property real unallocated:  rootInfo && rootInfo.btrfs_unallocated != null ? rootInfo.btrfs_unallocated : -1
    readonly property bool metadataTight: Logic.metadataTight(rootInfo)

    // Same thresholds and rules as dotfiles disk-alert.sh: "" | ok | warn | critical.
    readonly property int warnPct: Persistence.Config.get("storage.warnPct")
    readonly property int critPct: Persistence.Config.get("storage.critPct")
    readonly property string level: Logic.level(rootInfo, warnPct, critPct)

    // ── Full scan ─────────────────────────────────────────────────────────────
    property var    entries: []           // cleanup rows, safe first (see docs/STORAGE.md)
    property var    rejected: []          // sources refused by the personal-folder guard
    property var    tree: null            // { name, path, bytes, kind, tier?, children? }
    property var    sourceErrors: []      // bad source files / definitions
    property real   scannedAt: 0          // ms since epoch; 0 = never scanned
    property bool   partial: false        // the helper hit its timeout; sizes are lower bounds
    property string error: ""             // the last scan failed (helper missing, bad output)
    property string folderError: ""       // the last scanFolder() failed
    readonly property bool scanning: _scan.running
    readonly property var groups: Logic.groups(entries)

    signal scanned()
    // A scoped tree for one folder (Explore drill-down), already grafted into `tree`.
    signal folderScanned(string path)

    readonly property string _tool: decodeURIComponent(Qt.resolvedUrl("../../scripts/storage-scan.py").toString().replace("file://", ""))

    function rescan() {
        if (_scan.running) return
        root.error = ""
        _scan.running = true
    }
    function readRoot() { if (!_root.running) _root.running = true }

    // Deeper tree of one folder (item_183): a scoped walk of that folder only.
    // A call while one runs is queued; a newer call replaces the queued one.
    function scanFolder(path, depth) {
        if (!path) return
        if (_folder.running) { root._pendingFolder = { path: path, depth: depth }; return }
        root.folderError = ""
        _folder.path = path
        _folder.command = ["python3", root._tool, "--tree", path, "--depth", String(depth || 3)]
        _folder.running = true
    }
    property var _pendingFolder: null

    property var _root: Process {
        command: ["python3", root._tool, "--root"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var d = Logic.parse(this.text)
                if (d && d.root) root.rootInfo = d.root
            }
        }
    }
    property Timer _poll: Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.readRoot()
    }

    property var _scan: Process {
        command: ["python3", root._tool]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var d = Logic.parse(this.text)
                if (!d || !d.root) {
                    root.error = d && d.error ? d.error : "The storage scan returned nothing"
                    return
                }
                root.rootInfo = d.root
                root.entries = d.entries || []
                root.rejected = d.rejected || []
                root.tree = d.tree || null
                root.sourceErrors = d.errors || []
                root.partial = d.partial === true
                root.scannedAt = Date.now()
                root.scanned()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("storage-scan:", this.text.trim())
        }
    }

    property var _folder: Process {
        property string path: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var d = Logic.parse(this.text)
                if (!d || !d.tree) {
                    root.folderError = d && d.error ? d.error : "The folder scan returned nothing"
                    return
                }
                root.tree = Logic.graft(root.tree, root._folder.path, d.tree)
                root.folderScanned(root._folder.path)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("storage-scan --tree:", this.text.trim())
        }
        onExited: {
            var next = root._pendingFolder
            root._pendingFolder = null
            if (next) Qt.callLater(root.scanFolder, next.path, next.depth)
        }
    }
}
