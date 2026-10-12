pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Keymap helper (item_144): how to type any character on each keyboard.
// Data: keymap-data.py beside this file (xkbcli keymaps + the Compose table),
// re-read on every open. Search a character, a letter ("e" → é è ê …) or a
// name; click a result or a key legend to copy it.
//
// Loaded by file:// URL, so no `import Commons`: the theme is the injected
// `appearance` (the Appearance singleton), and the view waits for it.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot
    property var appearance
    readonly property var _a: appearance
    readonly property bool _ready: !!_a

    // Sizes with no theme token (keycap height, tile and search widths).
    readonly property int _capH: 24
    readonly property int _rowMinW: 500    // results: one column per 500px
    readonly property int _rowH: 34
    readonly property int _charW: 28
    readonly property int _searchW: 280
    readonly property int _keyMax: 60      // keyboard diagram: largest key, px

    // ── data ────────────────────────────────────────────────────────────────
    property var _data: null
    property string _error: ""
    property string kbId: ""
    property string query: ""
    property string _copied: ""
    property int sel: 0                  // selected result (keyboard), -1 none
    property int hov: -1                 // hovered result
    onQueryChanged: sel = 0
    onKbIdChanged: sel = 0
    // Key labels the diagram lights: the hovered result's easiest combo, else the selected one's.
    readonly property var _litKeys: {
        var r = _results[hov >= 0 ? hov : sel]
        return r ? r.combos[0].reduce((l, chord) => l.concat(chord), []) : []
    }
    // "Latin Small Letter E With Acute" → "acute"; other names as they are.
    function _short(n) {
        var m = /^Latin (?:Small|Capital) (?:Letter|Ligature) \S+(?: With (.*))?$/.exec(n)
        return m ? (m[1] ? m[1].toLowerCase() : "") : n.toLowerCase()
    }

    readonly property var _keyboards: _data ? _data.keyboards : []
    readonly property var _kb: _keyboards.find(k => k.id === kbId) || _keyboards[0] || null
    readonly property var _map: _kb && _data ? _data.maps[_kb.map] : null
    readonly property var _results: {
        if (!_map) return []
        var q = query.trim()
        var all = _map.chars
        // No query: what is one chord away (the AltGr layer, as a list).
        if (q === "") return all.filter(c => c.combos[0].length === 1)
        if (q.length === 1) {
            var l = q.toLowerCase()
            return all.filter(c => c.ch === q || c.base === l)
        }
        var w = q.toLowerCase()
        return all.filter(c => c.name.toLowerCase().indexOf(w) >= 0)
    }

    Process {
        id: loader
        command: ["python3", Qt.resolvedUrl("keymap-data.py").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._data = JSON.parse(text)
                    root._error = root._data.errors.length ? "Skipped: " + root._data.errors.join("; ")
                                : root._data.keyboards.length ? "" : "No keyboard layouts found"
                    if (!root._keyboards.some(k => k.id === root.kbId)) root.kbId = root._data["default"]
                } catch (e) {
                    root._error = "Could not read the keymaps (see keymap-data.py; needs xkbcli)"
                }
            }
        }
    }

    function copy(ch) {
        Quickshell.execDetached(["wl-copy", "--", ch])
        _copied = ch
        copiedTimer.restart()
    }
    Timer { id: copiedTimer; interval: 1600; onTriggered: root._copied = "" }

    // Reload on open (bound property: panelRoot is an untyped var, a Connections
    // on its signal would never fire), so a layout changed in Settings shows up.
    readonly property bool _panelOpen: root.panelRoot ? root.panelRoot.panelOpen : false
    on_PanelOpenChanged: if (_panelOpen) loader.running = true
    // The panel content is created when it opens, so _panelOpen may already be
    // true (no change signal): load once on creation too.
    Component.onCompleted: loader.running = true

    // ── shared bits ─────────────────────────────────────────────────────────
    component Cap: Rectangle {
        property string text: ""
        property bool lit: false
        implicitWidth: capText.implicitWidth + root._a.spacing.s3
        implicitHeight: root._capH
        radius: root._a.radius.xs
        color: lit ? root._a.colors.accentAlpha : root._a.colors.surface0Alpha
        border.width: 1
        border.color: lit ? root._a.colors.accentBorder : root._a.colors.glassBorder
        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.text
            textFormat: Text.PlainText
            color: root._a.colors.textPrimary
            font.family: root._a.font.family
            font.pixelSize: root._a.font.sizeSm
            font.weight: root._a.font.weightMedium
        }
    }

    // The view needs the theme: built once `appearance` has been injected.
    Loader {
        anchors.fill: parent
        active: root._ready
        sourceComponent: view
    }

    Component {
        id: view
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root._a.spacing.s6; anchors.rightMargin: root._a.spacing.s6
            anchors.topMargin: root._a.spacing.s5;  anchors.bottomMargin: root._a.spacing.s5
            spacing: root._a.spacing.s4

            // Clear + focus the search on open, and when first built.
            readonly property bool open: root._panelOpen
            onOpenChanged: if (open) focusSearch()
            Component.onCompleted: focusSearch()
            function focusSearch() {
                searchInput.text = ""
                searchInput.forceActiveFocus()
                // Again after the frame settles: the layer surface may not hold keyboard focus yet.
                Qt.callLater(function() { searchInput.forceActiveFocus() })
            }

            // ── Header: title, keyboard picker, search ──────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: root._a.spacing.s4

                Column {
                    spacing: root._a.spacing.s1
                    Text {
                        text: "Keymap"
                        color: root._a.colors.textPrimary
                        font.family: root._a.font.display
                        font.pixelSize: root._a.font.sizeHeadline
                        font.weight: root._a.font.weightSemibold
                    }
                    Text {
                        text: root._copied ? "Copied " + root._copied
                            : root._error ? root._error
                            : root._map ? root._map.label : "Reading keymaps…"
                        textFormat: Text.PlainText
                        color: root._copied ? root._a.colors.accent
                             : root._error ? root._a.colors.warning : root._a.colors.textSecondary
                        font.family: root._a.font.family
                        font.pixelSize: root._a.font.sizeBase
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: root._searchW
                    Layout.preferredHeight: 40
                    color: root._a.colors.surfaceCard
                    border.color: searchInput.activeFocus ? root._a.colors.accent : root._a.colors.glassBorder
                    border.width: searchInput.activeFocus ? 2 : 1
                    radius: root._a.radius.md
                    Text {
                        id: searchGlyph
                        anchors { left: parent.left; leftMargin: root._a.spacing.s3; verticalCenter: parent.verticalCenter }
                        text: ""
                        font { family: root._a.font.family; pixelSize: root._a.font.sizeXl }
                        color: searchInput.activeFocus ? root._a.colors.accent : root._a.colors.textMuted
                    }
                    TextInput {
                        id: searchInput
                        anchors {
                            left: searchGlyph.right; leftMargin: root._a.spacing.s3
                            right: parent.right; rightMargin: root._a.spacing.s3
                            verticalCenter: parent.verticalCenter
                        }
                        color: root._a.colors.textPrimary
                        font { family: root._a.font.family; pixelSize: root._a.font.sizeMd }
                        selectByMouse: true
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: {
                            if (text.length) text = ""
                            else if (root.panelRoot) root.panelRoot.close()
                        }
                        // ↑/↓ by row, Tab/Shift+Tab by item, Enter copies the selection.
                        Keys.onUpPressed: root.sel = Math.max(0, root.sel - grid.cols)
                        Keys.onDownPressed: root.sel = Math.min(root._results.length - 1, root.sel + grid.cols)
                        Keys.onTabPressed: root.sel = Math.min(root._results.length - 1, root.sel + 1)
                        Keys.onBacktabPressed: root.sel = Math.max(0, root.sel - 1)
                        Keys.onReturnPressed: if (root._results[root.sel]) root.copy(root._results[root.sel].ch)
                        Keys.onEnterPressed: if (root._results[root.sel]) root.copy(root._results[root.sel].ch)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: "Type a letter, é, € or a name…"
                            color: root._a.colors.textMuted
                            font: searchInput.font
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                    radius: root._a.radius.sm
                    color: closeHov.hovered ? root._a.colors.accentAlpha : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeHov.hovered ? root._a.colors.textPrimary : root._a.colors.textMuted
                        font.family: root._a.font.family
                        font.pixelSize: root._a.font.sizeMd
                    }
                    HoverHandler { id: closeHov }
                    TapHandler { onTapped: if (root.panelRoot) root.panelRoot.close() }
                }
            }

            // Keyboard picker: one pill per keyboard (Settings → Input) / system layout.
            Flow {
                Layout.fillWidth: true
                spacing: root._a.spacing.s1
                Repeater {
                    model: root._keyboards
                    delegate: Rectangle {
                        id: kbPill
                        required property var modelData
                        readonly property bool selected: root._kb && root._kb.id === modelData.id
                        width: kbText.implicitWidth + root._a.spacing.s6
                        height: 32
                        radius: root._a.radius.sm
                        color: selected ? root._a.colors.accentAlpha
                             : kbHov.hovered ? root._a.colors.surface0Alpha : "transparent"
                        border.width: 1
                        border.color: selected ? root._a.colors.accentBorder : root._a.colors.glassBorder
                        Text {
                            id: kbText
                            anchors.centerIn: parent
                            text: kbPill.modelData.name
                            textFormat: Text.PlainText
                            color: kbPill.selected ? root._a.colors.textPrimary : root._a.colors.textSecondary
                            font.family: root._a.font.family
                            font.pixelSize: root._a.font.sizeBase
                        }
                        HoverHandler { id: kbHov }
                        TapHandler { onTapped: { root.kbId = kbPill.modelData.id; searchInput.forceActiveFocus() } }
                    }
                }
            }

            // ── Results: one line per character, in columns ────────────────────
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root._results
                currentIndex: root.sel
                readonly property int cols: Math.max(1, Math.floor(width / root._rowMinW))
                cellWidth: Math.floor(width / cols)
                cellHeight: root._rowH
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                Text {
                    visible: root._map !== null && root._results.length === 0
                    width: grid.width
                    topPadding: root._a.spacing.s8
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: root.query.trim() === "" ? "This layout types nothing beyond plain ASCII"
                        : "“" + root.query + "” can't be typed on this keyboard"
                    color: root._a.colors.textMuted
                    font.family: root._a.font.family
                    font.pixelSize: root._a.font.sizeMd
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.sel
                    width: grid.cellWidth - root._a.spacing.s2
                    height: grid.cellHeight - root._a.spacing.s1
                    radius: root._a.radius.sm
                    color: current ? root._a.colors.accentAlpha
                         : rowHov.hovered ? root._a.colors.surface0Alpha : "transparent"
                    border.width: current ? 1 : 0
                    border.color: root._a.colors.accentBorder
                    HoverHandler {
                        id: rowHov
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: root.hov = hovered ? row.index : (root.hov === row.index ? -1 : root.hov)
                    }
                    TapHandler { onTapped: { root.sel = row.index; root.copy(row.modelData.ch) } }

                    Text {
                        id: glyph
                        anchors { left: parent.left; leftMargin: root._a.spacing.s2; verticalCenter: parent.verticalCenter }
                        width: root._charW
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.ch
                        textFormat: Text.PlainText
                        color: root._a.colors.textPrimary
                        font.family: root._a.font.family
                        font.pixelSize: root._a.font.sizeXl
                    }

                    // The easiest combo as keycaps (→ between steps), then a muted
                    // "or …" for the second way when there is room.
                    Row {
                        id: combos
                        anchors { left: glyph.right; leftMargin: root._a.spacing.s2; right: name.left; rightMargin: root._a.spacing.s2
                                  verticalCenter: parent.verticalCenter }
                        spacing: root._a.spacing.s1
                        clip: true
                        Repeater {
                            model: row.modelData.combos
                            delegate: Row {
                                id: combo
                                required property var modelData
                                required property int index
                                spacing: root._a.spacing.s1
                                opacity: index === 0 ? 1 : 0.55
                                Text {
                                    visible: combo.index > 0
                                    height: root._capH
                                    leftPadding: root._a.spacing.s2
                                    verticalAlignment: Text.AlignVCenter
                                    text: "or"
                                    color: root._a.colors.textMuted
                                    font.family: root._a.font.family
                                    font.pixelSize: root._a.font.size2xs
                                }
                                Repeater {
                                    model: combo.modelData
                                    delegate: Row {
                                        id: step
                                        required property var modelData
                                        required property int index
                                        spacing: root._a.spacing.s1
                                        Text {
                                            visible: step.index > 0
                                            height: root._capH
                                            verticalAlignment: Text.AlignVCenter
                                            text: "→"
                                            color: root._a.colors.textMuted
                                            font.family: root._a.font.family
                                            font.pixelSize: root._a.font.sizeSm
                                        }
                                        Repeater {
                                            model: step.modelData
                                            delegate: Cap { required property var modelData; text: modelData }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: name
                        anchors { right: parent.right; rightMargin: root._a.spacing.s3; verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, parent.width * 0.3)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: root._short(row.modelData.name)
                        textFormat: Text.PlainText
                        color: root._a.colors.textMuted
                        font.family: root._a.font.family
                        font.pixelSize: root._a.font.sizeSm
                    }
                }
            }

            // ── Keyboard diagram ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: board.implicitHeight + root._a.spacing.s4 * 2
                visible: root._map !== null
                radius: root._a.radius.md
                color: root._a.colors.surfaceCard

                Column {
                    id: board
                    anchors.centerIn: parent
                    spacing: root._a.spacing.s2
                    // 15 key units on the widest row (13-14 keys + the row offset).
                    readonly property real unit: Math.min(root._keyMax, (parent.width - root._a.spacing.s4 * 2) / 15)

                    Repeater {
                        model: root._map ? root._map.rows : []
                        delegate: Row {
                            id: keyRow
                            required property var modelData
                            required property int index
                            spacing: root._a.spacing.s2
                            // Stagger like a real board: Tab, Caps, Shift widths.
                            leftPadding: [0, 0.5, 0.75, 1.25][index] * board.unit

                            Repeater {
                                model: keyRow.modelData
                                delegate: Rectangle {
                                    id: key
                                    required property var modelData
                                    readonly property var lv: modelData.levels
                                    // Same label the combos use: ASCII letters upper-case.
                                    readonly property string label: lv[0] ? (/^[a-z]$/.test(lv[0].ch) ? lv[0].ch.toUpperCase() : lv[0].ch) : ""
                                    readonly property bool lit: root._litKeys.indexOf(label) >= 0
                                    width: board.unit - root._a.spacing.s2
                                    height: board.unit * 0.85
                                    radius: root._a.radius.sm
                                    color: lit ? root._a.colors.accentAlpha : root._a.colors.surface0
                                    border.width: 1
                                    border.color: lit ? root._a.colors.accent : root._a.colors.surface1

                                    // Four legends: [base, Shift, AltGr, AltGr+Shift] at
                                    // [bottom-left, top-left, bottom-right, top-right].
                                    Repeater {
                                        model: 4
                                        delegate: Text {
                                            id: legend
                                            required property int index
                                            readonly property var l: key.lv[index]
                                            readonly property bool onRight: index >= 2
                                            readonly property bool onTop: index % 2 === 1
                                            // A Shift legend that is just the upper-case base is noise.
                                            visible: !!l && !(index === 1 && key.lv[0] && l.ch === key.lv[0].ch.toUpperCase())
                                            x: onRight ? key.width - width - root._a.spacing.s1 : root._a.spacing.s1
                                            y: onTop ? root._a.spacing.s1 / 2 : key.height - height - root._a.spacing.s1 / 2
                                            text: l ? l.ch : ""
                                            textFormat: Text.PlainText
                                            color: l && l.dead ? root._a.colors.warning
                                                 : onRight ? root._a.colors.accent : root._a.colors.textPrimary
                                            font.family: root._a.font.family
                                            font.pixelSize: index === 0 ? root._a.font.sizeMd : root._a.font.sizeSm
                                            font.weight: index === 0 ? root._a.font.weightSemibold : root._a.font.weightRegular
                                            // Click to copy; the hovered legend grows so it reads as clickable.
                                            scale: legHov.hovered ? 1.35 : 1
                                            Behavior on scale { NumberAnimation { duration: root._a.anim.fast } }
                                            HoverHandler { id: legHov; enabled: !!legend.l; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: if (legend.l) root.copy(legend.l.ch) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Legend for the legends.
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: root._a.spacing.s2 }
                    spacing: root._a.spacing.s3
                    Repeater {
                        model: [{ t: "AltGr", c: "accent" }, { t: "dead key", c: "warning" }]
                        delegate: Text {
                            required property var modelData
                            text: "■ " + modelData.t
                            color: root._a.colors[modelData.c]
                            font.family: root._a.font.family
                            font.pixelSize: root._a.font.size2xs
                        }
                    }
                }
            }
        }
    }
}
