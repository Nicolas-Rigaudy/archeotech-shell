import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import ".." as Commons

Item {
    id: root
    property bool checked: false
    signal toggled(bool state)

    implicitWidth: 40
    implicitHeight: 22

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        // Off = recessed groove (dark top lip shadow → lit bottom floor);
        // on = raised accent track with a gentle top sheen.
        gradient: root.checked ? onGrad : offGrad
        border.width: 1
        border.color: root.checked ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0

        Behavior on border.color { Commons.ColorAnim {} }

        Gradient {
            id: onGrad
            GradientStop { position: 0.0; color: Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.hi) }
            GradientStop { position: 1.0; color: Commons.Appearance.sheenLo(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.lo) }
        }
        Gradient {
            id: offGrad
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.26) }
            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.03) }
        }

        // Thumb shadow — raised knob "pops" off the track.
        RectangularShadow {
            anchors.fill: thumb
            radius: thumb.radius
            blur:   7
            offset: Qt.vector2d(0, 1.5)
            spread: 0
            color:  Qt.rgba(0, 0, 0, 0.55 * Commons.Appearance.shadowStrength)
        }

        Rectangle {
            id: thumb
            width: 16; height: 16; radius: 8
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3

            // Raised sphere — top-lit gradient reads as a 3d knob.
            readonly property color _knob: root.checked ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Commons.Appearance.sheenHi(thumb._knob, Commons.Appearance.sheen.knob.hi) }
                GradientStop { position: 1.0; color: Commons.Appearance.sheenLo(thumb._knob, Commons.Appearance.sheen.knob.lo) }
            }

            // Press-pulse — depress then spring back (M3 spatial curve).
            scale: ma.pressed ? 0.92 : 1.0

            Behavior on x     { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
            Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked) }
    }
}
