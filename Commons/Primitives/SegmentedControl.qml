import QtQuick
import QtQuick.Effects
import ".." as Commons

// Segmented control — the shell's pick-one-of-N control (page selectors, mode
// toggles). N equal segments sit in one recessed track (sunk rgba language,
// like the SliderRow / stat bars); a raised accent pill slides to the selected
// segment with a top-lit gradient + lift shadow (gated on shadowStrength so it
// flattens in flat mode). Inactive segments take a StateLayer hover wash; the
// active label/glyph flips to `base` (dark) over the accent, matching the
// shell's "accent fill + base glyph" focal language.
//
// model items are { label, glyph } (either may be omitted). Bind `currentIndex`
// to your own state and update it in `onActivated` — the control is stateless.
// `iconOnly` collapses to glyphs for narrow side panels.
Item {
    id: root

    property var  model: []
    property int  currentIndex: 0
    property bool iconOnly: false
    signal activated(int index)

    implicitHeight: 30

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Commons.Appearance.radius.base
        color: Qt.rgba(0, 0, 0, 0.22)
        readonly property real _segW: root.model.length > 0 ? width / root.model.length : width

        RectangularShadow {
            anchors.fill: pill
            visible: root.model.length > 0
            radius: pill.radius
            blur:   14
            offset: Qt.vector2d(0, 3)
            spread: 0
            color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
        }
        Rectangle {
            id: pill
            visible: root.model.length > 0
            width:  track._segW - 8
            height: track.height - 8
            y: 4
            x: root.currentIndex * track._segW + 4
            radius: track.radius - 3
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(Commons.Appearance.colors.accent, 1.18) }
                GradientStop { position: 1.0; color: Qt.darker(Commons.Appearance.colors.accent, 1.12) }
            }
            Behavior on x { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
        }

        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool _on: root.currentIndex === index
                property bool _hov: false
                x: index * track._segW
                width: track._segW
                height: track.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: track.radius - 3
                    color: (seg._hov && !seg._on) ? Commons.Appearance.colors.stateHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        visible: !!seg.modelData.glyph
                        text: seg.modelData.glyph || ""
                        color: seg._on ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext0
                        font.pixelSize: 14; font.family: Commons.Appearance.font.family
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                    Text {
                        visible: !root.iconOnly && !!seg.modelData.label
                        text: seg.modelData.label || ""
                        color: seg._on ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext0
                        font.pixelSize: Commons.Appearance.font.sizeBase
                        font.family: Commons.Appearance.font.family
                        font.weight: seg._on ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: seg._hov = true
                    onExited:  seg._hov = false
                    onClicked: root.activated(seg.index)
                }
            }
        }
    }
}
