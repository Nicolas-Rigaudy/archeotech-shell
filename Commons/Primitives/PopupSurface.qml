import QtQuick
import QtQuick.Shapes
import "../../Commons" as Commons

// Body of a bar popup card (hover, wifi, bluetooth, calendar): lift shadow, the
// neck-shaped outline (wide top edge, inward arcs, rounded bottom) filled and
// stroked from Appearance.popupSurface, and the optional bolted collar. Fill is
// a screen-space slice of the one global top-lit gradient unless the recipe says
// "local". The parent card supplies geometry (r/rb/bw) and its window position.
Item {
    id: surf
    anchors.fill: parent

    property real r
    property real rb
    property real bw
    property real winY: 0
    property real winH: 1080

    readonly property var _rec: Commons.Appearance.popupSurface
    readonly property bool _screen: _rec.sheen === "screen"

    PanelShadow { side: "top"; perpInset: surf.r; cornerRadius: surf.rb }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: Commons.Appearance.crispEdges ? 0 : 8

        ShapePath {
            fillGradient: LinearGradient {
                x1: 0; y1: surf._screen ? -surf.winY : 0
                x2: 0; y2: surf._screen ? (surf.winH - surf.winY) : surf.height
                GradientStop { position: surf._rec.stops[0][0]; color: Commons.Appearance._surfaceColor(surf._rec.stops[0][1]) }
                GradientStop { position: surf._rec.stops[1][0]; color: Commons.Appearance._surfaceColor(surf._rec.stops[1][1]) }
                GradientStop { position: surf._rec.stops[2][0]; color: Commons.Appearance._surfaceColor(surf._rec.stops[2][1]) }
            }
            strokeWidth: surf._rec.strokeWidth
            strokeColor: Commons.Appearance._surfaceColor(surf._rec.strokeColor)

            startX: 0; startY: 0
            PathLine { x: surf.bw + surf.r * 2; y: 0 }
            PathArc  { x: surf.bw + surf.r;     y: surf.r
                       radiusX: surf.r; radiusY: surf.r; direction: PathArc.Counterclockwise }
            PathLine { x: surf.bw + surf.r;     y: surf.height - surf.rb }
            PathArc  { x: surf.bw + surf.r - surf.rb; y: surf.height
                       radiusX: surf.rb; radiusY: surf.rb; direction: PathArc.Clockwise }
            PathLine { x: surf.r + surf.rb;     y: surf.height }
            PathArc  { x: surf.r;               y: surf.height - surf.rb
                       radiusX: surf.rb; radiusY: surf.rb; direction: PathArc.Clockwise }
            PathLine { x: surf.r;               y: surf.r }
            PathArc  { x: 0;                    y: 0
                       radiusX: surf.r; radiusY: surf.r; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: 0 }
        }
    }

    ConsoleChrome {                              // bolted-collar connection to the bar
        anchors.fill: parent
        visible: surf._rec.collar
        attachSide: "top"; showTrim: false; showGussets: false
        radius: surf.rb
    }
}
