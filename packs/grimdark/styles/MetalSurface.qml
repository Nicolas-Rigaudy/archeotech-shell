import QtQuick
import QtQuick.Shapes

// Grimdark: flat welded-steel plate behind cards, panels, tooltips and bar
// segments (adr_027 Layer C style delegate for MetalSurface). A machined plate:
// top-lit steel gradient, 45° chamfered corners matching the frame, a dark seat
// outline (reads recessed into the panel) + a lit-copper hairline inset from the
// edge. Tones come from api.steel (the frame's steel family), so the plate stays
// welded to the bezel. No Commons import: everything arrives through `api`.
Item {
    id: surf
    property var api: ({})

    // api arrives just after creation: guard every read so the first pass is quiet.
    readonly property var   _steel:  api.steel
    readonly property color _hi:     _steel ? _steel.hi   : "transparent"
    readonly property color _md:     _steel ? _steel.md   : "transparent"
    readonly property color _lo:     _steel ? _steel.lo   : "transparent"
    readonly property color _edge:   _steel ? _steel.edge : "transparent"
    readonly property color _cu:     api.palette ? api.palette.copperLit : "transparent"
    readonly property bool _topLit:  api.topLit !== false
    readonly property bool _crisp:   api.crisp === true
    readonly property real _seat:    api.seatOpacity !== undefined ? api.seatOpacity : 1.0
    readonly property int  _c:       Math.max(2, Math.min(api.chamfer !== undefined ? api.chamfer : 7,
                                                          Math.min(width, height) / 2))

    Shape {
        id: plate
        anchors.fill: parent
        visible: !!surf._steel
        preferredRendererType: surf._crisp ? Shape.GeometryRenderer : Shape.CurveRenderer
        asynchronous: false

        readonly property int  w: surf.width
        readonly property int  h: surf.height
        readonly property int  c: surf._c
        // Chamfered-rect outline (SVG), reused for fill + seat stroke so no seam.
        readonly property string _path:
              "M " + c + " 0"
            + " L " + (w - c) + " 0"  + " L " + w + " " + c
            + " L " + w + " " + (h - c) + " L " + (w - c) + " " + h
            + " L " + c + " " + h + " L 0 " + (h - c)
            + " L 0 " + c + " Z"
        // Inset outline (1.5px in) for the hairline trim.
        readonly property real   _i: 1.5
        readonly property string _inPath:
              "M " + c + " " + _i
            + " L " + (w - c) + " " + _i + " L " + (w - _i) + " " + c
            + " L " + (w - _i) + " " + (h - c) + " L " + (w - c) + " " + (h - _i)
            + " L " + c + " " + (h - _i) + " L " + _i + " " + (h - c)
            + " L " + _i + " " + c + " Z"

        ShapePath {                         // steel face: top-lit, dark seat outline
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: plate.h
                GradientStop { position: 0.00; color: surf._topLit ? surf._hi : surf._md }
                GradientStop { position: 0.28; color: surf._md }
                GradientStop { position: 1.00; color: surf._lo }
            }
            // dark seat: reads recessed; seatOpacity dials its weight
            strokeColor: Qt.rgba(surf._edge.r, surf._edge.g, surf._edge.b, surf._seat)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: plate._path }
        }
        ShapePath {                         // lit-copper hairline trim, inset from the edge
            fillColor: "transparent"
            strokeColor: Qt.rgba(surf._cu.r, surf._cu.g, surf._cu.b, 0.5)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: plate._inPath }
        }
    }
}
