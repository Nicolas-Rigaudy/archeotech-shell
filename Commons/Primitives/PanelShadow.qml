import QtQuick
import QtQuick.Effects
import ".." as Commons

// Shared drop shadow for the neck-shaped floating panels — bar popups
// (wifi/bt/calendar/hover), the bar-edge BarPanel, and the Strip panels.
//
// ONE light source, from above. The shadow is CUT off the TOP edge always (so
// nothing casts upward — every panel reads with the same downward light) AND off
// the ATTACHED edge (so its blur tucks under the opaque panel instead of bleeding
// a dark line into the bar/strip seam). What's left is a soft downward drop on the
// free lower edges. Gated on shadowStrength → flat mode drops it.
//
// Place as a sibling BEHIND the panel's Shape. For panels whose root IS the shadow's
// parent (popups, BarPanel) just set `side` + `perpInset` + `cornerRadius`; the size
// defaults to the parent. For the Strip (shadow is a sibling of a separately-placed
// card) pass panelX/Y/W/H explicitly and bind opacity/visible to the card.
RectangularShadow {
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
    readonly property int _cL: Math.max(_vert ? 0 : perpInset, side === "left"   ? attachCut : 0)
    readonly property int _cR: Math.max(_vert ? 0 : perpInset, side === "right"  ? attachCut : 0)
    readonly property int _cT: Math.max(_vert ? perpInset : 0, attachCut)
    readonly property int _cB: Math.max(_vert ? perpInset : 0, side === "bottom" ? attachCut : 0)

    x: panelX + _cL
    y: panelY + _cT
    width:  panelW - _cL - _cR
    height: panelH - _cT - _cB
    radius: cornerRadius
    blur:   16
    spread: 0
    offset: Qt.vector2d(0, 5)
    color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
}
