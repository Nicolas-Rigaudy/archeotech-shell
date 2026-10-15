pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../../../Commons" as Commons
import "../../../../../Commons/Primitives" as Prim
import "../../../../../Services/Compositor/KeybindsLogic.js" as Logic

// Shortcuts tab of the Keyboard panel (item_145): the mango binds, a category
// rail on the left with counts, one list on the right ("what it does … keys").
// Typing searches every category (the rail jumps to All); Up/Down walk the rail.
// Keys are labelled for the selected keyboard (the panel parses with its
// keycode labels), and the hovered shortcut lights its keys on the diagram.
Item {
    id: root

    property var rows: []                   // KeybindsLogic.parse(config, labels)
    property string query: ""
    property string category: "All"
    property var hovRow: null

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
    signal focusSearch()

    onQueryChanged: category = "All"
    onRowsChanged: hovRow = null
    readonly property var _side: Logic.sidebar(rows, query)
    readonly property var _groups: Logic.group(rows, query).filter(g => root.category === "All" || g.category === root.category)
    readonly property int count: _side.length ? _side[0].count : 0
    // Key labels to light: the hovered shortcut's first chord (for a merged run
    // like Super+1…9, its first key).
    readonly property var lit: hovRow ? hovRow.keys[0] : []

    function step(d) {
        var i = _side.findIndex(e => e.category === category)
        for (var j = i + d; j >= 0 && j < _side.length; j += d)
            if (_side[j].count > 0) { category = _side[j].category; list.contentY = 0; return }
    }
    function page(d) { list.flick(0, -d * 2000) }
    function reset() { category = "All"; list.contentY = 0 }

    RowLayout {
        anchors.fill: parent
        spacing: Commons.Appearance.spacing.s4

        // The rail scrolls when the panel is short (a bottom panel over the diagram).
        Flickable {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            clip: true
            contentHeight: rail.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rail
                width: parent.width
                spacing: Commons.Appearance.spacing.s1

                Repeater {
                    model: root._side
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        readonly property bool selected: root.category === modelData.category
                        readonly property bool empty: modelData.count === 0
                        width: parent.width
                        height: 32
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
                            onTapped: { root.category = entry.modelData.category; list.contentY = 0; root.focusSearch() }
                        }
                    }
                }
            }
        }

        Prim.Divider {
            vertical: true
            Layout.fillHeight: true
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
                            Prim.Divider {
                                thin: true
                                anchors { left: secName.right; leftMargin: Commons.Appearance.spacing.s3; right: parent.right; verticalCenter: secName.verticalCenter }
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
                                HoverHandler {
                                    id: rowHov
                                    onHoveredChanged: root.hovRow = hovered ? row.modelData : (root.hovRow === row.modelData ? null : root.hovRow)
                                }

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
}
