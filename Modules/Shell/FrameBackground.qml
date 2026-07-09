import QtQuick
import QtQuick.Shapes
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices

// Sprint 22 — unified frame background.
//
// Draws the resting glass for EVERY active side as ONE ShapePath, so adjacent
// bars/strips form a single continuous fill: no translucent overlap seams, and
// each junction between two active sides gets a real concave fillet of radius R,
// independent of the two sides' thicknesses. Bar/Strip bodies are transparent
// and host their widgets on top; the strip popup cards draw their own shape.
//
// Tiling (no overlap): horizontal bands (top/bottom) span the full width and
// own the screen corners; vertical bands (left/right) sit BETWEEN them. So the
// pieces abut without overlapping, which lets WindingFill render one clean fill.
//   • Outer (screen-corner) corners round by `_or` — 0 in framed mode (sharp,
//     hugs the screen), cornerRadius in pill mode (floating rounded-rect). A
//     radius-0 SVG arc is drawn as a straight line, so the same path serves both.
//   • Inner (content-facing) junction corners round by `_r` via a concave wedge.
Shape {
    id: frame
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    required property string screenName

    // Rebuild whenever the config or the surface size changes.
    property string _d: ""
    function _rebuild() { _d = _build() }
    Component.onCompleted: _rebuild()
    onWidthChanged:  _rebuild()
    onHeightChanged: _rebuild()
    onScreenNameChanged: _rebuild()
    Connections {
        target: ShellServices.ShellConfig
        function onDataChanged() { frame._rebuild() }
    }

    function _build() {
        var cfg = ShellServices.ShellConfig
        var w = width, h = height
        if (w <= 0 || h <= 0) return ""

        var pill = cfg.pillMode()
        var o  = pill ? cfg.pillGap() : 0
        var R  = cfg.cornerRadius()          // inner (concave) radius
        var OR = pill ? cfg.cornerRadius() : 0   // outer (convex) radius

        var tg = cfg.sideGap("top",    screenName)
        var bg = cfg.sideGap("bottom", screenName)
        var lg = cfg.sideGap("left",   screenName)
        var rg = cfg.sideGap("right",  screenName)

        var cl = o + lg, ct = o + tg, cr = w - o - rg, cb = h - o - bg
        var vTop = tg > 0 ? ct : o          // vertical bands sit between the
        var vBot = bg > 0 ? cb : h - o      // horizontal bands

        // CW rounded rectangle with per-corner radii (0 → sharp via SVG line).
        function rr(x0, y0, x1, y1, rtl, rtr, rbr, rbl) {
            return "M " + (x0 + rtl) + " " + y0
                 + " L " + (x1 - rtr) + " " + y0
                 + " A " + rtr + " " + rtr + " 0 0 1 " + x1 + " " + (y0 + rtr)
                 + " L " + x1 + " " + (y1 - rbr)
                 + " A " + rbr + " " + rbr + " 0 0 1 " + (x1 - rbr) + " " + y1
                 + " L " + (x0 + rbl) + " " + y1
                 + " A " + rbl + " " + rbl + " 0 0 1 " + x0 + " " + (y1 - rbl)
                 + " L " + x0 + " " + (y0 + rtl)
                 + " A " + rtl + " " + rtl + " 0 0 1 " + (x0 + rtl) + " " + y0
                 + " Z "
        }
        // Concave fillet wedge at an inner corner: corner → one side's inner edge
        // → arc bulging back toward the corner → close.
        function fillet(cx, cy, e1x, e1y, e2x, e2y, sweep) {
            return "M " + cx + " " + cy + " L " + e1x + " " + e1y
                 + " A " + R + " " + R + " 0 0 " + sweep + " " + e2x + " " + e2y + " Z "
        }

        // Per-band cap radii, clamped to half the band thickness so a thin strip
        // can't request a corner wider than itself. `o*` = outer (screen-corner)
        // round, `i*` = inner cap at a TERMINATION end (neighbour inactive). A
        // junction end (neighbour active) stays sharp (0) — the fillet rounds it.
        var toO = Math.min(OR, tg / 2), toI = Math.min(R, tg / 2)
        var boO = Math.min(OR, bg / 2), boI = Math.min(R, bg / 2)
        var loO = Math.min(OR, lg / 2), loI = Math.min(R, lg / 2)
        var roO = Math.min(OR, rg / 2), roI = Math.min(R, rg / 2)

        var d = ""
        // rr(x0,y0,x1,y1, rtl,rtr,rbr,rbl)
        if (tg > 0) d += rr(o,  o,    w - o, ct,    toO, toO, rg > 0 ? 0 : toI, lg > 0 ? 0 : toI)
        if (bg > 0) d += rr(o,  cb,   w - o, h - o, lg > 0 ? 0 : boI, rg > 0 ? 0 : boI, boO, boO)
        if (lg > 0) d += rr(o,  vTop, cl,    vBot,  tg > 0 ? 0 : loO, tg > 0 ? 0 : loI, bg > 0 ? 0 : loI, bg > 0 ? 0 : loO)
        if (rg > 0) d += rr(cr, vTop, w - o, vBot,  tg > 0 ? 0 : roI, tg > 0 ? 0 : roO, bg > 0 ? 0 : roO, bg > 0 ? 0 : roI)

        if (tg > 0 && lg > 0) d += fillet(cl, ct, cl + R, ct, cl, ct + R, 0)
        if (tg > 0 && rg > 0) d += fillet(cr, ct, cr - R, ct, cr, ct + R, 1)
        if (bg > 0 && lg > 0) d += fillet(cl, cb, cl + R, cb, cl, cb - R, 1)
        if (bg > 0 && rg > 0) d += fillet(cr, cb, cr - R, cb, cr, cb - R, 0)

        return d
    }

    ShapePath {
        fillColor:   Commons.Appearance.colors.glassBgLight
        strokeWidth: 0
        strokeColor: "transparent"
        fillRule:    ShapePath.WindingFill
        PathSvg { path: frame._d }
    }
}
