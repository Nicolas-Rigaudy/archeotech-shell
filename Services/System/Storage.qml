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
    readonly property bool folderScanning: _folder.running
    readonly property string folderPath: _folder.path     // the folder being (or last) measured
    readonly property var groups: Logic.groups(entries)

    // ── Run (item_182) ────────────────────────────────────────────────────────
    // run([{id, commands}]): the commands the confirm page showed. The helper
    // plans them again and runs only what its fresh plan still produces (admin
    // ones behind one pkexec prompt), then a rescan refreshes the list.
    readonly property bool running: _run.running
    property var  runStatus: ({})         // id -> "queued" | "running" | "done" | "failed"
    property var  runErrors: ({})         // id -> error text of a failed entry
    property var  lastResult: null        // helper's result line: { ok, freed, failed, before, after }
    property var  runPlan: []             // the rows of the last run(), as the panel shows them
    property bool resultUnseen: false     // a run finished and no panel has shown its result yet

    signal scanned()
    signal ran(var result)
    // A scoped tree for one folder (Explore drill-down), already grafted into `tree`.
    signal folderScanned(string path)

    readonly property string _tool: decodeURIComponent(Qt.resolvedUrl("../../scripts/storage-scan.py").toString().replace("file://", ""))

    // A rescan asked for while one runs (the one after a cleanup) runs once it ends.
    property bool _rescanPending: false
    function rescan() {
        if (_scan.running) { root._rescanPending = true; return }
        root.error = ""
        _scan.running = true
    }
    // list: [{id, commands}] for the helper; plan: the same rows with their labels
    // and sizes, kept so a panel reopened mid-run can show it. Returns false when
    // it cannot start (a scan or another run is in progress): nothing ran.
    function run(list, plan) {
        if (_run.running || _scan.running || !list || !list.length) return false
        root.runPlan = plan || list
        var st = {}
        for (var i = 0; i < list.length; i++) st[list[i].id] = "queued"
        root.runStatus = st
        root.runErrors = ({})
        root.lastResult = null
        _run.command = ["python3", root._tool, "--run", JSON.stringify({ entries: list })]
        _run.running = true
        return true
    }
    function _setStatus(id, state, err) {
        var st = Object.assign({}, root.runStatus); st[id] = state; root.runStatus = st
        if (err) { var e = Object.assign({}, root.runErrors); e[id] = err; root.runErrors = e }
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
        onExited: {
            if (!root._rescanPending) return
            root._rescanPending = false
            Qt.callLater(root.rescan)
        }
    }

    property var _run: Process {
        running: false
        stdout: SplitParser {
            onRead: line => {
                var ev = Logic.parseEvent(line)
                if (!ev) return
                if (ev.event === "start") root._setStatus(ev.id, "running")
                else if (ev.event === "done") root._setStatus(ev.id, ev.ok ? "done" : "failed", ev.error || "")
                else if (ev.event === "result") {
                    root.lastResult = ev
                    if (ev.after) root.rootInfo = ev.after
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("storage-scan --run:", this.text.trim())
        }
        onExited: (code, status) => {
            if (!root.lastResult)
                root.lastResult = { ok: false, freed: 0, failed: -1, error: "The cleanup helper stopped (exit " + code + ")" }
            root.resultUnseen = true
            root.ran(root.lastResult)
            Qt.callLater(root.rescan)
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
