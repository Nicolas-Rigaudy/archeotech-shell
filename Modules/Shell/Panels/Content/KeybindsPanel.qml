pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../../Services/Compositor" as Compositor
import "../../../../Services/Compositor/KeybindsLogic.js" as Logic
import "Keyboard"

// Keyboard panel (Super+K / Super+Shift+K; items 144 + 145): everything about the
// keys under your hands, for the keyboard you pick (Settings → Input layouts).
//   Shortcuts   the mango binds, read live from its config, with number-row keys
//               labelled as on the selected keyboard (Super+1 vs Super+&).
//   Characters  how to type é, €, « … on it: AltGr and dead-key combos.
// Both share the keyboard picker and the diagram below, which lights the keys of
// the hovered shortcut or character. Keyboard data: scripts/keymap-data.py
// (xkbcli keymaps + the Compose table), re-read on every open. Tab switches tabs;
// the tab also follows Commons.State.keyboardTab (set by the `keybinds` IPC).
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    readonly property bool _mango: !Compositor.CompositorService.isHyprland
    readonly property string _confPath:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/mango/config.conf"
    readonly property bool _chars: Commons.State.keyboardTab === "characters"

    // ── data ────────────────────────────────────────────────────────────────
    property string _conf: ""
    property var _data: null
    property string _error: ""
    property string kbId: ""
    property string query: ""
    property string _copied: ""

    readonly property var _keyboards: _data ? _data.keyboards : []
    readonly property var _kb: _keyboards.find(k => k.id === kbId) || _keyboards[0] || null
    readonly property var _map: _kb && _data ? _data.maps[_kb.map] : null
    // Re-parsed only when the config or the keyboard's labels really change (the
    // data reloads on every open; equal content must not rebuild the lists).
    readonly property string _labelsKey: _map ? JSON.stringify(_map.labels) : ""
    property var _rows: []
    function _reparse() { _rows = Logic.parse(_conf, _map ? _map.labels : null) }
    on_ConfChanged: _reparse()
    on_LabelsKeyChanged: _reparse()

    FileView {
        path: root._mango ? root._confPath : ""
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: { var t = text() || ""; if (t !== root._conf) root._conf = t }
    }

    Process {
        id: loader
        command: ["python3", Qt.resolvedUrl("../../../../scripts/keymap-data.py").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._data = JSON.parse(text)
                    root._error = root._data.errors.length ? "Skipped: " + root._data.errors.join("; ")
                                : root._data.keyboards.length ? "" : "No keyboard layouts found"
                    if (!root._keyboards.some(k => k.id === root.kbId)) root.kbId = root._data["default"]
                } catch (e) {
                    root._error = "Could not read the keyboard layouts (scripts/keymap-data.py needs xkbcli)"
                }
            }
        }
    }

    function copy(ch) {
        Quickshell.execDetached(["wl-copy", "--", ch])
        _copied = ch
        copiedTimer.restart()
    }
    Timer { id: copiedTimer; interval: 1600; onTriggered: root._copied = "" }   // how long "Copied é" shows

    function setTab(t) { Commons.State.keyboardTab = t }
    // A tab change — from the tabs, Tab, or the IPC while the panel is open —
    // starts the new tab with an empty search and the field focused.
    on_CharsChanged: {
        queryDebounce.stop()
        searchInput.text = ""
        root.query = ""
        searchInput.forceActiveFocus()
    }

    // Reset + reload + focus on open (bound property: panelRoot is an untyped var,
    // so a Connections on its signal would never fire — see Launcher.qml).
    readonly property bool _panelOpen: root.panelRoot ? root.panelRoot.panelOpen : false
    on_PanelOpenChanged: if (_panelOpen) _onOpen()
    // The content is created when the panel opens: load once on creation too.
    Component.onCompleted: _onOpen()
    function _onOpen() {
        searchInput.text = ""
        root.query = ""
        shortcuts.reset()
        loader.running = true
        searchInput.forceActiveFocus()
        // Again after the frame settles: the layer surface may not hold keyboard focus yet.
        Qt.callLater(function() { searchInput.forceActiveFocus() })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Commons.Appearance.spacing.s6; anchors.rightMargin: Commons.Appearance.spacing.s6
        anchors.topMargin: Commons.Appearance.spacing.s5;  anchors.bottomMargin: Commons.Appearance.spacing.s5
        spacing: Commons.Appearance.spacing.s3

        // ── One row: the tab switch, then the search (the primary action) ────
        RowLayout {
            Layout.fillWidth: true
            spacing: Commons.Appearance.spacing.s3

            // Segmented switch: one track, the selected segment raised in it.
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
                        model: [{ id: "shortcuts", t: "Shortcuts" }, { id: "characters", t: "Characters" }]
                        delegate: Rectangle {
                            id: tab
                            required property var modelData
                            readonly property bool selected: Commons.State.keyboardTab === modelData.id
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
                                text: tab.modelData.t
                                color: tab.selected ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textSecondary
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeMd
                                font.weight: tab.selected ? Commons.Appearance.font.weightSemibold : Commons.Appearance.font.weightRegular
                            }
                            HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.setTab(tab.modelData.id) }
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
                Behavior on border.color { Commons.ColorAnim {} }

                Text {
                    id: searchGlyph
                    anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s3; verticalCenter: parent.verticalCenter }
                    text: ""
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
                    color: Commons.Appearance.colors.textPrimary
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeMd }
                    selectByMouse: true
                    clip: true
                    // Shortcuts rebuild their list per query: debounce. Characters filter cheaply.
                    onTextChanged: root._chars ? root.query = text : queryDebounce.restart()
                    Timer { id: queryDebounce; interval: 80; onTriggered: root.query = searchInput.text }
                    Keys.onEscapePressed: {
                        if (text.length) text = ""
                        else if (root.panelRoot) root.panelRoot.close()
                    }
                    // Tab: the other tab. Up/Down: the rail (Shortcuts) or the line
                    // (Characters). Enter copies the line (Shift: its capital).
                    Keys.onTabPressed: root.setTab(root._chars ? "shortcuts" : "characters")
                    Keys.onBacktabPressed: root.setTab(root._chars ? "shortcuts" : "characters")
                    Keys.onDownPressed: root._chars ? characters.down() : shortcuts.step(1)
                    Keys.onUpPressed: root._chars ? characters.up() : shortcuts.step(-1)
                    Keys.onReturnPressed: event => { if (root._chars) characters.enter(event.modifiers & Qt.ShiftModifier) }
                    Keys.onEnterPressed: event => { if (root._chars) characters.enter(event.modifiers & Qt.ShiftModifier) }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown) { shortcuts.page(1); event.accepted = true }
                        else if (event.key === Qt.Key_PageUp) { shortcuts.page(-1); event.accepted = true }
                    }

                    // The hint carries the count, so no separate status line.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        visible: searchInput.text.length === 0
                        text: root._chars ? "Type a letter, é, € or a name…"
                            : root._mango ? "Search " + shortcuts.count + " shortcuts…" : "Search…"
                        color: Commons.Appearance.colors.textMuted
                        font: searchInput.font
                    }
                }
                // Right end of the field: "✓ é" after a copy, else the match count.
                Text {
                    id: notice
                    anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s4; verticalCenter: parent.verticalCenter }
                    text: root._copied ? "✓ copied " + root._copied
                        : root.query && !root._chars ? shortcuts.count + " found"
                        : root.query && root._chars ? characters.count + " found" : ""
                    textFormat: Text.PlainText
                    color: root._copied ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.weight: root._copied ? Commons.Appearance.font.weightSemibold : Commons.Appearance.font.weightRegular
                }
            }
        }

        // ── The tab ─────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160

            ShortcutsView {
                id: shortcuts
                anchors.fill: parent
                visible: !root._chars && root._mango && root._rows.length > 0
                rows: root._rows
                query: root._chars ? "" : root.query
                onFocusSearch: searchInput.forceActiveFocus()
            }
            CharactersView {
                id: characters
                anchors.fill: parent
                visible: root._chars
                map: root._map
                query: root._chars ? root.query : ""
                onPicked: ch => root.copy(ch)
            }
            Text {
                anchors.fill: parent
                visible: !root._chars && (!root._mango || root._rows.length === 0)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: !root._mango ? "The shortcuts list reads MangoWC binds; Hyprland isn't supported yet."
                    : "No binds found in ~/.config/mango/config.conf"
                color: Commons.Appearance.colors.textMuted
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
            }
        }

        // ── The keyboard, lighting the hovered shortcut / character; its
        //    header holds the keyboard choice it shows ──────────────────────
        KeyDiagram {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            // A short panel keeps the list: the diagram goes first.
            visible: root._map !== null && root.height > 620
            maxKey: 52
            rows: root._map ? root._map.rows : []
            lit: root._chars ? characters.lit : shortcuts.lit
            onPicked: ch => root.copy(ch)

            Row {
                spacing: Commons.Appearance.spacing.s3
                // Dropdown: the keyboards from Settings → Input, plus system layouts.
                Rectangle {
                    id: kbButton
                    width: kbLabel.implicitWidth + Commons.Appearance.spacing.s6
                    height: 30
                    radius: Commons.Appearance.radius.sm
                    color: kbHov.hovered || kbMenu.opened ? Commons.Appearance.colors.surface0Alpha : "transparent"
                    border.width: 1
                    border.color: kbMenu.opened ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.glassBorder
                    Text {
                        id: kbLabel
                        anchors.centerIn: parent
                        text: "󰌌  " + (root._kb ? root._kb.name : "Keyboard") + "  " + (kbMenu.opened ? "󰅃" : "󰅀")
                        textFormat: Text.PlainText
                        color: Commons.Appearance.colors.textPrimary
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeBase
                    }
                    HoverHandler { id: kbHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: kbMenu.opened ? kbMenu.close() : kbMenu.open() }

                    Popup {
                        id: kbMenu
                        y: kbButton.height + Commons.Appearance.spacing.s1
                        padding: Commons.Appearance.spacing.s1
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        onClosed: searchInput.forceActiveFocus()
                        background: Rectangle {
                            radius: Commons.Appearance.radius.base
                            color: Commons.Appearance.colors.glassBg
                            border.width: 1
                            border.color: Commons.Appearance.colors.glassBorder
                        }
                        contentItem: Column {
                            spacing: Commons.Appearance.spacing.s1
                            Repeater {
                                model: root._keyboards
                                delegate: Rectangle {
                                    id: opt
                                    required property var modelData
                                    readonly property bool current: root._kb && root._kb.id === modelData.id
                                    width: Math.max(optText.implicitWidth + Commons.Appearance.spacing.s6, kbButton.width)
                                    height: 30
                                    radius: Commons.Appearance.radius.sm
                                    color: current ? Commons.Appearance.colors.accentAlpha
                                         : optHov.hovered ? Commons.Appearance.colors.surface0Alpha : "transparent"
                                    Text {
                                        id: optText
                                        anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s3; verticalCenter: parent.verticalCenter }
                                        text: opt.modelData.name
                                        textFormat: Text.PlainText
                                        color: opt.current ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textSecondary
                                        font.family: Commons.Appearance.font.family
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                    }
                                    HoverHandler { id: optHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: { root.kbId = opt.modelData.id; kbMenu.close() } }
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._map ? root._map.label : ""
                    textFormat: Text.PlainText
                    color: Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
            }
        }

        // ── Footer: the keys, or what went wrong ────────────────────────────
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root._error ? root._error
                : root._chars ? "↑↓ move   ·   Enter copy   ·   Shift+Enter capital   ·   Tab shortcuts   ·   Esc close"
                : "↑↓ categories   ·   PgUp/PgDn scroll   ·   Tab characters   ·   Esc close"
            color: root._error ? Commons.Appearance.colors.warning : Commons.Appearance.colors.textMuted
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.size2xs
        }
    }
}
