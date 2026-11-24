pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../../../Commons" as Commons
import "../../../../../Commons/Primitives" as Prim
import "../../../../../Services/System" as SysSvc
import "../../../../../Services/System/StorageLogic.js" as Logic
import "../../../../Dashboard/panels" as Dash
import "Glyph.js" as G

// The Explore tab (item_183, owner pick "ExploreB"): the size map of the home
// folder across the top, under it the folder's contents largest first and the
// hovered box's card. A click on a folder (box, strip, list row, breadcrumb)
// opens it; Esc (the panel's back()) goes up. The full scan holds three levels
// of the tree; a folder whose map would show empty boxes gets a scoped helper
// scan of its own (once per folder per scan), grafted into the tree.
// Read-only: the card's buttons open the folder in the file manager or point
// at its Clean up row; nothing here removes anything.
ColumnLayout {
    id: view
    property string home: ""
    property string query: ""            // the panel's search: folders and files by name
    property string ageText: ""
    property string path: ""             // the folder shown; "" = the top of the tree
    // The box or row last pointed at; it stays when the pointer leaves for the
    // card, so the card's buttons act on what the card shows. Cleared when the
    // folder changes. Up / Down in the search move it, Enter opens it.
    property var hovered: null
    signal rescan()
    signal showInCleanup(string query)
    signal clearQuery()                  // a search result was opened: the list goes back to the folder

    // Sizes that have no Appearance token, named once.
    readonly property int _rowH: 38
    readonly property int _rowIndent: Commons.Appearance.spacing.s8
    readonly property int _barH: 5
    readonly property int _sizeColW: 64

    readonly property var store: SysSvc.Storage
    readonly property var tree: store.tree
    readonly property string base: tree ? tree.path : ""
    readonly property var node: _resolve(tree, path)
    readonly property var results: Logic.search(tree, query, 50)
    readonly property var _target: hovered || node
    readonly property var _rows: query ? results : (node && node.children ? node.children : [])
    readonly property real _rowsTotal: query ? (tree ? tree.bytes : 0) : (node ? node.bytes : 0)
    readonly property bool _measuring: store.folderScanning && !!node && store.folderPath === node.path
    // A scoped scan is due for this folder but not started (callLater) or queued.
    readonly property bool _pending: !!node && Logic.needsScan(node) && !_asked[node.path]
    readonly property string _folderError: node && store.folderPath === node.path ? store.folderError : ""

    spacing: Commons.Appearance.spacing.s3

    // The folder at `p`, or the closest one above it the tree holds.
    function _resolve(t, p) {
        if (!t) return null
        var q = p || t.path
        while (q && q !== "/") {
            var n = Logic.findNode(t, q)
            if (n) return n
            q = Logic.parentPath(q)
        }
        return t
    }
    function openNode(n) {
        if (!n || (n.kind !== "dir" && n.kind !== "file")) return
        view.path = n.kind === "dir" ? n.path : Logic.parentPath(n.path)
        if (view.query) view.clearQuery()
    }
    // Keyboard (from the panel's search field): move through the list, open.
    function move(d) {
        var rs = view._rows
        if (!rs.length) return
        var i = -1
        for (var k = 0; k < rs.length; k++) if (map._same(rs[k], view.hovered)) { i = k; break }
        i = i < 0 ? (d > 0 ? 0 : rs.length - 1) : Math.max(0, Math.min(rs.length - 1, i + d))
        view.hovered = rs[i]
        rows.positionViewAtIndex(i, ListView.Contain)
    }
    function activate() { if (view.hovered) view.openNode(view.hovered) }
    // Back to the top of the tree (the panel calls it on open).
    function reset() { view.path = ""; view.hovered = null }
    // One level up; false at the top (the panel then closes).
    function up() {
        if (!node || !tree || node.path === tree.path) return false
        view.path = Logic.parentPath(node.path)
        return true
    }

    // ── Lazy scoped scans ──────────────────────────────────────────────────
    // Only while Explore is on screen. A folder counts as done when its scan
    // comes back (or fails), not when it is asked for: Storage keeps one queued
    // request and a newer one replaces it, so a folder skipped past while
    // another scan ran is asked again when it is shown again.
    property var _asked: ({})            // path -> true: scanned (or failed) since the last full scan
    property string _nodePath: ""
    onNodeChanged: {
        var p = node ? node.path : ""
        if (p !== _nodePath) { _nodePath = p; view.hovered = null }   // a graft keeps the same folder
        Qt.callLater(view._ensure)
    }
    onVisibleChanged: if (visible) Qt.callLater(view._ensure)
    function _ensure() {
        var n = view.node
        if (!view.visible || view.store.scanning || !n || !Logic.needsScan(n) || view._asked[n.path]) return
        if (view.store.folderScanning && view.store.folderPath === n.path) return
        view.store.scanFolder(n.path, 3)
    }
    function _done(p) { var a = Object.assign({}, view._asked); a[p] = true; view._asked = a }
    Connections {
        target: view.store
        function onScanned() { view._asked = ({}); Qt.callLater(view._ensure) }
        function onFolderScanned(p) { view._done(p) }
        function onFolderErrorChanged() { if (view.store.folderError) view._done(view.store.folderPath) }
    }

    // ── What a node is, for the card ───────────────────────────────────────
    function _tildeOf(p) { return p === view.home ? "~" : Logic.tilde(p, view.home) }
    function label(n) {
        if (!n) return ""
        return n.kind === "more" || n.kind === "files" ? _tildeOf(n.path) + "  ›  " + n.name : _tildeOf(n.path)
    }
    function pct(n) {
        if (!n || !tree || !(tree.bytes > 0)) return ""
        var p = 100 * n.bytes / tree.bytes
        return (p < 1 ? "< 1" : p.toFixed(0)) + " % of ~"
    }
    readonly property var _source: _target && _target.tier ? Logic.sourceFor(store.entries, _target.path) : null
    readonly property var _inside: _target && _target.kind === "dir" && !_target.tier ? Logic.inside(store.entries, _target.path) : []
    function describe(n) {
        if (!n) return ""
        if (n.kind === "more") return "Folders too small to draw on their own. Open the folder in Files to see them."
        if (n.kind === "files") return "The loose files of this folder, counted together."
        if (n.tier === "personal") return "Your files. Clean up never offers them; only you decide what goes."
        if (n.tier === "safe")
            return view._source ? "Listed in Clean up as safe to remove: " + view._source.label + "."
                                : "Cache or leftover data that Clean up can remove."
        if (n.tier === "review")
            return view._source ? "Listed in Clean up under Review: " + view._source.label + "."
                                : "Listed in Clean up under Review."
        if (view._inside.length) {
            var b = Logic.sumBytes(view._inside)
            return "Holds " + view._inside.length + (view._inside.length === 1 ? " cleanup" : " cleanups")
                   + (b > 0 ? " (" + Logic.formatBytes(b) + ")" : "") + " listed in Clean up."
        }
        return n.kind === "file" ? "A file. Clean up does not list it." : "Apps, settings and data that Clean up does not list."
    }
    function _openInFiles(n) {
        if (!n) return
        Quickshell.execDetached(["xdg-open", n.kind === "file" ? Logic.parentPath(n.path) : n.path])
    }

    // ── Breadcrumb and legend ──────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Appearance.spacing.s7
        spacing: Commons.Appearance.spacing.s2

        Text {
            text: G.home
            color: Commons.Appearance.colors.overlay2
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeLg
        }
        Repeater {
            model: view.node && view.tree ? Logic.crumbs(view.node.path, view.tree.path, "~") : []
            delegate: Row {
                id: crumb
                required property var modelData
                required property int index
                readonly property bool last: view.node && modelData.path === view.node.path
                spacing: Commons.Appearance.spacing.s2
                Text {
                    visible: crumb.index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Commons.Appearance.colors.overlay0
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeMd
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: crumb.modelData.name
                    color: crumb.last ? Commons.Appearance.colors.textPrimary
                         : crumbHov.hovered ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay2
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeMd
                    font.weight: crumb.last ? Commons.Appearance.font.weightSemibold : Commons.Appearance.font.weightRegular
                    HoverHandler { id: crumbHov; enabled: !crumb.last; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: !crumb.last; onTapped: view.path = crumb.modelData.path }
                }
            }
        }
        Text {
            leftPadding: Commons.Appearance.spacing.s2
            text: view.node ? Logic.formatBytes(view.node.bytes) : ""
            color: Commons.Appearance.colors.overlay1
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeMd
        }
        Item { Layout.fillWidth: true }
        Repeater {
            model: [{ t: "safe to clean", tier: "safe" }, { t: "review", tier: "review" },
                    { t: "yours", tier: "personal" }, { t: "other", tier: "" }]
            delegate: Row {
                id: key
                required property var modelData
                spacing: Commons.Appearance.spacing.s2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Commons.Appearance.font.sizeMd; height: width
                    radius: Commons.Appearance.radius.xs
                    color: map.fill(key.modelData.tier, "dir")
                }
                Text {
                    rightPadding: Commons.Appearance.spacing.s3
                    text: key.modelData.t
                    color: Commons.Appearance.colors.subtext0
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeBase
                }
            }
        }
    }

    // ── The map ────────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Commons.Appearance.spacing.s12 * 5
        radius: Commons.Appearance.radius.md
        color: Commons.Appearance.colors.crust
        border.width: 1
        border.color: Commons.Appearance.colors.borderSubtle

        Treemap {
            id: map
            anchors.fill: parent
            anchors.margins: Commons.Appearance.spacing.s1
            node: view.node
            hovered: view.hovered
            onHover: n => { if (n) view.hovered = n }
            onOpen: n => view.openNode(n)
        }
        // A folder with nothing measured below it yet, or nothing in it.
        ColumnLayout {
            anchors.centerIn: parent
            visible: !view.node || !(view.node.children || []).some(c => c.bytes > 0)
            readonly property bool busy: view._measuring || (view._pending && !view._folderError)
            spacing: Commons.Appearance.spacing.s3
            Prim.Spinner {
                Layout.alignment: Qt.AlignHCenter
                visible: parent.busy
                running: visible
                size: Commons.Appearance.font.size6xl
            }
            Prim.EmptyState {
                Layout.preferredWidth: Commons.Appearance.spacing.s12 * 10
                icon: parent.busy ? "" : G.dir
                title: parent.busy ? "Measuring " + view.label(view.node) + "…"
                     : !view.node ? "No size map yet" : "Nothing measured in this folder"
                hint: parent.busy ? "A scan of this folder only" : !view.node ? "Rescan measures your home folder"
                    : view._folderError || "It holds no files, or none the scan could read"
            }
        }
    }

    // ── Largest first, and the hovered box ─────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Commons.Appearance.spacing.s12 * 5 + Commons.Appearance.spacing.s2
        Layout.fillHeight: false      // its cards fill it; the map takes the rest
        spacing: Commons.Appearance.spacing.s4

        Dash.DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: view.query ? view.results.length + (view.results.length === 1 ? " match" : " matches") + " for “" + view.query + "”"
                              : "Largest first"

            ListView {
                id: rows
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: view._rows
                ScrollBar.vertical: ScrollBar { id: rowsBar; policy: ScrollBar.AsNeeded }
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool hot: map._same(view.hovered, n)
                    readonly property real share: view._rowsTotal > 0 ? n.bytes / view._rowsTotal : 0
                    width: rows.width - (rowsBar.visible ? rowsBar.width : 0)
                    height: view._rowH

                    Rectangle {
                        anchors.fill: parent
                        radius: Commons.Appearance.radius.sm
                        color: Commons.Appearance.colors.surface0Alpha
                        visible: row.hot
                    }
                    Text {
                        id: rowIcon
                        x: Commons.Appearance.spacing.s2; y: Commons.Appearance.spacing.s1
                        text: row.n.kind === "file" || row.n.kind === "files" ? G.file : G.dir
                        color: map.fill(row.n.tier || "", row.n.kind)
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeLg
                    }
                    Text {
                        x: view._rowIndent; y: Commons.Appearance.spacing.s1 - 1
                        width: parent.width - x - sizeCol.width - Commons.Appearance.spacing.s3
                        text: view.query ? view._tildeOf(row.n.path) : row.n.name
                        elide: view.query ? Text.ElideMiddle : Text.ElideRight
                        color: Commons.Appearance.colors.textPrimary
                        font.family: Commons.Appearance.font.mono
                        font.pixelSize: Commons.Appearance.font.sizeMd
                    }
                    Row {
                        id: sizeCol
                        anchors.right: parent.right; anchors.rightMargin: Commons.Appearance.spacing.s2
                        y: Commons.Appearance.spacing.s1 - 1
                        spacing: Commons.Appearance.spacing.s3
                        Text {
                            text: row.share >= 0.01 ? (100 * row.share).toFixed(0) + " %" : "< 1 %"
                            color: Commons.Appearance.colors.overlay1
                            font.family: Commons.Appearance.font.mono
                            font.pixelSize: Commons.Appearance.font.sizeBase
                        }
                        Text {
                            width: view._sizeColW
                            horizontalAlignment: Text.AlignRight
                            text: Logic.formatBytes(row.n.bytes)
                            color: Commons.Appearance.colors.subtext1
                            font.family: Commons.Appearance.font.mono
                            font.pixelSize: Commons.Appearance.font.sizeMd
                        }
                    }
                    Rectangle {
                        x: view._rowIndent; y: parent.height - Commons.Appearance.spacing.s3
                        width: parent.width - x - Commons.Appearance.spacing.s2
                        height: view._barH
                        radius: height / 2
                        color: Commons.Appearance.colors.recessedTrack
                        Rectangle {
                            width: Math.max(height, parent.width * Math.min(1, row.share))
                            height: parent.height
                            radius: height / 2
                            color: map.fill(row.n.tier || "", row.n.kind === "dir" ? "dir" : "")
                        }
                    }
                    HoverHandler {
                        cursorShape: row.n.kind === "dir" || row.n.kind === "file" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onHoveredChanged: if (hovered) view.hovered = row.n
                    }
                    TapHandler { onTapped: view.openNode(row.n) }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: view._rows.length === 0
                text: view.query ? "No folder or file in the scanned tree matches. Esc clears the search." : ""
                color: Commons.Appearance.colors.textMuted
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                wrapMode: Text.WordWrap
            }
        }

        Dash.DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: view.label(view._target)

            Text {
                text: view._target ? Logic.formatBytes(view._target.bytes) + "  ·  " + view.pct(view._target) : ""
                color: Commons.Appearance.colors.textPrimary
                font.family: Commons.Appearance.font.mono
                font.pixelSize: Commons.Appearance.font.size3xl
                font.weight: Commons.Appearance.font.weightSemibold
            }
            Text {
                Layout.fillWidth: true
                text: view.describe(view._target)
                color: Commons.Appearance.colors.subtext0
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                spacing: Commons.Appearance.spacing.s3
                Prim.GlassButton {
                    text: "Open in Files"
                    enabled: !!view._target
                    onClicked: view._openInFiles(view._target)
                }
                Prim.GlassButton {
                    visible: !!view._source || view._inside.length > 0
                    text: "Show in Clean up"
                    onClicked: {
                        var t = view._target
                        view.showInCleanup(view._source ? view._source.label
                                                        : t.path.indexOf(view.home + "/") === 0 ? t.path.slice(view.home.length + 1) : t.path)
                    }
                }
            }
        }
    }

    // ── Footer ─────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Commons.Appearance.spacing.s3
        Prim.Spinner {
            visible: view.store.folderScanning
            running: visible
            size: Commons.Appearance.font.sizeBase
        }
        Text {
            Layout.fillWidth: true
            text: view.store.scanning ? "Scanning…"
                : view.store.folderScanning ? "Measuring " + view._tildeOf(view.store.folderPath) + "…"
                : view._folderError ? G.alert + "  " + view._folderError
                : (view.ageText ? "Scanned " + view.ageText + "  ·  " : "") + "click a box or ↑↓ Enter to open it, Esc goes up"
            color: view._folderError && !view.store.folderScanning ? Commons.Appearance.colors.warning
                                                                         : Commons.Appearance.colors.overlay1
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeSm
            elide: Text.ElideRight
        }
        Prim.GlassButton {
            text: "Rescan"
            enabled: !view.store.scanning && !view.store.running
            onClicked: view.rescan()
        }
    }
}
