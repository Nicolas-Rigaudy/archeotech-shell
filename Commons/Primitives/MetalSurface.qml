import QtQuick
import QtQuick.Shapes
import ".." as Commons

// Pack-aware chrome surface — the shared background for cards/panels/pills so the
// material propagates from one place. Three looks, picked by the active pack:
//
//   • Flat welded steel (Grimdark / any chamfer+matte pack) — a machined
//     plate: top-lit steel gradient, 45° chamfered corners matching the frame, a
//     dark seat outline (reads as recessed into the panel) + a brass hairline
//     trim inset from the edge. Single-sources its tones from Appearance.steel,
//     so it stays welded to the frame bezel (FrameFx) rather than re-hardcoded.
//   • 9-slice plate (pack ships panels.surface, no chamfer) — legacy BorderImage.
//   • Plain themed rect (base/glass packs) — completely unaffected.
Item {
    id: surf
    property color color:  Commons.Appearance.colors.surfaceCard   // fallback fill
    property real  radius: Commons.Appearance.radius.md
    property int   slice:  12                                       // 9-slice border inset
    // Chamfer size for the steel look — clamped to half the smaller side so small
    // cards don't over-cut. Tracks the frame's cornerRadius feel, a touch smaller.
    property int   chamfer: 7
    // Recessed-seat weight (0..1) — the dark outline that makes a card read as
    // sunk into the panel. Full for big cards; dial down for a light bar readout
    // that should sit flush with the frame face, not pop off it.
    property real  seatOpacity: 1.0
    // Top-lit highlight — a raised specular band at the top of the plate. Right
    // for cards; off for a small housing that must blend with the bar face.
    property bool  topLit: true

    readonly property string _plate: Commons.Appearance.panelPlate
    readonly property bool   _steel: Commons.Appearance.frameChamfer
    readonly property int    _c:     Math.max(2, Math.min(chamfer, Math.min(width, height) / 2))

    Rectangle {                         // fallback — no metal pack
        anchors.fill: parent
        visible: surf._plate === "" && !surf._steel
        radius: surf.radius
        antialiasing: true
        // item_050: top-lit sheen on the card's OWN fill (same colour, lighter top →
        // darker bottom) so nested cards read as lit glass like the panels behind
        // them; collapses to a flat slab in depthFlat via sheenHi/Lo.
        gradient: Gradient {
            // Surface-tier sheen on the card's OWN fill (shared sheen scale). Honour
            // topLit like the steel path: a flush housing (topLit:false, e.g.
            // BarSegment) collapses both stops to the base so it sits flush with the
            // bar face rather than popping off it.
            GradientStop { position: 0.0; color: surf.topLit ? Commons.Appearance.sheenHi(surf.color, Commons.Appearance.sheen.surface.hi) : surf.color }
            GradientStop { position: 1.0; color: surf.topLit ? Commons.Appearance.sheenLo(surf.color, Commons.Appearance.sheen.surface.lo) : surf.color }
        }
    }
    BorderImage {                       // legacy 9-slice plate (plate pack, no chamfer)
        anchors.fill: parent
        visible: surf._plate !== "" && !surf._steel
        source: surf._plate
        border { left: surf.slice; top: surf.slice; right: surf.slice; bottom: surf.slice }
    }

    // ── Flat welded steel plate ──────────────────────────────────────────────
    Shape {
        id: plate
        anchors.fill: parent
        visible: surf._steel
        preferredRendererType: Shape.CurveRenderer
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
        // Inset outline (1.5px in) for the brass hairline trim.
        readonly property real   _i: 1.5
        readonly property string _inPath:
              "M " + c + " " + _i
            + " L " + (w - c) + " " + _i + " L " + (w - _i) + " " + c
            + " L " + (w - _i) + " " + (h - c) + " L " + (w - c) + " " + (h - _i)
            + " L " + c + " " + (h - _i) + " L " + _i + " " + (h - c)
            + " L " + _i + " " + c + " Z"

        ShapePath {                         // steel face — top-lit, dark seat outline
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: plate.h
                GradientStop { position: 0.00; color: surf.topLit ? Commons.Appearance.steel.hi : Commons.Appearance.steel.md }
                GradientStop { position: 0.28; color: Commons.Appearance.steel.md }
                GradientStop { position: 1.00; color: Commons.Appearance.steel.lo }
            }
            // dark seat — reads recessed; seatOpacity dials its weight
            strokeColor: Qt.rgba(Commons.Appearance.steel.edge.r, Commons.Appearance.steel.edge.g,
                                 Commons.Appearance.steel.edge.b, surf.seatOpacity)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: plate._path }
        }
        ShapePath {                         // brass hairline trim, inset from the edge
            fillColor: "transparent"
            // Lit copper to match the frame trim's peachy read (was flat peach α0.30).
            strokeColor: Qt.rgba(Commons.Appearance.colors.copperLit.r, Commons.Appearance.colors.copperLit.g,
                                 Commons.Appearance.colors.copperLit.b, 0.5)
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            PathSvg { path: plate._inPath }
        }
    }
}
