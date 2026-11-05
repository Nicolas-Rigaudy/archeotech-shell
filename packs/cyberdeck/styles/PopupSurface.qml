pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Cyberdeck Netrunner: bar popup body (adr_027 Layer C delegate for
// PopupSurface: hover cards, wifi, bluetooth, calendar). The same plate as the
// strip panels (PanelChrome): dark fill, teal hairline, both bottom corners cut
// at 45°, the bar-attached top edge left open so the card reads as docked under
// the bar. A short red tick on the top-left echoes the frame's under-bar rule.
Item {
    id: ps
    property var api: ({})
    property string register: ""

    readonly property var  _p: api.palette
    readonly property real _r: api.r ?? 0
    readonly property real _bw: api.bw ?? width
    readonly property real _c: Math.min(14, _bw / 4, height / 4)

    // Body walks from the top-left (open edge) down, across the cut bottom and
    // back up the right side.
    readonly property var _pts: {
        const x0 = _r + 0.75, x1 = _r + _bw - 0.75
        const y0 = 0, y1 = height - 0.75, c = _c
        return [Qt.point(x0, y0), Qt.point(x0, y1 - c), Qt.point(x0 + c, y1),
                Qt.point(x1 - c, y1), Qt.point(x1, y1 - c), Qt.point(x1, y0)]
    }

    Shape {
        anchors.fill: parent
        visible: !!ps._p && ps.height > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: Qt.rgba(0.02, 0.05, 0.07, 0.90)   // PanelChrome's plate
            startX: ps._pts[0].x; startY: ps._pts[0].y
            PathPolyline { path: ps._pts }
        }
        // Edge rule, open along the top (the bar edge).
        ShapePath {
            strokeColor: ps._p ? Qt.lighter(ps._p.surface2, 1.45) : "transparent"
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            startX: ps._pts[0].x; startY: ps._pts[0].y
            PathPolyline { path: ps._pts }
        }
    }

    Rectangle {
        visible: !!ps._p
        x: ps._r + 1.5; y: 0
        width: Math.min(28, ps._bw / 3); height: 2
        color: ps._p ? ps._p.red : "transparent"
    }
}
