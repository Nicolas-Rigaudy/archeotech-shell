import QtQuick
import QtQuick.Shapes
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices
import "../../Modules/Shell/Panels" as Panels

// A panel dropping from a bar edge (Sprint 26-C, phase 2) — the bar's analogue
// of the strip's panel card. Hosted by Bar.qml as a child (like the hover/wifi
// popups), so it rides the same _popupBounds → ShellSurface input-mask path.
//
// Shows when a panel is open on THIS bar's side (an opener on the bar passed its
// side to ShellState). Grows perpendicular from the bar's inner edge, anchored
// along the axis to the opener that was clicked (holderRoot._panelAnchor), clamped
// to the screen. Content + sizing come from the shared PanelHost; this file owns
// the chrome + placement + open/close (it IS the content's panelRoot).
//
// Chrome is the SAME neck Shape the strip card uses (Sides/Strip.qml) so a bar
// panel fuses into the bar identically — concave arcs (radius _r) at the
// attached edge, convex far corners. CurveRenderer, never layer.enabled (see
// DECISIONS 2026-07-02).
Item {
    id: root
    required property var holderRoot

    readonly property string _side:   holderRoot ? holderRoot.side : ""
    readonly property var    _screen: holderRoot ? holderRoot.screen : null
    readonly property string _scr:    holderRoot && holderRoot.screen ? holderRoot.screen.name : ""
    readonly property bool   horizontal: holderRoot && holderRoot.horizontal

    // Panels are global; show on the bar whose side matches the active side.
    readonly property string _activePanel: ShellServices.ShellState.activePanel(_scr)
    readonly property string _activeSide:  ShellServices.ShellState.activeSide(_scr)
    // NB: must NOT depend on host.meta — meta is gated on host.shown, which is
    // bound to _open, so referencing it here would deadlock (open never turns on).
    readonly property bool   _open: _activePanel !== "" && _activeSide === _side

    // panelRoot API injected into the content.
    function close() { ShellServices.ShellState.closeAllAcross() }
    readonly property bool panelOpen: _open

    // ── Geometry ─────────────────────────────────────────────────────────────
    readonly property int  _r:          Commons.Appearance.radius.md
    readonly property int  _screenAxis: horizontal ? (holderRoot ? holderRoot.width : 0)
                                                    : (holderRoot ? holderRoot.height : 0)
    // Along-axis center: the clicked opener's position, else bar center.
    readonly property real _anchor: (holderRoot && holderRoot._panelAnchor >= 0)
                                    ? holderRoot._panelAnchor : _screenAxis / 2

    // Retained size — updated only while a valid panel is resolved, so closing
    // (host.meta → null → the "full" axis fallback) doesn't snap the card
    // mid-fade; it holds size while fading out.
    property real _perpSize: 0
    property real _axisSize: 0
    Connections {
        target: host
        function onPerpTargetChanged() { if (host.meta) root._perpSize = host.perpTarget }
        function onAxisTargetChanged() { if (host.meta) root._axisSize = host.axisTarget }
    }

    width:  horizontal ? _axisSize : _perpSize
    height: horizontal ? _perpSize : _axisSize

    // Position in bar-local coords: attach to the bar's inner edge; clamp along axis.
    x: _side === "left"  ? holderRoot.width
     : _side === "right" ? -width
     :                      Math.max(0, Math.min(_screenAxis - width, _anchor - width / 2))
    y: _side === "top"    ? holderRoot.height
     : _side === "bottom" ? -height
     :                       Math.max(0, Math.min(_screenAxis - height, _anchor - height / 2))

    visible: opacity > 0.01
    opacity: (_open && host.ready) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

    // Slide in from the bar edge (perpendicular) for the "drop" feel.
    transform: Translate {
        y: root._side === "top"    ? (root._open ? 0 : -12)
         : root._side === "bottom" ? (root._open ? 0 :  12) : 0
        x: root._side === "left"   ? (root._open ? 0 : -12)
         : root._side === "right"  ? (root._open ? 0 :  12) : 0
        Behavior on x { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
    }

    // Esc closes (the surface holds exclusive keyboard focus while open).
    focus: _open
    Keys.onEscapePressed: root.close()

    // ── Neck card (same geometry as Strip.qml's card) ──────────────────────────
    Shape {
        id: card
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        readonly property real _r: root._r
        readonly property var _p: {
            const W = width, H = height, r = _r, rb = _r
            if (root._side === "right") return [
                Qt.point(W,      0),          Qt.point(W,      H),
                Qt.point(W - r,  H - r),      Qt.point(rb,     H - r),
                Qt.point(0,      H - r - rb), Qt.point(0,      r + rb),
                Qt.point(rb,     r),          Qt.point(W - r,  r)
            ]
            if (root._side === "left") return [
                Qt.point(0,      H),          Qt.point(0,      0),
                Qt.point(r,      r),          Qt.point(W - rb, r),
                Qt.point(W,      r + rb),     Qt.point(W,      H - r - rb),
                Qt.point(W - rb, H - r),      Qt.point(r,      H - r)
            ]
            if (root._side === "top") return [
                Qt.point(0,          0),      Qt.point(W,          0),
                Qt.point(W - r,      r),      Qt.point(W - r,      H - rb),
                Qt.point(W - r - rb, H),      Qt.point(r + rb,     H),
                Qt.point(r,          H - rb), Qt.point(r,          r)
            ]
            return [ // bottom
                Qt.point(W,          H),      Qt.point(0,          H),
                Qt.point(r,          H - r),  Qt.point(r,          rb),
                Qt.point(r + rb,     0),      Qt.point(W - r - rb, 0),
                Qt.point(W - r,      rb),     Qt.point(W - r,      H - r)
            ]
        }

        ShapePath {
            fillColor:   Commons.Appearance.colors.glassBgLight
            strokeWidth: 0
            strokeColor: "transparent"
            startX: card._p[0].x
            startY: card._p[0].y
            PathLine { x: card._p[1].x; y: card._p[1].y }
            PathArc  { x: card._p[2].x; y: card._p[2].y; radiusX: card._r; radiusY: card._r; direction: PathArc.Counterclockwise }
            PathLine { x: card._p[3].x; y: card._p[3].y }
            PathArc  { x: card._p[4].x; y: card._p[4].y; radiusX: card._r; radiusY: card._r; direction: PathArc.Clockwise }
            PathLine { x: card._p[5].x; y: card._p[5].y }
            PathArc  { x: card._p[6].x; y: card._p[6].y; radiusX: card._r; radiusY: card._r; direction: PathArc.Clockwise }
            PathLine { x: card._p[7].x; y: card._p[7].y }
            PathArc  { x: card._p[0].x; y: card._p[0].y; radiusX: card._r; radiusY: card._r; direction: PathArc.Counterclockwise }
        }
    }

    Panels.PanelHost {
        id: host
        anchors.fill: parent
        anchors.margins: root._r
        side:       root._side
        screen:     root._screen
        panelId:    root._activePanel
        shown:      root._open
        screenAxis: root._screenAxis
        axisFloor:  160
        panelRoot:  root
    }
}
