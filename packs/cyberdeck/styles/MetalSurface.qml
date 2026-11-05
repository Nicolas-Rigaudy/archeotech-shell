pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Cyberdeck Netrunner: card / panel / tooltip chrome (adr_027 Layer C delegate
// for MetalSurface). A translucent dark-teal plate cut at 45° on the top-right
// and bottom-left corners, a teal hairline edge and faint accent scanlines every
// 4 px. Everything arrives through `api` (no Commons import).
Item {
    id: surf
    property var api: ({})
    property string register: ""

    readonly property var   _p:     api.palette
    readonly property color _accent: _p ? _p.accent : "transparent"
    // Edge hairline: the palette's line tone lifted a step (mock line2 #2c5666).
    // `api.edge` lets a caller light the edge (selected row, focused field).
    readonly property color _line:  !_p ? "transparent"
                                  : api.edge ? api.edge : Qt.lighter(_p.surface2, 1.45)
    readonly property color _fill:  Qt.rgba(0.03, 0.08, 0.11, 0.85)
    readonly property bool  _crisp: api.crisp === true
    // Cut size: the host's chamfer, at least 10 so the cut reads on small cards.
    readonly property int   _c: Math.max(4, Math.min(Math.max(10, api.chamfer !== undefined ? api.chamfer * 2 : 14),
                                                     Math.min(width, height) / 3))

    Shape {
        anchors.fill: parent
        visible: !!surf._p
        preferredRendererType: surf._crisp ? Shape.GeometryRenderer : Shape.CurveRenderer
        asynchronous: false
        ShapePath {
            strokeColor: surf._line
            strokeWidth: 1.2
            fillColor: surf._fill
            joinStyle: ShapePath.MiterJoin
            // (0,0) → (w-c,0) → (w,c) → (w,h) → (c·0.6,h) → (0,h-c·0.6) → close
            startX: 0.5; startY: 0.5
            PathLine { x: surf.width - surf._c;  y: 0.5 }
            PathLine { x: surf.width - 0.5;      y: surf._c }
            PathLine { x: surf.width - 0.5;      y: surf.height - 0.5 }
            PathLine { x: surf._c * 0.6;         y: surf.height - 0.5 }
            PathLine { x: 0.5;                   y: surf.height - surf._c * 0.6 }
            PathLine { x: 0.5;                   y: 0.5 }
        }
    }

    // Scanlines: 1 px accent rules every 4 px, barely there.
    Repeater {
        model: surf._p && surf.height > 24 ? Math.floor(surf.height / 4) : 0
        delegate: Rectangle {
            required property int index
            x: 2; y: index * 4 + 2
            width: surf.width - 4; height: 1
            color: surf._accent
            opacity: 0.035
        }
    }
}
