pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../Dashboard/panels"
import "../../../../Services/Compositor" as Compositor
import "../../../../Services/Compositor/KeybindsLogic.js" as Logic

// Shortcuts sheet (Super+K, item_145) — replaces the rofi show-keybinds.sh list.
// Read live from the mango config (FileView watch), so the sheet is never stale:
// edit a bind and reopen. Grouped by what a bind DOES (KeybindsLogic.category),
// described by the comment above it. Type to filter by description, action or
// key ("tag", "super + q"). Bottom-edge panel; Panel.qml owns chrome + Esc +
// click-outside.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    readonly property bool _mango: !Compositor.CompositorService.isHyprland
    readonly property string _confPath:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/mango/config.conf"

    property var _rows: []
    property string query: ""
    readonly property int _total: _rows.reduce((n, r) => n + r.keys.length, 0)
    // Debounced: each query rebuilds the cards, so not on every keystroke.
    Timer { id: queryDebounce; interval: 80; onTriggered: root.query = searchInput.text }
    readonly property var _groups: Logic.group(_rows, query)
    readonly property int _ncols: width >= 900 ? 3 : width >= 600 ? 2 : 1
    readonly property var _cols: Logic.columns(_groups, _ncols)
    readonly property int _shown: _groups.reduce((n, g) => n + g.rows.reduce((k, r) => k + r.keys.length, 0), 0)

    FileView {
        path: root._mango ? root._confPath : ""
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root._rows = Logic.parse(text() || "")
    }

    // Clear + focus the search on open (bound property: panelRoot is an untyped
    // var, so a Connections on its signal would never fire — see Launcher.qml).
    readonly property bool _panelOpen: root.panelRoot ? root.panelRoot.panelOpen : false
    on_PanelOpenChanged: if (_panelOpen) {
        searchInput.text = ""
        root.query = ""
        flick.contentY = 0
        searchInput.forceActiveFocus()
        // Again after the frame settles: the layer surface may not hold keyboard
        // focus yet at the instant the panel opens.
        Qt.callLater(function() { searchInput.forceActiveFocus() })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Commons.Appearance.spacing.s6; anchors.rightMargin: Commons.Appearance.spacing.s6
        anchors.topMargin: Commons.Appearance.spacing.s5;  anchors.bottomMargin: Commons.Appearance.spacing.s5
        spacing: Commons.Appearance.spacing.s4

        // ── Header: title + count, search, close ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Commons.Appearance.spacing.s4

            Column {
                spacing: Commons.Appearance.spacing.s1
                Text {
                    text: "Shortcuts"
                    color: Commons.Appearance.colors.textPrimary
                    font.family: Commons.Appearance.font.display
                    font.pixelSize: Commons.Appearance.font.sizeHeadline
                    font.weight: Commons.Appearance.font.weightSemibold
                }
                Text {
                    text: !root._mango ? "Hyprland"
                        : root.query ? root._shown + " of " + root._total + " shortcuts"
                        : root._total + " shortcuts · from your mango config"
                    color: Commons.Appearance.colors.textSecondary
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeBase
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 340
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
                        right: parent.right; rightMargin: Commons.Appearance.spacing.s3
                        verticalCenter: parent.verticalCenter
                    }
                    color: Commons.Appearance.colors.textPrimary
                    font { family: Commons.Appearance.font.family; pixelSize: Commons.Appearance.font.sizeMd }
                    selectByMouse: true
                    clip: true
                    onTextChanged: queryDebounce.restart()
                    Keys.onEscapePressed: {
                        if (text.length) text = ""
                        else if (root.panelRoot) root.panelRoot.close()
                    }
                    Keys.onDownPressed: flick.flick(0, -1200)
                    Keys.onUpPressed: flick.flick(0, 1200)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: "Search shortcuts…"
                        color: Commons.Appearance.colors.textMuted
                        font: searchInput.font
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignTop
                radius: Commons.Appearance.radius.sm
                color: closeHov.hovered ? Commons.Appearance.colors.accentAlpha : "transparent"
                border.color: closeHov.hovered ? Commons.Appearance.colors.accentBorder : "transparent"
                Behavior on color { Commons.ColorAnim {} }
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeHov.hovered ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeMd
                }
                HoverHandler { id: closeHov }
                TapHandler { onTapped: if (root.panelRoot) root.panelRoot.close() }
            }
        }

        // ── Cards: categories in masonry columns, scrolling ─────────────────
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._mango && root._groups.length > 0
            clip: true
            contentWidth: width
            contentHeight: colsRow.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            RowLayout {
                id: colsRow
                width: flick.width
                spacing: Commons.Appearance.spacing.s4

                Repeater {
                    model: root._cols
                    delegate: ColumnLayout {
                        id: col
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: Commons.Appearance.spacing.s4

                        Repeater {
                            model: col.modelData
                            delegate: DashCard {
                                id: card
                                required property var modelData
                                Layout.fillWidth: true
                                title: modelData.category.toUpperCase()
                                // Key column = this card's widest chord, capped: a card of
                                // "Super Q" rows gives its descriptions the room.
                                property real keyW: 0
                                readonly property real keyCap: 200

                                Repeater {
                                    model: card.modelData.rows
                                    delegate: RowLayout {
                                        id: row
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: Commons.Appearance.spacing.s3

                                        // Keycaps: one column per card so descriptions line up;
                                        // a chord wider than the cap wraps.
                                        Flow {
                                            id: caps
                                            readonly property real naturalW: {
                                                var w = -spacing
                                                for (var i = 0; i < children.length; i++)
                                                    if (children[i].width > 0) w += children[i].width + spacing
                                                return Math.max(0, w)
                                            }
                                            onNaturalWChanged: card.keyW = Math.max(card.keyW, Math.min(card.keyCap, naturalW))
                                            Layout.preferredWidth: card.keyW
                                            Layout.alignment: Qt.AlignTop
                                            spacing: Commons.Appearance.spacing.s1
                                            Repeater {
                                                model: row.modelData.chips
                                                delegate: Rectangle {
                                                    id: chip
                                                    required property var modelData
                                                    width: chipText.implicitWidth + (modelData.cap ? Commons.Appearance.spacing.s2 : 0)
                                                    height: 22
                                                    radius: Commons.Appearance.radius.xs
                                                    color: modelData.cap ? Commons.Appearance.colors.surface0Alpha : "transparent"
                                                    border.width: modelData.cap ? 1 : 0
                                                    border.color: Commons.Appearance.colors.glassBorder
                                                    Text {
                                                        id: chipText
                                                        anchors.centerIn: parent
                                                        text: chip.modelData.text
                                                        textFormat: Text.PlainText
                                                        color: chip.modelData.cap ? Commons.Appearance.colors.textPrimary
                                                                                  : Commons.Appearance.colors.textMuted
                                                        font.family: Commons.Appearance.font.family
                                                        font.pixelSize: Commons.Appearance.font.sizeSm
                                                        font.weight: Commons.Appearance.font.weightMedium
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignTop
                                            topPadding: 3
                                            text: Logic.styledDesc(row.modelData.desc, Commons.Appearance.colors.textMuted)
                                            textFormat: Text.StyledText
                                            color: Commons.Appearance.colors.textSecondary
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Empty states ────────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !flick.visible
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: !root._mango ? "The shortcuts sheet reads MangoWC binds; Hyprland isn't supported yet."
                : root._rows.length === 0 ? "No binds found in ~/.config/mango/config.conf"
                : "No shortcut matches “" + root.query + "”"
            color: Commons.Appearance.colors.textMuted
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeMd
        }
    }
}
