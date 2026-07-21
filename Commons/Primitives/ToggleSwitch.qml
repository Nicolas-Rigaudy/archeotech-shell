import QtQuick
import QtQuick.Controls
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
        color: root.checked ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface0
        // Pill outline so the off-state track still reads as a switch on glass.
        border.width: 1
        border.color: root.checked ? "transparent" : Commons.Appearance.colors.overlay1

        Behavior on color { Commons.ColorAnim {} }
        Behavior on border.color { Commons.ColorAnim {} }

        Rectangle {
            id: thumb
            width: 16; height: 16; radius: 8
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext0

            // Press-pulse — thumb depresses then springs back (M3 spatial curve).
            scale: ma.pressed ? 0.92 : 1.0

            Behavior on x     { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
            Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
            Behavior on color { Commons.ColorAnim {} }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked) }
    }
}
