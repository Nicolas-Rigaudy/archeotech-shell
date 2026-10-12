pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../../Services/Compositor" as Compositor
import "../../../../Services/Compositor/KeybindsLogic.js" as Logic

// Shortcuts sheet (Super+K, item_145) — replaces the rofi show-keybinds.sh list.
// Read live from the mango config (FileView watch), so the sheet is never stale.
// Lookup layout (owner, 2026-10-12): a category rail on the left with counts,
// one list on the right, each row "what it does … keys" (description first,
// keycaps right-aligned) so you scan by the task. Typing searches every
// category (the rail jumps to All and shows per-category hits); Up/Down walk the
// rail. Bottom-edge panel; Panel.qml owns chrome + Esc + click-outside.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    readonly property bool _mango: !Compositor.CompositorService.isHyprland
    readonly property string _confPath:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/mango/config.conf"

    readonly property var _glyphs: ({
        "All": "󰌌",
        "Apps": "󰀻",
        "Shell": "󰕮",
        "Windows": "󰖯",
        "Tags": "󰓹",
        "Monitors": "󰍹",
        "Layouts": "󰕰",
        "Groups": "󰓩",
        "Tools": "󱁤",
        "Media & hardware": "󰝚",
        "System": "󰐥",
        "Mouse & gestures": "󰍽"
    })

    property var _rows: []
    property string query: ""
    property string category: "All"
    // Debounced: each query rebuilds the list, so not on every keystroke.
    Timer { id: queryDebounce; interval: 80; onTriggered: { root.query = searchInput.text; root.category = "All" } }
    readonly property var _side: Logic.sidebar(_rows, query)
    readonly property var _groups: Logic.group(_rows, query).filter(g => root.category === "All" || g.category === root.category)

    function _step(d) {
        var i = _side.findIndex(e => e.category === category)
        for (var j = i + d; j >= 0 && j < _side.length; j += d)
            if (_side[j].count > 0) { category = _side[j].category; list.contentY = 0; return }
    }

    FileView {
        path: root._mango ? root._confPath : ""
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root._rows = Logic.parse(text() || "")
    }

    // Reset + focus the search on open (bound property: panelRoot is an untyped
    // var, so a Connections on its signal would never fire — see Launcher.qml).
    readonly property bool _panelOpen: root.panelRoot ? root.panelRoot.panelOpen : false
    on_PanelOpenChanged: if (_panelOpen) {
        searchInput.text = ""
        root.query = ""
        root.category = "All"
        list.contentY = 0
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
                        : root.query ? root._side[0].count + " matching “" + root.query + "”"
                        : root._side[0].count + " shortcuts · from your mango config"
                    textFormat: Text.PlainText
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
                    Keys.onDownPressed: root._step(1)
                    Keys.onUpPressed: root._step(-1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_PageDown) { list.flick(0, -2000); event.accepted = true }
                        else if (event.key === Qt.Key_PageUp) { list.flick(0, 2000); event.accepted = true }
                    }

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

        // ── Body: category rail | divider | list ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._mango && root._rows.length > 0
            spacing: Commons.Appearance.spacing.s4

            Column {
                Layout.preferredWidth: 220
                Layout.alignment: Qt.AlignTop
                spacing: Commons.Appearance.spacing.s1

                Repeater {
                    model: root._side
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        readonly property bool selected: root.category === modelData.category
                        readonly property bool empty: modelData.count === 0
                        width: parent.width
                        height: 36
                        radius: Commons.Appearance.radius.sm
                        color: selected ? Commons.Appearance.colors.accentAlpha
                             : entryHov.hovered && !empty ? Commons.Appearance.colors.surface0Alpha : "transparent"
                        Behavior on color { Commons.ColorAnim {} }

                        RowLayout {
                            anchors { fill: parent; leftMargin: Commons.Appearance.spacing.s3; rightMargin: Commons.Appearance.spacing.s3 }
                            spacing: Commons.Appearance.spacing.s3
                            Text {
                                Layout.preferredWidth: Commons.Appearance.font.sizeXl
                                horizontalAlignment: Text.AlignHCenter
                                text: root._glyphs[entry.modelData.category] || ""
                                color: entry.selected ? Commons.Appearance.colors.accent
                                     : entry.empty ? Commons.Appearance.colors.textMuted : Commons.Appearance.colors.textSecondary
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeLg
                            }
                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.category
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: entry.selected ? Commons.Appearance.colors.textPrimary
                                     : entry.empty ? Commons.Appearance.colors.textMuted : Commons.Appearance.colors.textSecondary
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeMd
                                font.weight: entry.selected ? Commons.Appearance.font.weightSemibold : Commons.Appearance.font.weightRegular
                            }
                            Text {
                                text: entry.modelData.count
                                color: entry.selected ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textMuted
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeSm
                            }
                        }
                        HoverHandler { id: entryHov; enabled: !entry.empty }
                        TapHandler {
                            enabled: !entry.empty
                            onTapped: { root.category = entry.modelData.category; list.contentY = 0; searchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Commons.Appearance.colors.surface0
            }

            Flickable {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listCol
                    width: list.width
                    spacing: 0

                    Text {
                        visible: root._groups.length === 0
                        width: parent.width
                        topPadding: Commons.Appearance.spacing.s12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        text: "No shortcut matches “" + root.query + "”"
                        color: Commons.Appearance.colors.textMuted
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeMd
                    }

                    Repeater {
                        model: root._groups
                        delegate: Column {
                            id: grp
                            required property var modelData
                            required property int index
                            width: listCol.width
                            spacing: 0

                            // Section header (All view only): a gap above every
                            // section but the first, then the name + a rule.
                            Item {
                                visible: root.category === "All"
                                width: parent.width
                                height: Commons.Appearance.font.sizeSm + Commons.Appearance.spacing.s3
                                        + (grp.index > 0 ? Commons.Appearance.spacing.s4 : 0)
                                Text {
                                    id: secName
                                    anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s3; bottom: parent.bottom; bottomMargin: Commons.Appearance.spacing.s1 }
                                    text: grp.modelData.category.toUpperCase()
                                    color: Commons.Appearance.colors.accent
                                    font.family: Commons.Appearance.font.display
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    font.letterSpacing: Commons.Appearance.font.trackingLabel
                                }
                                Rectangle {
                                    anchors { left: secName.right; leftMargin: Commons.Appearance.spacing.s3; right: parent.right; verticalCenter: secName.verticalCenter }
                                    height: 1
                                    color: Commons.Appearance.colors.surface0
                                }
                            }

                            Repeater {
                                model: grp.modelData.rows
                                delegate: Rectangle {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    width: grp.width
                                    height: Math.max(32, caps.height + Commons.Appearance.spacing.s2)
                                    radius: Commons.Appearance.radius.sm
                                    // Faint zebra so the eye can follow a row across the
                                    // gap from description to keys; hover is a full tint.
                                    color: rowHov.hovered ? Commons.Appearance.colors.surface0Alpha
                                         : row.index % 2 === 1 ? Qt.alpha(Commons.Appearance.colors.surface0, 0.25) : "transparent"
                                    HoverHandler { id: rowHov }

                                    Text {
                                        anchors {
                                            left: parent.left; leftMargin: Commons.Appearance.spacing.s3
                                            right: caps.left; rightMargin: Commons.Appearance.spacing.s4
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: Logic.styledDesc(row.modelData.desc, Commons.Appearance.colors.textMuted)
                                        textFormat: Text.StyledText
                                        elide: Text.ElideRight
                                        color: Commons.Appearance.colors.textPrimary
                                        font.family: Commons.Appearance.font.family
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                    }

                                    // Keycaps, right-aligned; a very long chord wraps
                                    // within half the row instead of eating the text.
                                    Flow {
                                        id: caps
                                        anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s3; verticalCenter: parent.verticalCenter }
                                        width: Math.min(implicitW, row.width / 2)
                                        layoutDirection: Qt.RightToLeft
                                        spacing: Commons.Appearance.spacing.s1
                                        readonly property real implicitW: {
                                            var w = -spacing
                                            for (var i = 0; i < children.length; i++)
                                                if (children[i].width > 0) w += children[i].width + spacing
                                            return Math.max(0, w)
                                        }
                                        Repeater {
                                            // RightToLeft lays the first item rightmost: feed it reversed.
                                            model: row.modelData.chips.slice().reverse()
                                            delegate: Rectangle {
                                                id: chip
                                                required property var modelData
                                                width: chipText.implicitWidth + (modelData.cap ? Commons.Appearance.spacing.s3 : 0)
                                                height: 24
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
            visible: !root._mango || root._rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: !root._mango ? "The shortcuts sheet reads MangoWC binds; Hyprland isn't supported yet."
                : "No binds found in ~/.config/mango/config.conf"
            color: Commons.Appearance.colors.textMuted
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeMd
        }
    }
}
