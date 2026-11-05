pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Cyberdeck Netrunner: the screen frame (adr_027 Layer C delegate for
// FrameStyle). Paints the band body itself (dark translucent, still above 0
// alpha so the compositor keeps blurring it), rules the content hole with a
// teal hairline cut at 45° on every corner, marks the hole's left and right
// edges with red crosshairs and runs a short red rule under the bar.
Item {
    id: fr
    property var api: ({})
    property string register: ""
    property bool replacesGlass: true

    readonly property var  _p: api.palette
    readonly property rect _r: api.contentRect || Qt.rect(0, 0, 0, 0)
    readonly property color _line: _p ? Qt.lighter(_p.surface2, 1.45) : "transparent"
    readonly property color _red:  _p ? _p.red : "transparent"
    // Corner cut: the fill's chamfer leg (api.cornerRadius), clamped so the
    // diagonal stays inside the window gap (a window corner sits `gap` px in on
    // both axes, so the line reaches it at cut == 2*gap).
    readonly property real _cut: Math.max(0, Math.min(api.cornerRadius ?? 10,
                                                      2 * (api.gap ?? 6) - 2))

    // Band body: the frame shape (outer rect minus the hole).
    Shape {
        anchors.fill: parent
        visible: !!fr._p && !!fr.api.framePath
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: Qt.rgba(0.02, 0.04, 0.06, 0.80)
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: fr.api.framePath || "" }
        }
    }

    // Hole rule, cut corners, drawn 1 px outside the hole so it never paints
    // over windows.
    Shape {
        id: hole
        anchors.fill: parent
        visible: !!fr._p && fr._r.width > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real x0: fr._r.x - 1
        readonly property real y0: fr._r.y - 1
        readonly property real x1: fr._r.x + fr._r.width + 1
        readonly property real y1: fr._r.y + fr._r.height + 1
        readonly property real c: fr._cut
        ShapePath {
            strokeColor: fr._line
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            startX: hole.x0 + hole.c; startY: hole.y0
            PathLine { x: hole.x1 - hole.c; y: hole.y0 }
            PathLine { x: hole.x1;            y: hole.y0 + hole.c }
            PathLine { x: hole.x1;            y: hole.y1 - hole.c }
            PathLine { x: hole.x1 - hole.c; y: hole.y1 }
            PathLine { x: hole.x0 + hole.c; y: hole.y1 }
            PathLine { x: hole.x0;            y: hole.y1 - hole.c }
            PathLine { x: hole.x0;            y: hole.y0 + hole.c }
            PathLine { x: hole.x0 + hole.c; y: hole.y0 }
        }
    }

    // Red crosshairs on the hole's side edges, at mid height (outside the hole).
    Repeater {
        model: fr._p && fr._r.width > 0 ? [fr._r.x - 1, fr._r.x + fr._r.width + 1] : []
        delegate: Item {
            required property real modelData
            readonly property bool leftSide: modelData < fr.width / 2
            x: leftSide ? modelData - 20 : modelData
            y: fr._r.y + fr._r.height / 2 - 10
            width: 20; height: 20
            Rectangle { x: 0; y: 9.5; width: 20; height: 1; color: fr._red }
            Rectangle { x: 9.5; y: 0; width: 1; height: 20; color: fr._red }
        }
    }

    // Short red rule under the bar, centred.
    Rectangle {
        visible: !!fr._p && (fr.api.bands ? fr.api.bands.top : 0) > 8
        width: Math.min(520, fr.width * 0.3); height: 2
        x: (fr.width - width) / 2
        y: (fr.api.bands ? fr.api.bands.top : 0) - 3
        color: fr._red
    }
}
