pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtCore
import "../../../../Commons" as Commons
import "../../../../Commons/Primitives" as Prim
import "../../../../Services/System" as SysSvc
import "../../../../Services/System/StorageLogic.js" as Logic
import "Storage"
import "Storage/Glyph.js" as G

// Storage panel (req_018 / task_085, item_182): free space on / and what can go.
//   Clean up  the cleanups the scan found, Safe first, then Review; tick, read
//             the exact commands, Free → confirm → run (admin ones under one
//             polkit prompt) → "Freed X", with the Trash and btrfs follow-ups.
//   Explore   the size map of the home folder (item_183).
// Data and the run: Services/System/Storage.qml over scripts/storage-scan.py.
// The scan is on demand: the first open scans, later opens show the cached
// result with its age and a Rescan button. Tab switches tabs; Esc steps back
// (confirm → list, search → cleared) and then closes.
Item {
    id: root
    anchors.fill: parent
    focus: true

    property var panelRoot

    readonly property var store: SysSvc.Storage
    readonly property string home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")

    property string tab: "clean"          // clean | explore
    property string stage: "list"         // list | confirm | run
    property string query: ""
    property var sel: ({})
    property var plan: []
    property string runNotice: ""         // why Run did nothing, shown on the confirm page
    property bool _selInit: false         // the default ticks were applied once
    property real _now: Date.now()

    readonly property var _shown: Logic.filter(store.entries, query)
    readonly property bool _hasData: store.scannedAt > 0

    Connections {
        target: root.store
        function onScanned() { root._applySelection() }
    }
    Component.onCompleted: {
        if (store.scannedAt > 0) _applySelection()
        _onOpen()
    }
    // The first scan ticks the defaults; a rescan keeps the user's ticks for the
    // rows that are still there.
    function _applySelection() {
        if (!_selInit) { sel = Logic.defaultSelection(store.entries); _selInit = true; return }
        var s = {}
        store.entries.forEach(e => { if (sel[e.id]) s[e.id] = true })
        sel = s
    }

    // Reset + focus on open (bound property: panelRoot is an untyped var, so a
    // Connections on its signal would never fire — see Launcher.qml).
    readonly property bool _panelOpen: root.panelRoot ? root.panelRoot.panelOpen : false
    on_PanelOpenChanged: if (_panelOpen) _onOpen()
    function _onOpen() {
        _now = Date.now()
        searchInput.text = ""
        query = ""
        // A run still going, or one that finished while the panel was closed, opens
        // on its page; the run continues if the panel closes.
        if (store.running || store.resultUnseen) { plan = store.runPlan; stage = "run" }
        else stage = "list"
        if (!store.scanning && !store.running && store.scannedAt === 0) store.rescan()
        _focus()
        Qt.callLater(_focus)
    }
    function _focus() { if (stage === "list" && tab === "clean") searchInput.forceActiveFocus(); else root.forceActiveFocus() }
    onStageChanged: Qt.callLater(_focus)
    onTabChanged: Qt.callLater(_focus)

    function toggle(id) {
        var s = Object.assign({}, sel)
        if (s[id]) delete s[id]; else s[id] = true
        sel = s
    }
    // The ticked rows that run something, admin ones first (the order they run in).
    function _selectedPlan() {
        var ids = Logic.runList(store.entries, sel).map(r => r.id)
        return ids.map(id => store.entries.find(e => e.id === id))
    }
    function confirm(rows) {
        if (!rows.length) return
        plan = rows
        runNotice = ""
        stage = "confirm"
    }
    function runPlan() {
        if (!store.run(plan.map(e => ({ id: e.id, commands: e.commands })), plan)) {
            runNotice = "A scan is still running: Run again once it ends."
            return
        }
        stage = "run"
    }
    // The result page is on screen: it no longer needs to reopen the panel on it.
    readonly property bool _resultShown: _panelOpen && stage === "run" && !store.running && store.resultUnseen
    on_ResultShownChanged: if (_resultShown) store.resultUnseen = false
    function back() {
        if (stage === "confirm") { stage = "list"; return }
        if (stage === "run" && !store.running) { stage = "list"; return }
        if (searchInput.text.length) { searchInput.text = ""; return }
        if (root.panelRoot) root.panelRoot.close()
    }

    Keys.onEscapePressed: root.back()
    Keys.onTabPressed: if (stage === "list") tab = tab === "clean" ? "explore" : "clean"
    Keys.onBacktabPressed: if (stage === "list") tab = tab === "clean" ? "explore" : "clean"

    Timer { interval: 30000; repeat: true; running: root._panelOpen; onTriggered: root._now = Date.now() }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Commons.Appearance.spacing.s6; anchors.rightMargin: Commons.Appearance.spacing.s6
        anchors.topMargin: Commons.Appearance.spacing.s5;  anchors.bottomMargin: Commons.Appearance.spacing.s5
        spacing: Commons.Appearance.spacing.s3

        // ── One row: the tab switch, then the search ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.stage === "list"
            spacing: Commons.Appearance.spacing.s3

            Rectangle {
                Layout.preferredWidth: tabRow.implicitWidth + Commons.Appearance.spacing.s1 * 2
                Layout.preferredHeight: 40
                radius: Commons.Appearance.radius.md
                color: Commons.Appearance.colors.surfaceCard
                border.width: 1
                border.color: Commons.Appearance.colors.glassBorder
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: Commons.Appearance.spacing.s1
                    Repeater {
                        model: [{ id: "clean", t: "Clean up" }, { id: "explore", t: "Explore" }]
                        delegate: Rectangle {
                            id: tabItem
                            required property var modelData
                            readonly property bool selected: root.tab === modelData.id
                            width: tabText.implicitWidth + Commons.Appearance.spacing.s8
                            height: 32
                            radius: Commons.Appearance.radius.sm
                            color: selected ? Commons.Appearance.colors.accentAlpha
                                 : tabHov.hovered ? Commons.Appearance.colors.surface0Alpha : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: Commons.Appearance.colors.accentBorder
                            Behavior on color { Commons.ColorAnim {} }
                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: tabItem.modelData.t
                                color: tabItem.selected ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textSecondary
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeMd
                                font.weight: tabItem.selected ? Commons.Appearance.font.weightSemibold : Commons.Appearance.font.weightRegular
                            }
                            HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.tab = tabItem.modelData.id }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Commons.Appearance.colors.surfaceCard
                border.color: searchInput.activeFocus ? Commons.Appearance.colors.accent
                                                      : Commons.Appearance.colors.glassBorder
                border.width: searchInput.activeFocus ? 2 : 1
                radius: Commons.Appearance.radius.md
                opacity: root.tab === "clean" ? 1 : 0.5
                Behavior on border.color { Commons.ColorAnim {} }

                Text {
                    id: searchGlyph
                    anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s3; verticalCenter: parent.verticalCenter }
                    text: G.search
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeXl }
                    color: searchInput.activeFocus ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textMuted
                }
                TextInput {
                    id: searchInput
                    anchors {
                        left: searchGlyph.right; leftMargin: Commons.Appearance.spacing.s3
                        right: notice.left; rightMargin: Commons.Appearance.spacing.s3
                        verticalCenter: parent.verticalCenter
                    }
                    enabled: root.tab === "clean"
                    color: Commons.Appearance.colors.textPrimary
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeMd }
                    selectByMouse: true
                    clip: true
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.back()
                    Keys.onTabPressed: root.tab = "explore"
                    Keys.onBacktabPressed: root.tab = "explore"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        visible: searchInput.text.length === 0
                        text: root.tab === "explore" ? "Search arrives with the size map"
                            : "Search " + root.store.entries.length + " cleanups…"
                        color: Commons.Appearance.colors.textMuted
                        font: searchInput.font
                    }
                }
                Text {
                    id: notice
                    anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s4; verticalCenter: parent.verticalCenter }
                    text: root.query ? root._shown.length + " found" : ""
                    color: Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
            }
        }

        // A scan that hit its time limit, or source files the helper skipped.
        Text {
            Layout.fillWidth: true
            visible: root.stage === "list" && root.tab === "clean" && root._hasData
                     && (root.store.partial || root.store.sourceErrors.length > 0 || root.store.error.length > 0)
            text: G.alert + "  " + (root.store.error ? "The last rescan failed: " + root.store.error
                  : root.store.partial ? "The scan ran out of time: some sizes are missing or too small. Rescan to finish it."
                  : "Skipped: " + root.store.sourceErrors.join("; "))
            color: Commons.Appearance.colors.warning
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            elide: Text.ElideRight
        }

        // ── The tab / stage ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            CleanupView {
                anchors.fill: parent
                visible: root.stage === "list" && root.tab === "clean" && root._hasData
                entries: root._shown
                sel: root.sel
                home: root.home
                query: root.query
                ageText: Logic.age(root.store.scannedAt, root._now)
                onToggle: id => root.toggle(id)
                onRescan: root.store.rescan()
                onFree: root.confirm(root._selectedPlan())
            }

            // First scan running, or it failed with nothing cached.
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.stage === "list" && root.tab === "clean" && !root._hasData
                spacing: Commons.Appearance.spacing.s3
                Prim.Spinner {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.store.scanning
                    running: visible
                    size: Commons.Appearance.font.size6xl
                }
                Prim.EmptyState {
                    Layout.preferredWidth: 520
                    icon: root.store.scanning ? "" : G.alert
                    title: root.store.scanning ? "Measuring caches and leftovers…" : root.store.error ? "The scan failed" : "Not scanned yet"
                    hint: root.store.scanning ? "Usually under a minute; big caches take longer"
                        : root.store.error || "Rescan measures what can be removed"
                }
                Prim.GlassButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.store.scanning
                    text: "Rescan"
                    onClicked: root.store.rescan()
                }
            }

            Prim.EmptyState {
                anchors.centerIn: parent
                width: 560
                visible: root.stage === "list" && root.tab === "explore"
                icon: G.disk
                title: "Explore"
                hint: "The size map of your home folder arrives in the next update"
            }

            RunView {
                anchors.fill: parent
                visible: root.stage !== "list"
                mode: root.stage === "confirm" ? "confirm" : root.store.running ? "running" : "result"
                plan: root.plan
                home: root.home
                notice: root.runNotice
                onBack: root.stage = "list"
                onRun: root.runPlan()
                onDone: root.stage = "list"
                onEmptyTrash: {
                    var t = root.store.entries.find(e => e.id === "trash")
                    if (t) root.confirm([t])
                }
                // Shown on the confirm page only; the helper's BALANCE command is what runs.
                onBalance: root.confirm([{ id: "@balance", label: "Rebalance btrfs data", root: true, bytes: null,
                                           commands: ["btrfs balance start -dusage=50 /"] }])
            }
        }
    }
}
