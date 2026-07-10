import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../../Services/Persistence" as Persistence

// Launcher UI. Panel.qml provides chrome + slide anim + click-outside-to-close;
// this file is the inner content only. `panelRoot` is injected by Panel.qml's
// Loader.onLoaded — call `panelRoot.close()` to dismiss. Reset on open is
// wired via the Connections on panelRoot below.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    // ── State ──────────────────────────────────────────────────────────────────
    property var    allApps:      []
    property var    filtered:     []
    property string query:        ""
    property int    selectedIdx:  0
    property var    _depIds:      ({})
    property var    _usageCounts: ({})

    // Pinned apps come first in the Recents row, in user-chosen order;
    // frecency from launches-via-launcher fills any remaining slots up to 4.
    // Pinned list lives in Persistence.Config (writeable from this UI via
    // the pin/unpin buttons on each list row). Matched against entry.id
    // first, then entry.name (case-insensitive).
    readonly property var _pinnedDefaults: ["kitty", "zen", "code", "obsidian"]
    readonly property var pinnedIds:
        Persistence.Config.get("launcher.pinned", root._pinnedDefaults)

    property var topRecents: []

    function _findApp(needle) {
        var n = (needle || "").toLowerCase()
        for (var i = 0; i < allApps.length; i++) {
            var a = allApps[i]
            if ((a.id   || "").toLowerCase() === n) return a
            if ((a.name || "").toLowerCase() === n) return a
        }
        return null
    }

    function isPinned(entry) {
        if (!entry) return false
        var ids = root.pinnedIds || []
        for (var i = 0; i < ids.length; i++) {
            var n = (ids[i] || "").toLowerCase()
            if ((entry.id   || "").toLowerCase() === n) return true
            if ((entry.name || "").toLowerCase() === n) return true
        }
        return false
    }

    function togglePin(entry) {
        if (!entry || !entry.id) return
        var pins = (root.pinnedIds || []).slice()
        // Remove any matching variant (id or name) — keeps the list clean.
        var key = entry.id.toLowerCase()
        var nameKey = (entry.name || "").toLowerCase()
        var removed = false
        for (var i = pins.length - 1; i >= 0; i--) {
            var p = (pins[i] || "").toLowerCase()
            if (p === key || p === nameKey) { pins.splice(i, 1); removed = true }
        }
        if (!removed) pins.push(entry.id)
        Persistence.Config.set("launcher.pinned", pins)
        root._refreshRecents()
    }

    function _refreshRecents() {
        var seen = {}
        var out  = []
        var pinned = root.pinnedIds || []
        for (var i = 0; i < pinned.length && out.length < 4; i++) {
            var a = _findApp(pinned[i])
            if (a && !seen[a.id]) { out.push(a); seen[a.id] = true }
        }
        if (out.length < 4) {
            var rest = allApps.slice().filter(function(a) {
                return !seen[a.id] && (root._usageCounts[a.name] || 0) > 0
            })
            rest.sort(function(a, b) {
                return (root._usageCounts[b.name] || 0) - (root._usageCounts[a.name] || 0)
            })
            for (var j = 0; j < rest.length && out.length < 4; j++) out.push(rest[j])
        }
        root.topRecents = out
    }
    onPinnedIdsChanged: _refreshRecents()

    // usage → dep → _loadApps chain on startup
    Component.onCompleted: usageReader.running = true

    // re-index when new apps are installed
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root._loadApps() }
    }

    // ── Load apps from native API ──────────────────────────────────────────────
    function _loadApps() {
        var model = DesktopEntries.applications
        var entries = model.values || []
        if (!entries.length && model.count) {
            entries = []
            for (var i = 0; i < model.count; i++) entries.push(model.get(i))
        }
        var buf = []
        for (var j = 0; j < entries.length; j++) {
            if (!root._depIds[entries[j].id]) buf.push(entries[j])
        }
        root.allApps = buf
        root._filter()
        root._refreshRecents()
    }

    // ── Usage reader ───────────────────────────────────────────────────────────
    property var usageReader: Process {
        command: ["bash", "-c", "cat \"$HOME/.cache/qs-launcher-usage\" 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("\t")
                if (p.length >= 2 && p[0].trim())
                    root._usageCounts[p[0]] = parseInt(p[1]) || 0
            }
        }
        onExited: (code, status) => { depReader.running = true }
    }

    // ── Dep-ID reader ──────────────────────────────────────────────────────────
    property var depReader: Process {
        command: ["bash", "-c",
            "pacman -Qdq | xargs -r pacman -Ql 2>/dev/null | " +
            "awk '/\\.desktop$/{gsub(\".*/\",\"\"); gsub(\"\\.desktop$\",\"\"); print}'"]
        running: false
        stdout: SplitParser {
            onRead: data => { var id = data.trim(); if (id) root._depIds[id] = true }
        }
        onExited: (code, status) => { root._loadApps() }
    }

    // ── Usage writer ───────────────────────────────────────────────────────────
    property var usageWriter: Process { running: false }

    function _bumpUsage(name) {
        root._usageCounts[name] = (root._usageCounts[name] || 0) + 1
        root._refreshRecents()
        if (usageWriter.running) return
        var lines = []
        for (var k in root._usageCounts) {
            lines.push("printf '%s\\t%s\\n' '" + k.replace(/'/g, "'\\''") + "' " + root._usageCounts[k])
        }
        usageWriter.command = ["bash", "-c",
            "{ " + lines.join("; ") + "; } > \"$HOME/.cache/qs-launcher-usage\""]
        usageWriter.running = true
    }

    // ── Fuzzy scorer ───────────────────────────────────────────────────────────
    function _fuzzyScore(str, q) {
        if (!str || !q) return 0
        str = str.toLowerCase()
        q   = q.toLowerCase()
        if (str === q)             return 1.0
        if (str.startsWith(q))     return 0.9
        if (str.indexOf(q) !== -1) return 0.7
        var si = 0, qi = 0, score = 0, consec = 0, prev = -1
        while (si < str.length && qi < q.length) {
            if (str[si] === q[qi]) {
                consec = (prev === si - 1) ? consec + 1 : 0
                score += 1.0 + consec * 0.3
                if (si === 0 || " -_".indexOf(str[si - 1]) !== -1) score += 0.8
                prev = si
                qi++
            }
            si++
        }
        if (qi < q.length) return 0
        return score / (q.length * 2.5)
    }

    function _appScore(entry, q) {
        var s = _fuzzyScore(entry.name        || "", q) * 0.70
              + _fuzzyScore(entry.genericName  || "", q) * 0.15
              + _fuzzyScore(entry.comment      || "", q) * 0.05
        var kws = entry.keywords
        if (kws) {
            if (typeof kws === "string") kws = kws.split(";").filter(Boolean)
            var kmax = 0
            for (var i = 0; i < kws.length; i++) {
                var ks = _fuzzyScore(kws[i], q) * 0.10
                if (ks > kmax) kmax = ks
            }
            s += kmax
        }
        return s
    }

    // ── Filter + sort ──────────────────────────────────────────────────────────
    function _filter() {
        var apps = allApps.slice()
        var result
        if (query.length === 0) {
            apps.sort(function(a, b) {
                var ca = root._usageCounts[a.name] || 0
                var cb = root._usageCounts[b.name] || 0
                if (cb !== ca) return cb - ca
                return (a.name || "") < (b.name || "") ? -1 : 1
            })
            result = apps
        } else {
            var q = query
            var scored = []
            for (var i = 0; i < apps.length; i++) {
                var sc = root._appScore(apps[i], q)
                if (sc > 0) scored.push({ entry: apps[i], score: sc })
            }
            scored.sort(function(a, b) { return b.score - a.score })
            result = scored.map(function(x) { return x.entry })
        }
        filtered    = result
        selectedIdx = 0
    }
    onQueryChanged: _filter()

    // ── Launch ─────────────────────────────────────────────────────────────────
    // Use Quickshell.execDetached, NOT a child Process: closing the panel
    // unloads this item, and a child Process would be torn down (killing the
    // app) before it finishes spawning. execDetached double-forks so the app
    // reparents to init and survives. (Regression surfaced on QS 0.3.0, which
    // tightened Process child cleanup.)
    function _launch(entry) {
        if (!entry) return
        root._bumpUsage(entry.name || "")
        // Prefer parsed command array; fall back to execString
        var cmd = []
        if (entry.command && entry.command.length > 0) {
            for (var i = 0; i < entry.command.length; i++) cmd.push(entry.command[i])
        } else {
            var raw = (entry.execString || "").replace(/ *%[uUfFdDnNickvm]/g, "").trim()
            if (!raw) return
            cmd = ["bash", "-c", raw]
        }
        if (entry.runInTerminal) cmd = ["kitty", "-e"].concat(cmd)
        Quickshell.execDetached(cmd)
        if (root.panelRoot) root.panelRoot.close()
    }

    // ── Reset on open — focus the search + clear query when the panel opens
    Connections {
        target: root.panelRoot
        enabled: root.panelRoot !== null
        function onPanelOpenChanged() {
            if (!root.panelRoot || !root.panelRoot.panelOpen) return
            root.query = ""
            searchInput.text = ""
            root._filter()
            root._refreshRecents()
            searchInput.forceActiveFocus()
        }
    }

    // ── Content container — fills Panel's Loader bounds. Panel.qml owns
    //    chrome (color/border/radius) + slide-from-edge animation; this Item
    //    just hosts the search + list column.
    Item {
        id: panel
        anchors.fill: parent

        Column {
            id: col
            anchors {
                top:   parent.top;   topMargin:   Commons.Appearance.spacing.lg
                left:  parent.left;  leftMargin:  Commons.Appearance.spacing.lg
                right: parent.right; rightMargin: Commons.Appearance.spacing.lg
            }
            spacing: Commons.Appearance.spacing.sm

            // ── Recents row (most-used, frecency-sorted) ───────────────────────
            // Hidden when typing; tap launches without losing the search field.
            Item {
                id: recentsRow
                width:   parent.width
                visible: root.query.length === 0 && root.topRecents.length > 0
                height:  visible ? (recentsLbl.height + tilesRow.height + 4) : 0

                Text {
                    id: recentsLbl
                    text:  "RECENTS"
                    color: Commons.Appearance.colors.subtext0
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeSm; letterSpacing: 1.5 }
                    opacity: 0.7
                    anchors { top: parent.top; left: parent.left }
                }

                Row {
                    id: tilesRow
                    spacing: Commons.Appearance.spacing.base
                    anchors { left: parent.left; right: parent.right; top: recentsLbl.bottom; topMargin: 4 }

                    Repeater {
                        model: root.topRecents
                        delegate: Rectangle {
                            required property var modelData
                            // 4 tiles, share the row evenly minus spacing.
                            width:  (tilesRow.width - Commons.Appearance.spacing.base * (root.topRecents.length - 1)) / Math.max(1, root.topRecents.length)
                            height: 64
                            radius: Commons.Appearance.radius.base
                            color:  tileHov.hovered ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0Alpha
                            border.color: tileHov.hovered ? Commons.Appearance.colors.accentBorder : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                            Item {
                                id: tileIconWrapper
                                anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                                width: 26; height: 26
                                property int _idx: 0
                                property var _cands: {
                                    var n = modelData.icon || "", id = modelData.id || "", c = []
                                    if (n) {
                                        c.push(n.startsWith("/") ? n : "image://icon/" + n)
                                        if (n !== n.toLowerCase()) c.push("image://icon/" + n.toLowerCase())
                                    }
                                    if (id && id !== n && id !== n.toLowerCase())
                                        c.push("image://icon/" + id)
                                    return c
                                }
                                Image {
                                    id: tileIcon
                                    anchors.fill: parent
                                    source: tileIconWrapper._cands[tileIconWrapper._idx] || ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    onStatusChanged: {
                                        if (status === Image.Error
                                                && tileIconWrapper._idx < tileIconWrapper._cands.length - 1)
                                            tileIconWrapper._idx++
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: tileIcon.status !== Image.Ready
                                    text: ""
                                    font { family: Commons.Appearance.font.family; pixelSize: 16 }
                                    color: Commons.Appearance.colors.overlay1
                                }
                            }

                            Text {
                                anchors { bottom: parent.bottom; bottomMargin: 6; left: parent.left; right: parent.right }
                                text:  modelData.name || ""
                                color: Commons.Appearance.colors.subtext1
                                font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeSm }
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            // Unpin overlay — top-right corner, fades in on
                            // tile hover. Pinned-tile-only since recents
                            // entries are either pinned or frecency-only;
                            // frecency entries can be re-pinned from the list.
                            Rectangle {
                                id: tileUnpin
                                readonly property bool _pinned: root.isPinned(modelData)
                                visible: _pinned
                                anchors { top: parent.top; right: parent.right; margins: 4 }
                                width: 20; height: 20
                                radius: Commons.Appearance.radius.sm
                                color:   _tileUnpinArea.containsMouse ? Commons.Appearance.colors.surface0 : "transparent"
                                opacity: tileHov.hovered || _tileUnpinArea.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                                Behavior on color   { ColorAnimation  { duration: Commons.Appearance.anim.fast } }

                                Text {
                                    anchors.centerIn: parent
                                    text:  "󰐃"
                                    color: Commons.Appearance.colors.accent
                                    font { family: Commons.Appearance.font.family; pixelSize: 12 }
                                }

                                MouseArea {
                                    id: _tileUnpinArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePin(modelData)
                                }
                            }

                            HoverHandler { id: tileHov }
                            TapHandler   { onTapped: root._launch(modelData) }
                        }
                    }
                }
            }

            // ── Search box ─────────────────────────────────────────────────────
            Rectangle {
                width:        parent.width
                height:       38
                color:        Commons.Appearance.colors.surface0Alpha
                border.color: Commons.Appearance.colors.accentBorder
                border.width: 1
                radius:       Commons.Appearance.radius.base

                Text {
                    id: searchGlyph
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text:  ""
                    font { family: Commons.Appearance.font.family; pixelSize: 14 }
                    color: Commons.Appearance.colors.overlay1
                }
                TextInput {
                    id: searchInput
                    anchors {
                        left: searchGlyph.right; leftMargin: 6
                        right: parent.right;     rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    color:         Commons.Appearance.colors.text
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeBase }
                    selectByMouse: true
                    onTextChanged: root.query = text
                    Keys.onUpPressed: {
                        if (root.selectedIdx > 0) root.selectedIdx--
                        resultList.positionViewAtIndex(root.selectedIdx, ListView.Contain)
                    }
                    Keys.onDownPressed: {
                        if (root.selectedIdx < root.filtered.length - 1) root.selectedIdx++
                        resultList.positionViewAtIndex(root.selectedIdx, ListView.Contain)
                    }
                    Keys.onReturnPressed: root._launch(root.filtered[root.selectedIdx])
                    Keys.onEscapePressed: if (root.panelRoot) root.panelRoot.close()
                }
            }

            // ── Result list ────────────────────────────────────────────────────
            ListView {
                id:             resultList
                width:          parent.width
                // Shrink the cap when recents row is visible so the compact
                // (axisSize:440) panel fits without overflow. When typing,
                // recents hides and the list can grow back.
                height:         recentsRow.visible ? Math.min(contentHeight, 6 * 40)
                                                   : Math.min(contentHeight, 8 * 40)
                implicitHeight: height
                clip:           true
                model:          root.filtered
                currentIndex:   root.selectedIdx

                // Instant highlight — hover sets selectedIdx, so any slide
                // animation just lags the bar behind the cursor.
                highlightMoveDuration: 0
                highlightMoveVelocity: -1
                highlight: Rectangle {
                    width:  resultList.width
                    height: 40
                    radius: Commons.Appearance.radius.sm
                    color:  Commons.Appearance.colors.accentAlpha
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width:  ListView.view.width
                    height: 40

                    // ── Icon with fallback chain ───────────────────────────────
                    Item {
                        id: iconWrapper
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 22; height: 22

                        property int _idx: 0
                        property var _cands: {
                            var n = modelData.icon || "", id = modelData.id || "", c = []
                            if (n) {
                                c.push(n.startsWith("/") ? n : "image://icon/" + n)
                                if (n !== n.toLowerCase()) c.push("image://icon/" + n.toLowerCase())
                            }
                            if (id && id !== n && id !== n.toLowerCase())
                                c.push("image://icon/" + id)
                            return c
                        }

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source:       iconWrapper._cands[iconWrapper._idx] || ""
                            fillMode:     Image.PreserveAspectFit
                            smooth:       true
                            onStatusChanged: {
                                if (status === Image.Error &&
                                        iconWrapper._idx < iconWrapper._cands.length - 1)
                                    iconWrapper._idx++
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready || iconWrapper._cands.length === 0
                            text:  ""
                            font { family: Commons.Appearance.font.family; pixelSize: 16 }
                            color: Commons.Appearance.colors.overlay1
                        }
                    }

                    Text {
                        anchors {
                            left:  iconWrapper.right; leftMargin:  10
                            right: pinBtn.left;       rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        text:  modelData.name || ""
                        color: root.selectedIdx === index
                                   ? Commons.Appearance.colors.text
                                   : Commons.Appearance.colors.subtext1
                        font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeBase }
                        elide: Text.ElideRight
                    }

                    // Pin/unpin toggle. Visible when the row is selected OR
                    // the app is already pinned (so pinned items stay tagged).
                    Rectangle {
                        id: pinBtn
                        readonly property bool _pinned: root.isPinned(modelData)
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        width: 22; height: 22
                        radius: Commons.Appearance.radius.sm
                        visible: _pinned || root.selectedIdx === index
                        color:   _pinArea.containsMouse ? Commons.Appearance.colors.surface0Alpha : "transparent"
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                        Text {
                            anchors.centerIn: parent
                            text:  pinBtn._pinned ? "󰐃" : "󰤱"
                            color: pinBtn._pinned ? Commons.Appearance.colors.accent
                                                  : Commons.Appearance.colors.overlay0
                            font { family: Commons.Appearance.font.family; pixelSize: 14 }
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        }

                        MouseArea {
                            id: _pinArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // MouseArea is on top of the row's TapHandler, so the
                            // click is consumed and doesn't trigger launch.
                            onClicked: root.togglePin(modelData)
                        }
                    }

                    HoverHandler { onHoveredChanged: if (hovered) root.selectedIdx = index }
                    TapHandler   { onTapped: root._launch(modelData) }
                }
            }

            // ── Empty state ────────────────────────────────────────────────────
            Item {
                visible: root.filtered.length === 0
                width:   parent.width
                height:  40
                Text {
                    anchors.centerIn: parent
                    text:  root.allApps.length === 0 ? "Loading…" : "No results"
                    color: Commons.Appearance.colors.overlay1
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeBase }
                }
            }
        }
    }
}
