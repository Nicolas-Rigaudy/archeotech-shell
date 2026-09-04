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

    // Steel pack (Grimdark): the selected pill is a raised machined-steel key
    // edged with the teal live-line (the "cyan pinpoint = this is live"), not a
    // copper wash. Base packs keep the accent pill.
    readonly property bool _steel: Commons.Appearance.frameChamfer
    readonly property color _teal: Commons.Appearance.colors.teal

    readonly property color _cu: Commons.Appearance.colors.peach

    Rectangle {
        id: track
        anchors.fill: parent
        // Steel: a recessed machined slot — dark seat, square-ish corners, copper
        // hairline frame. Base packs keep the soft sunk rounded track.
        radius: root._steel ? 1 : Commons.Appearance.radius.base
        color: root._steel ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.22)
        border.width: root._steel ? 1 : 0
        border.color: root._steel ? Qt.rgba(root._cu.r, root._cu.g, root._cu.b, 0.35) : "transparent"
        readonly property real _segW: root.model.length > 0 ? width / root.model.length : width

        // top inner shadow line → reads as recessed into the plate (not a flat box)
        Rectangle {
            visible: root._steel
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 2; rightMargin: 2; topMargin: 1 }
            height: 1; color: Qt.rgba(0, 0, 0, 0.55)
        }

        RectangularShadow {                 // soft drop shadow — base packs only (reads "modern" on steel)
            anchors.fill: pill
            visible: root.model.length > 0 && !root._steel
            radius: pill.radius
            blur:   14
            offset: Qt.vector2d(0, 3)
            spread: 0
            color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
        }
        Rectangle {                         // hard dark seat under the key — machined depth, not a soft glow
            visible: root._steel && root.model.length > 0
            x: pill.x; y: pill.y + 1.5; width: pill.width; height: pill.height
            radius: pill.radius; color: Commons.Appearance.steel.edge
        }
        Rectangle {
            id: pill
            visible: root.model.length > 0
            width:  track._segW - 8
            height: track.height - 8
            y: 4
            x: root.currentIndex * track._segW + 4
            // Square-cut machined key on steel; rounded pill on base packs.
            radius: root._steel ? 1 : track.radius - 3
            border.width: root._steel ? 1.2 : 0
            // Selected key = lit copper edge (the register metal). Teal dropped — read too modern.
            border.color: root._steel ? Qt.lighter(Commons.Appearance.colors.accent, 1.25) : "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: root._steel ? Qt.lighter(Commons.Appearance.steel.hi, 1.18)
                                                                  : Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, 1.18) }
                GradientStop { position: 0.5; color: root._steel ? Commons.Appearance.steel.md : Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, 1.18) }
                GradientStop { position: 1.0; color: root._steel ? Commons.Appearance.steel.lo
                                                                  : Commons.Appearance.sheenLo(Commons.Appearance.colors.accent, 1.12) }
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
                        color: seg._on ? (root._steel ? Commons.Appearance.colors.text : Commons.Appearance.colors.base)
                                       : Commons.Appearance.colors.subtext0
                        font.pixelSize: 14; font.family: Commons.Appearance.font.family
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                    Text {
                        visible: !root.iconOnly && !!seg.modelData.label
                        text: seg.modelData.label || ""
                        color: seg._on ? (root._steel ? Commons.Appearance.colors.text : Commons.Appearance.colors.base)
                                       : Commons.Appearance.colors.subtext0
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
