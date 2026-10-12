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

    implicitHeight: board.implicitHeight + Commons.Appearance.spacing.s4 * 2
    radius: Commons.Appearance.radius.md
    color: Commons.Appearance.colors.surfaceCard

    Column {
        id: board
        anchors.centerIn: parent
        spacing: Commons.Appearance.spacing.s2
        // 15 key units on the widest row (13-14 keys + the row offset).
        readonly property real unit: Math.min(root.maxKey, (root.width - Commons.Appearance.spacing.s4 * 2) / 15)

        Repeater {
            model: root.rows
            delegate: Row {
                id: keyRow
                required property var modelData
                required property int index
                spacing: Commons.Appearance.spacing.s2
                // Stagger like a real board: Tab, Caps, Shift widths.
                leftPadding: [0, 0.5, 0.75, 1.25][index] * board.unit

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
            }
        }
    }

    // Legend for the legends.
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: Commons.Appearance.spacing.s2 }
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
