import QtQuick
import QtQuick.Effects
import ".." as Commons

// Unified button for the shell's liquid-glass / 3d aesthetic. Depth comes from a
// soft drop shadow (like the cards / stat bars) + a GENTLE top-lit gradient —
// not a heavy gloss (that reads as wet plastic). No hard specular line.
//   • resting: raised surfaceCard gradient + glassBorder
//   • active/selected: gentle accent gradient + accent border
//   • StateLayer hover-wash / press-depress
// Text-only via `text`, or drop custom content (icon+label) as a child.
//
// Layer C (adr_027): the CHROME (shadow + rounded surface) is a curated style
// seam — a theme pack may replace it via `<packDir>/styles/GlassButton.qml`
// (StyleDelegate). Behaviour/props/slots and the content+interaction layer stay
// in this base component; only the resting background is delegated. With no pack
// delegate the base visual below draws exactly as before.
Item {
    id: btn
    // Consumer children (icon+label) land in the centered content Row; or just
    // set `text` for a plain label button.
    default property alias content: contentSlot.data
    property string text: ""
    property bool   active: false
    property real   hpad: 14
    readonly property alias hovered: layer.hovered
    readonly property alias pressed: layer.pressed
    signal clicked()

    implicitWidth:  (label.visible ? label.implicitWidth : contentSlot.implicitWidth) + hpad * 2
    implicitHeight: 30

    // Press-depress / hover scale is applied to the whole button (chrome+content)
    // by the StateLayer below, so the base and any pack delegate scale together.
    Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }

    // ── Chrome: base visual (hidden when a pack style delegate is loaded) ────────
    RectangularShadow {
        anchors.fill: bg
        visible: !styleDelegate.active
        radius: bg.radius
        blur:   10
        offset: Qt.vector2d(0, 3)
        spread: 0
        color:  Qt.rgba(0, 0, 0, 0.5 * Commons.Appearance.shadowStrength)
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        visible: !styleDelegate.active
        radius: Commons.Appearance.radius.base
        antialiasing: true
        border.width: 1
        border.color: btn.active ? Commons.Appearance.colors.accent : Commons.Appearance.colors.glassBorder
        gradient: Gradient {
            GradientStop { position: 0.0; color: btn.active ? Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.hi) : Commons.Appearance.sheenHi(Commons.Appearance.colors.surfaceCard, Commons.Appearance.sheen.surface.hi) }
            GradientStop { position: 1.0; color: btn.active ? Commons.Appearance.sheenLo(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.lo) : Commons.Appearance.sheenLo(Commons.Appearance.colors.surfaceCard, Commons.Appearance.sheen.surface.lo) }
        }
        Behavior on border.color { Commons.ColorAnim {} }
    }

    // ── Chrome: pack style delegate (replaces the base visual when present) ──────
    StyleDelegate {
        id: styleDelegate
        anchors.fill: parent
        componentId: "GlassButton"
        // Versioned prop contract (docs/STYLE_API.md). Colours are passed IN so the
        // pack delegate stays theme-driven without importing Commons (it can't —
        // it lives outside the shell tree). Add fields over time, never remove.
        api: ({
            "active":  btn.active,
            "hovered": btn.hovered,
            "pressed": btn.pressed,
            "text":    btn.text,
            "radius":  Commons.Appearance.radius.base,
            "colors": {
                "accent":  Commons.Appearance.colors.accent,
                "surface": Commons.Appearance.colors.surfaceCard,
                "border":  Commons.Appearance.colors.glassBorder,
                "text":    Commons.Appearance.colors.textSecondary,
                "base":    Commons.Appearance.colors.base,
                "teal":    Commons.Appearance.colors.teal,
                // Flat welded-steel family (matches the frame); pack delegates
                // render machined-steel chrome from these instead of importing Commons.
                "steelHi":   Commons.Appearance.steel.hi,
                "steelMd":   Commons.Appearance.steel.md,
                "steelLo":   Commons.Appearance.steel.lo,
                "steelEdge": Commons.Appearance.steel.edge,
                "steelLip":  Commons.Appearance.steel.lip,
                "chamfer":   Commons.Appearance.frameChamfer
            }
        })
    }

    // ── Content + interaction (always base, on top of the chrome) ────────────────
    Row {
        id: contentSlot
        anchors.centerIn: parent
    }

    Text {
        id: label
        visible: btn.text !== ""
        anchors.centerIn: parent
        text: btn.text
        // Active text: dark `base` reads on the base accent fill, but the steel
        // pack's active chrome is dark steel + a teal edge → use light text there.
        color: btn.active ? (Commons.Appearance.frameChamfer ? Commons.Appearance.colors.textPrimary
                                                             : Commons.Appearance.colors.base)
                          : Commons.Appearance.colors.textSecondary
        font.pixelSize: Commons.Appearance.font.sizeSm
        font.family: Commons.Appearance.font.family
        Behavior on color { Commons.ColorAnim {} }
    }

    StateLayer {
        id: layer
        anchors.fill: parent
        radius: Commons.Appearance.radius.base   // match the button corners (parent is an Item, no radius)
        pressScale: 0.96
        scaleTarget: btn
        onClicked: btn.clicked()
    }
}
