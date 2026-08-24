import QtQuick
import QtQuick.Shapes
import "../../Commons" as Commons
import "../../Services/Compositor" as Compositor

// Per-window HUD corner brackets (adr_027 — theme chrome on the real windows).
//
// Draws a bracket at every corner of every visible window on this monitor, using
// live client geometry from the compositor (MangoWC.clientsFor → monitor-local
// coords). Mounted on the shell's Overlay-layer surface, so it renders ABOVE the
// windows. Pack-gated by the same `fx.brackets` block as the frame; empty/off ⇒
// nothing draws. Non-interactive (no input mask contribution).
//
// The bracket geometry mirrors FrameFx: horizontal arm → rounded bend (radius 0 =
// sharp) → vertical arm. All marks are flattened into one model (client × 4
// corners) so each delegate is a bare Shape with no custom context properties
// (Quickshell marks delegate context props FINAL).
Item {
    id: root
    property string screenName: ""

    readonly property var   _fx:      Commons.Appearance.fx
    readonly property var   _br:      _fx.brackets || ({})
    readonly property bool  _on:      !!_br.enabled
    readonly property int   _len:     _br.length    !== undefined ? _br.length    : 18
    readonly property int   _thick:   _br.thickness !== undefined ? _br.thickness : 2
    readonly property int   _inset:   _br.inset     !== undefined ? _br.inset     : 6
    readonly property int   _radius:  _br.radius    !== undefined ? _br.radius     : 0
    readonly property color _color:   Commons.Appearance.fxColor(_br.color, Commons.Appearance.colors.accent)

    // Flattened bracket marks: one per (window corner). Each = anchor point in
    // monitor-local coords + which corner (left/top) it is.
    readonly property var _marks: {
        var out = []
        if (!_on || !screenName) return out
        var cs = Compositor.MangoWC.clientsFor(screenName)
        for (var i = 0; i < cs.length; i++) {
            var c = cs[i]
            var L = c.x + _inset,          T = c.y + _inset
            var R = c.x + c.width - _inset, B = c.y + c.height - _inset
            var f = c.focused
            out.push({ left: true,  top: true,  cx: L, cy: T, focused: f })
            out.push({ left: false, top: true,  cx: R, cy: T, focused: f })
            out.push({ left: false, top: false, cx: R, cy: B, focused: f })
            out.push({ left: true,  top: false, cx: L, cy: B, focused: f })
        }
        return out
    }

    Repeater {
        model: root._marks
        delegate: Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // Focused window's brackets read full-strength; unfocused dim back —
            // the corner marks carry focus indication (this pack drops the border).
            opacity: modelData.focused ? 1.0 : 0.45
            ShapePath {
                id: sp
                strokeColor: root._color
                strokeWidth: root._thick
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                readonly property real ax: modelData.cx
                readonly property real ay: modelData.cy
                readonly property real dx: modelData.left ? 1 : -1
                readonly property real dy: modelData.top  ? 1 : -1
                readonly property real r:  Math.max(0.5, Math.min(root._radius, root._len))
                startX: ax + dx * root._len
                startY: ay
                PathLine { x: sp.ax + sp.dx * sp.r; y: sp.ay }
                PathArc {
                    x: sp.ax; y: sp.ay + sp.dy * sp.r
                    radiusX: sp.r; radiusY: sp.r
                    direction: (sp.dx * sp.dy > 0) ? PathArc.Counterclockwise : PathArc.Clockwise
                }
                PathLine { x: sp.ax; y: sp.ay + sp.dy * root._len }
            }
        }
    }
}
