import QtQuick
import QtQuick.Shapes

// Grimdark — machined-steel button chrome (adr_027 Layer C style delegate).
// Chrome ONLY: the base GlassButton keeps behaviour/interaction/content/label. No
// Commons import (this lives outside the shell tree) — all state + tones via `api`
// (see the api.colors steel* family, single-sourced from the frame's palette).
//
// A stamped steel key that matches the frame bezel: flat top-lit steel face, 45°
// chamfered corners, a dark seat outline (reads recessed into the panel) + a brass
// hairline. Active = the key is LIVE: it lifts (brighter steel) and lights a teal
// edge — the pack's "cyan is the one live note", instead of the old copper wash.
Item {
    id: root
    property var api: ({})

    readonly property color _hi:   (api.colors && api.colors.steelHi)   ? api.colors.steelHi   : "#333f4d"
    readonly property color _md:   (api.colors && api.colors.steelMd)   ? api.colors.steelMd   : "#28313d"
    readonly property color _lo:   (api.colors && api.colors.steelLo)   ? api.colors.steelLo   : "#1c232d"
    readonly property color _edge: (api.colors && api.colors.steelEdge) ? api.colors.steelEdge : "#05080d"
    readonly property color _teal: (api.colors && api.colors.teal)      ? api.colors.teal      : "#57d8d2"
    readonly property color _brass:(api.colors && api.colors.accent)    ? api.colors.accent    : "#a8683c"
    readonly property bool  _active:  api.active === true
    readonly property bool  _hovered: api.hovered === true

    readonly property int   _w: width
    readonly property int   _h: height
    readonly property int   _c: Math.max(2, Math.min(5, Math.min(_w, _h) / 2))
    readonly property string _path:
          "M " + _c + " 0"
        + " L " + (_w - _c) + " 0" + " L " + _w + " " + _c
        + " L " + _w + " " + (_h - _c) + " L " + (_w - _c) + " " + _h
        + " L " + _c + " " + _h + " L 0 " + (_h - _c)
        + " L 0 " + _c + " Z"

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {                         // steel face — top-lit; lifts a touch when active/hovered
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: root._h
                GradientStop { position: 0.0; color: root._active ? Qt.lighter(root._hi, 1.18)
                                                    : root._hovered ? Qt.lighter(root._hi, 1.08) : root._hi }
                GradientStop { position: 0.30; color: root._md }
                GradientStop { position: 1.0;  color: root._lo }
            }
            strokeColor: root._edge          // dark seat — recessed into the panel
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: root._path }
        }
        ShapePath {                         // trim: brass hairline at rest → lit brass when active (teal dropped, too modern)
            fillColor: "transparent"
            strokeColor: root._active
                ? Qt.lighter(root._brass, 1.3)
                : Qt.rgba(root._brass.r, root._brass.g, root._brass.b, root._hovered ? 0.55 : 0.32)
            strokeWidth: root._active ? 1.5 : 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: root._path }
        }
    }
}
