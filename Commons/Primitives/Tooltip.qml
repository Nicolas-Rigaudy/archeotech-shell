import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import ".." as Commons

// The shell's tooltip: a small lit glass card (the same MetalSurface material,
// glass rim and raised shadow as the settings and dashboard cards) with one line
// of text, fading in after a short delay. Use this instead of a stock QtQuick.Controls ToolTip, whose platform
// look does not belong in the shell (tests/py/test_tooltips.py enforces it).
//
//   Prim.Tooltip { visible: someLayer.hovered; text: "Reset to 5.0s" }
//
// It positions itself above its parent item, centred, like a ToolTip.
ToolTip {
    id: tip
    delay: Commons.Appearance.anim.panel
    margins: Commons.Appearance.spacing.s2
    leftPadding: Commons.Appearance.spacing.s3;  rightPadding: Commons.Appearance.spacing.s3
    topPadding: Commons.Appearance.spacing.s1;   bottomPadding: Commons.Appearance.spacing.s1

    contentItem: Text {
        text: tip.text
        color: Commons.Appearance.colors.textPrimary
        font.pixelSize: Commons.Appearance.font.sizeSm
        font.family: Commons.Appearance.font.family
    }

    // The cards' material (MetalSurface: top-lit sheen on the translucent card
    // fill, the steel plate under a chamfer pack) with a raised e3 shadow and the
    // glass rim, so a tooltip reads as one more lit glass card, not a flat slab.
    background: Item {
        RectangularShadow {
            anchors.fill: surface
            radius: surface.radius
            blur:   Commons.Appearance.elevation.e3.blur
            offset: Qt.vector2d(0, Commons.Appearance.elevation.e3.y)
            spread: Commons.Appearance.elevation.e3.spread
            color:  Commons.Appearance.outerShadowColor(Commons.Appearance.elevation.e3)
        }
        MetalSurface {
            id: surface
            anchors.fill: parent
            radius: Commons.Appearance.radius.base
            chamfer: 4
            crisp: Commons.Appearance.crispEdges
        }
        Rectangle {               // glass rim (the steel plate draws its own seat)
            anchors.fill: parent
            visible: !Commons.Appearance.frameChamfer
            radius: surface.radius
            antialiasing: !Commons.Appearance.crispEdges
            color: "transparent"
            border.width: 1
            border.color: Commons.Appearance.colors.glassBorder
        }
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Commons.Appearance.glassFades ? Commons.Appearance.anim.fast : 0 } }
    exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Commons.Appearance.glassFades ? Commons.Appearance.anim.fast : 0 } }
}
