import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import ".." as Commons

// The shell's tooltip: a small glass card (same surface, border and shadow
// language as the dropdown list) with one line of text, fading in after a short
// delay. Use this instead of a stock QtQuick.Controls ToolTip, whose platform
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

    background: Item {
        RectangularShadow {
            anchors.fill: card
            radius: card.radius
            blur:   Commons.Appearance.elevation.e2.blur
            offset: Qt.vector2d(0, Commons.Appearance.elevation.e2.y)
            spread: Commons.Appearance.elevation.e2.spread
            color:  Commons.Appearance.elevation.e2.color
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: Commons.Appearance.radius.base
            color: Commons.Appearance.colors.glassBg
            border.width: 1
            border.color: Commons.Appearance.colors.glassBorder
        }
    }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Commons.Appearance.anim.fast } }
    exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Commons.Appearance.anim.fast } }
}
