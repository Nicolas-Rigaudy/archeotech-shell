pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Cyberdeck Netrunner plate shared by PanelChrome (strip panels) and
// PopupSurface (bar popups): a dark fill and a teal hairline along an open
// polyline whose first and last points sit on the docked edge, so that edge
// keeps no rule. Lives in styles/parts/ so PackRegistry (styles/*.qml) does not
// list it as a style delegate.
Shape {
    id: plate
    // Polyline walking the body; the fill closes it, the rule does not.
    property var points: []
    property var colors: null   // Appearance.colors

    visible: !!colors && points.length > 1
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillColor: Qt.rgba(0.02, 0.05, 0.07, 0.90)
        startX: plate.points.length ? plate.points[0].x : 0
        startY: plate.points.length ? plate.points[0].y : 0
        PathPolyline { path: plate.points }
    }
    ShapePath {
        strokeColor: plate.colors ? Qt.lighter(plate.colors.surface2, 1.45) : "transparent"
        strokeWidth: 1.5
        fillColor: "transparent"
        joinStyle: ShapePath.MiterJoin
        startX: plate.points.length ? plate.points[0].x : 0
        startY: plate.points.length ? plate.points[0].y : 0
        PathPolyline { path: plate.points }
    }
}
