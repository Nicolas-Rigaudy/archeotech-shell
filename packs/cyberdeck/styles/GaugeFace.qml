pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: system meters (adr_027 Layer C delegate for GaugeFace).
// One row per stat: a small caps label, 30 sheared segments that fill with a
// rising brightness, and a large display readout. Accent by default, critical
// red at 85 % and over; battery is ok green, red only at 15 % and under.
Column {
    id: face
    property var api: ({})
    property string register: ""

    readonly property var _p: api.palette
    readonly property var _f: api.font
    spacing: 6

    // A count model (not the stats array): the host rebuilds `api` on every
    // poll tick, and an array model would recreate every row and segment.
    Repeater {
        model: face.api.stats ? face.api.stats.length : 0
        delegate: Item {
            id: row
            required property int index
            readonly property var modelData: face.api.stats[index] || ({ "label": "", "value": 0, "kind": "" })
            // No battery (or an unknown reading, < 0): drop the row.
            visible: !(modelData.kind === "bat" && modelData.value < 0)
            width: face.width
            height: 30
            readonly property real v: Math.max(0, Math.min(modelData.value, 100)) / 100
            readonly property color col: !face._p ? "transparent"
                : modelData.kind === "bat" ? (v <= 0.15 ? face._p.red : face._p.green)
                : v >= 0.85 ? face._p.red : face._p.accent

            Text {
                y: 7; width: 54
                text: row.modelData.label
                color: face._p ? face._p.overlay1 : "transparent"
                font.family: face._f ? face._f.mono : ""
                font.pixelSize: 12
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
            Row {
                id: segs
                x: 60; y: 4
                spacing: 3
                // 30 segments when the card is wide enough; fewer when narrow.
                readonly property int n: Math.max(8, Math.min(30, Math.floor((row.width - 60 - readout.width - 24) / 12)))
                Repeater {
                    model: segs.n
                    delegate: Rectangle {
                        required property int index
                        readonly property bool on: index < Math.round(row.v * segs.n)
                        width: 9; height: 22
                        antialiasing: true
                        color: on ? row.col : Qt.rgba(1, 1, 1, 0.07)
                        opacity: on ? 0.5 + 0.5 * index / segs.n : 1
                        transform: Shear { xFactor: -0.45; origin.y: 11 }
                    }
                }
            }
            Text {
                id: readout
                anchors.right: parent.right
                y: -3
                text: row.modelData.value + "%"
                color: row.col
                font.family: face._f ? face._f.display : ""
                font.pixelSize: 28
                font.weight: Font.Bold
            }
        }
    }
}
