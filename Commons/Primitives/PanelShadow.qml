import QtQuick
import ".." as Commons

// Shared drop shadow for the neck-shaped floating panels — bar popups
// (wifi/bt/calendar/hover), the bar-edge BarPanel, and the Strip panels.
//
// ONE light source, from above. The shadow is CUT off the TOP edge always (so
// nothing casts upward — every panel reads with the same downward light) AND off
// the ATTACHED edge (so its blur tucks under the opaque panel instead of bleeding
// a dark line into the bar/strip seam). What's left is a soft downward drop on the
// free lower edges. Gated on shadowStrength → flat mode drops it. The neck body
// (and its flared attach band) is cut out of it (GlassShadow), so the shadow
// never shows through the translucent glass as a dark patch.
//
// Place as a sibling BEHIND the panel's Shape. For panels whose root IS the shadow's
// parent (popups, BarPanel) just set `side` + `perpInset` + `cornerRadius`; the size
// defaults to the parent. For the Strip (shadow is a sibling of a separately-placed
// card) pass panelX/Y/W/H explicitly and bind opacity/visible to the card.
GlassShadow {
    id: root

    // Which edge attaches to the bar/strip.
    property string side: "top"
    // Body inset on the edges perpendicular to `side` (the neck flare radius).
    property int perpInset: Commons.Appearance.radius.md
    // Shadow corner radius — match the panel body's rounded corners.
    property int cornerRadius: perpInset
    // How far to pull the shadow off the top/attached edges (≈ blur, so the blur
    // lands exactly at the panel edge and no further).
    property int attachCut: 14

    // Panel geometry the shadow tracks. Defaults to the parent Item; override for
    // the Strip, where the card is placed independently of the shadow's parent.
    property real panelX: 0
    property real panelY: 0
    property real panelW: parent ? parent.width : 0
    property real panelH: parent ? parent.height : 0

    readonly property bool _vert: side === "left" || side === "right"

    x: panelX
    y: panelY
    width:  panelW
    height: panelH
    trimLeft:   Math.max(_vert ? 0 : perpInset, side === "left"   ? attachCut : 0)
    trimRight:  Math.max(_vert ? 0 : perpInset, side === "right"  ? attachCut : 0)
    trimTop:    Math.max(_vert ? perpInset : 0, attachCut)
    trimBottom: Math.max(_vert ? perpInset : 0, side === "bottom" ? attachCut : 0)
    shadowRadius: cornerRadius
    blur:   Commons.Appearance.elevation.e3.blur
    spread: Commons.Appearance.elevation.e3.spread
    offset: Qt.vector2d(0, Commons.Appearance.elevation.e3.y)
    color:  Commons.Appearance.outerShadowColor(Commons.Appearance.elevation.e3)   // none under blur-safe rendering

    // The neck card's glass (BarPanel/Strip card geometry): the body, inset by the
    // flare radius on the perpendicular edges and rounded on its free corners,
    // plus the band along the attached edge where the flares widen it.
    cuts: {
        const W = width, H = height, r = perpInset, rb = cornerRadius
        if (side === "bottom") return [
            { x: r, y: 0, w: W - 2 * r, h: H, tl: rb, tr: rb, br: 0, bl: 0 },
            { x: 0, y: H - r, w: W, h: r, tl: 0, tr: 0, br: 0, bl: 0 }]
        if (side === "left") return [
            { x: 0, y: r, w: W, h: H - 2 * r, tl: 0, tr: rb, br: rb, bl: 0 },
            { x: 0, y: 0, w: r, h: H, tl: 0, tr: 0, br: 0, bl: 0 }]
        if (side === "right") return [
            { x: 0, y: r, w: W, h: H - 2 * r, tl: rb, tr: 0, br: 0, bl: rb },
            { x: W - r, y: 0, w: r, h: H, tl: 0, tr: 0, br: 0, bl: 0 }]
        return [
            { x: r, y: 0, w: W - 2 * r, h: H, tl: 0, tr: 0, br: rb, bl: rb },
            { x: 0, y: 0, w: W, h: r, tl: 0, tr: 0, br: 0, bl: 0 }]
    }
}
