pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: bar zone housing (adr_027 Layer C delegate for
// BarSegment). A dark translucent box with a teal hairline, sheared to lean
// like a HUD readout. 30 px tall, centred in the bar.
Item {
    id: seg
    property var api: ({})
    property string register: ""

    readonly property var _p: api.palette

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 8; width: parent.width - 16
        height: Math.min(30, parent.height - 2)
        color: Qt.rgba(0.02, 0.05, 0.07, 0.7)
        border.width: 1
        border.color: seg._p ? Qt.lighter(seg._p.surface2, 1.45) : "transparent"
        antialiasing: true
        // Lean the box; the shear pivots on the vertical centre so it stays put.
        transform: Shear { xFactor: -0.35; origin.y: 15 }
    }
}
