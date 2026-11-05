import QtQuick
import ".." as Commons

// Pack-aware chrome surface: the shared background for cards/panels/pills so the
// material propagates from one place. Three looks, picked by the active pack:
//
//   • Pack style delegate (`<pack>/styles/MetalSurface.qml`, e.g. Grimdark's
//     welded steel plate): replaces the whole visual; `styled` tells hosts the
//     delegate draws its own seat/rim.
//   • 9-slice plate (pack ships panels.surface) — legacy BorderImage.
//   • Plain themed rect (base/glass packs).
Item {
    id: surf
    property color color:  Commons.Appearance.colors.surfaceCard   // fallback fill
    property real  radius: Commons.Appearance.radius.md
    property int   slice:  12                                       // 9-slice border inset
    // Corner cut for a delegate that chamfers (clamped by the delegate to half
    // the smaller side).
    property int   chamfer: 7
    // Recessed-seat weight (0..1) for a delegate that draws a seat outline: full
    // for big cards; dial down for a bar readout that should sit flush.
    property real  seatOpacity: 1.0
    // Top-lit highlight; off for a small housing that must blend with the bar face.
    property bool  topLit: true
    // Crisp (non-anti-aliased) outline, for a surface whose edge meets nothing
    // under layer blur (Appearance.crispEdges; the tooltip). Cards keep false.
    property bool  crisp: false

    // A pack style draws this surface (hosts drop their own glass rim on it).
    readonly property bool styled: style.active

    readonly property string _plate: Commons.Appearance.panelPlate

    Rectangle {                         // fallback — no pack chrome
        anchors.fill: parent
        visible: surf._plate === "" && !surf.styled
        radius: surf.radius
        antialiasing: !surf.crisp
        // item_050: top-lit sheen on the card's OWN fill (same colour, lighter top →
        // darker bottom) so nested cards read as lit glass like the panels behind
        // them; collapses to a flat slab in depthFlat via sheenHi/Lo.
        gradient: Gradient {
            // Surface-tier sheen on the card's OWN fill (shared sheen scale). A flush
            // housing (topLit:false) collapses both stops to the base so it sits
            // flush with the bar face rather than popping off it.
            GradientStop { position: 0.0; color: surf.topLit ? Commons.Appearance.sheenHi(surf.color, Commons.Appearance.sheen.surface.hi) : surf.color }
            GradientStop { position: 1.0; color: surf.topLit ? Commons.Appearance.sheenLo(surf.color, Commons.Appearance.sheen.surface.lo) : surf.color }
        }
    }
    BorderImage {                       // legacy 9-slice plate
        anchors.fill: parent
        visible: surf._plate !== "" && !surf.styled
        source: surf._plate
        border { left: surf.slice; top: surf.slice; right: surf.slice; bottom: surf.slice }
    }

    StyleDelegate {
        id: style
        anchors.fill: parent
        componentId: "MetalSurface"
        api: ({
            "radius":      surf.radius,
            "chamfer":     surf.chamfer,
            "seatOpacity": surf.seatOpacity,
            "topLit":      surf.topLit,
            "crisp":       surf.crisp,
            "color":       surf.color,
            "palette":     Commons.Appearance.colors,
            "steel":       Commons.Appearance.steel
        })
    }
}
