pragma ComponentBehavior: Bound
import QtQuick
import "../../../../../Commons" as Commons

// Keyboard diagram for the Keyboard panel: the main block of one layout
// (scripts/keymap-data.py `rows`), each key with its four legends — base
// bottom-left, Shift top-left, AltGr bottom-right, AltGr+Shift top-right — and
// dead keys marked. Keys whose label is in `lit` light up (the hovered shortcut
// or character). Clicking a legend emits `picked(ch)` (the panel copies it).
Rectangle {
    id: root

    property var rows: []
    property var lit: []
    property int maxKey: 60                 // largest key, px
    signal picked(string ch)
    // Items for the card's header, left of the legend (the panel puts the
    // keyboard picker here: the choice sits on the keyboard it changes).
    default property alias header: headerSlot.data

    implicitHeight: headerSlot.height + board.implicitHeight + Commons.Appearance.spacing.s3 * 3
    radius: Commons.Appearance.radius.md
    color: Commons.Appearance.colors.surfaceCard

    Item {
        id: headerSlot
        anchors { left: parent.left; right: legendRow.left; top: parent.top
                  leftMargin: Commons.Appearance.spacing.s3; topMargin: Commons.Appearance.spacing.s3 }
        height: childrenRect.height
    }

    // The keys round the character block, sized like a real board (in key units,
    // 15 per row): Backspace; Tab; Caps … Enter; Shift … Shift; then the bottom
    // row. ISO boards (a key left of Z, 12 keys on the top letter row) have the
    // tall Enter and a short left Shift. They light like the others: hovering
    // Super+Shift+H lights Super, Shift and H.
    readonly property bool _iso: rows.length > 1 && rows[1].length === 12
    function _edges(i, n) {
        var e = [null, null]
        if (i === 0) e[1] = { t: "Backspace", w: 15 - n }
        else if (i === 1) { e[0] = { t: "Tab", w: _iso ? 1.5 : 15 - n }
                            if (_iso) e[1] = { t: "Enter", w: 15 - 1.5 - n } }
        else if (i === 2) { e[0] = { t: "Caps", w: 1.75 }
                            e[1] = { t: _iso ? "" : "Enter", lit: "Enter", w: 15 - 1.75 - n } }
        else if (i === 3) { var l = _iso ? 1.25 : 2.25
                            e[0] = { t: "Shift", w: l }; e[1] = { t: "Shift", w: 15 - l - n } }
        return e.map(k => k && k.w >= 0.5 ? k : null)
    }
    readonly property var _bottom: [{ t: "Ctrl", w: 1.5 }, { t: "Super", w: 1.25 }, { t: "Alt", w: 1.5 },
                                    { t: "Space", w: 7.75 }, { t: "AltGr", w: 1.5 }, { t: "Ctrl", w: 1.5 }]

    component ModKey: Rectangle {
        property var key: null              // { t: label, w: width in units, lit: label it lights for }
        property real unit: 0
        readonly property bool lit: !!key && root.lit.indexOf(key.lit || key.t) >= 0
        visible: !!key
        width: key ? key.w * unit - Commons.Appearance.spacing.s2 : 0
        height: unit * 0.85
        radius: Commons.Appearance.radius.sm
        color: lit ? Commons.Appearance.colors.accentAlpha : Qt.alpha(Commons.Appearance.colors.surface0, 0.6)
        border.width: 1
        border.color: lit ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface1
        Text {
            anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s2; bottom: parent.bottom; bottomMargin: Commons.Appearance.spacing.s1 }
            text: parent.key ? parent.key.t : ""
            color: parent.lit ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textMuted
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.size2xs
        }
    }

    Column {
        id: board
        anchors { horizontalCenter: parent.horizontalCenter; top: headerSlot.bottom; topMargin: Commons.Appearance.spacing.s3 }
        spacing: Commons.Appearance.spacing.s2
        // 15 key units per row (character keys + the edge keys).
        readonly property real unit: Math.min(root.maxKey, (root.width - Commons.Appearance.spacing.s4 * 2) / 15)

        Repeater {
            model: root.rows
            delegate: Row {
                id: keyRow
                required property var modelData
                required property int index
                spacing: Commons.Appearance.spacing.s2
                readonly property var edges: root._edges(index, modelData.length)

                ModKey { key: keyRow.edges[0]; unit: board.unit }
                Repeater {
                    model: keyRow.modelData
                    delegate: Rectangle {
                        id: key
                        required property var modelData
                        readonly property var lv: modelData.levels
                        // Same label the combos and shortcuts use: ASCII letters upper-case.
                        readonly property string label: lv[0] ? (/^[a-z]$/.test(lv[0].ch) ? lv[0].ch.toUpperCase() : lv[0].ch) : ""
                        readonly property bool lit: root.lit.indexOf(label) >= 0
                        width: board.unit - Commons.Appearance.spacing.s2
                        height: board.unit * 0.85
                        radius: Commons.Appearance.radius.sm
                        color: lit ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0
                        border.width: 1
                        border.color: lit ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface1

                        Repeater {
                            model: 4
                            delegate: Text {
                                id: legend
                                required property int index
                                readonly property var l: key.lv[index]
                                readonly property bool onRight: index >= 2
                                readonly property bool onTop: index % 2 === 1
                                readonly property bool isBase: index === 0
                                // A Shift legend that is just the upper-case base is noise.
                                visible: !!l && !(index === 1 && key.lv[0] && l.ch === key.lv[0].ch.toUpperCase())
                                x: onRight ? key.width - width - Commons.Appearance.spacing.s1 : Commons.Appearance.spacing.s1
                                y: onTop ? Commons.Appearance.spacing.s1 / 2 : key.height - height - Commons.Appearance.spacing.s1 / 2
                                text: l ? l.ch : ""
                                textFormat: Text.PlainText
                                color: l && l.dead ? Commons.Appearance.colors.warning
                                     : onRight ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textPrimary
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: isBase ? Commons.Appearance.font.sizeMd : Commons.Appearance.font.sizeSm
                                font.weight: isBase ? Commons.Appearance.font.weightSemibold : Commons.Appearance.font.weightRegular
                                // Click to copy; the hovered legend grows so it reads as clickable.
                                scale: legHov.hovered ? 1.35 : 1
                                Behavior on scale { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                                HoverHandler { id: legHov; enabled: !!legend.l; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: if (legend.l) root.picked(legend.l.ch) }
                            }
                        }
                    }
                }
                ModKey { key: keyRow.edges[1]; unit: board.unit }
            }
        }

        Row {
            visible: root.rows.length > 0
            spacing: Commons.Appearance.spacing.s2
            Repeater {
                model: root._bottom
                delegate: ModKey { required property var modelData; key: modelData; unit: board.unit }
            }
        }
    }

    // Legend for the legends.
    Row {
        id: legendRow
        anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s4; verticalCenter: headerSlot.verticalCenter }
        spacing: Commons.Appearance.spacing.s3
        Repeater {
            model: [{ t: "AltGr", c: "accent" }, { t: "dead key", c: "warning" }]
            delegate: Text {
                required property var modelData
                text: "■ " + modelData.t
                color: Commons.Appearance.colors[modelData.c]
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.size2xs
            }
        }
    }
}
