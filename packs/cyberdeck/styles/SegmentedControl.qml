pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: selector keys (adr_027 Layer C delegate for
// SegmentedControl). Each segment is a sheared slot with a hairline; the
// selected one is a solid accent slot with dark text on it.
Item {
    id: seg
    property var api: ({})
    property string register: ""

    readonly property var _p: api.palette
    property color activeText: _p ? _p.base : "black"
    property color idleText:   _p ? _p.subtext0 : "white"

    Repeater {
        model: seg.api.count || 0
        delegate: Rectangle {
            id: k
            required property int index
            readonly property bool cur: index === seg.api.currentIndex
            readonly property bool hov: index === seg.api.hoveredIndex
            readonly property real len: seg.api.segmentSize || 0
            x: seg.api.vertical ? 4 : index * len + 3
            y: seg.api.vertical ? index * len + 3 : 0
            width:  seg.api.vertical ? seg.width - 8 : len - 6
            height: seg.api.vertical ? len - 6 : seg.height
            antialiasing: true
            color: !seg._p ? "transparent"
                 : cur ? seg._p.accent
                 : hov ? Qt.rgba(seg._p.accent.r, seg._p.accent.g, seg._p.accent.b, 0.12)
                 : Qt.rgba(0.02, 0.05, 0.07, 0.7)
            border.width: cur ? 0 : 1
            border.color: seg._p ? Qt.lighter(seg._p.surface2, 1.45) : "transparent"
            opacity: seg.api.enabled === false ? 0.5 : 1
            transform: Shear { xFactor: seg.api.vertical ? 0 : -0.3; origin.y: k.height / 2 }
        }
    }
}
