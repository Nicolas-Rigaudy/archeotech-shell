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

    RectangularShadow {
        anchors.fill: bg
        radius: bg.radius
        blur:   10
        offset: Qt.vector2d(0, 3)
        spread: 0
        color:  Qt.rgba(0, 0, 0, 0.5)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Commons.Appearance.radius.base
        antialiasing: true
        border.width: 1
        border.color: btn.active ? Commons.Appearance.colors.accent : Commons.Appearance.colors.glassBorder

        gradient: Gradient {
            GradientStop { position: 0.0; color: btn.active ? Qt.lighter(Commons.Appearance.colors.accent, 1.08) : Qt.lighter(Commons.Appearance.colors.surfaceCard, 1.12) }
            GradientStop { position: 1.0; color: btn.active ? Qt.darker(Commons.Appearance.colors.accent, 1.06)  : Commons.Appearance.colors.surfaceCard }
        }

        Behavior on scale        { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
        Behavior on border.color { Commons.ColorAnim {} }

        Row {
            id: contentSlot
            anchors.centerIn: parent
        }

        Text {
            id: label
            visible: btn.text !== ""
            anchors.centerIn: parent
            text: btn.text
            color: btn.active ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext1
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
            Behavior on color { Commons.ColorAnim {} }
        }

        StateLayer {
            id: layer
            anchors.fill: parent
            pressScale: 0.96
            onClicked: btn.clicked()
        }
    }
}
