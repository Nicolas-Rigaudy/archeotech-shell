import QtQuick
import QtQuick.Controls
import ".." as Commons

Item {
    property bool checked: false
    signal toggled(bool state)

    implicitWidth: 40
    implicitHeight: 22

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: parent.checked ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface0

        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

        Rectangle {
            width: 16; height: 16; radius: 8
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: parent.parent.checked ? parent.width - width - 3 : 3
            color: parent.parent.checked ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext0

            Behavior on x     { NumberAnimation { duration: Commons.Appearance.anim.fast; easing.type: Easing.InOutQuad } }
            Behavior on color { ColorAnimation   { duration: Commons.Appearance.anim.fast } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: { parent.checked = !parent.checked; parent.toggled(parent.checked) }
    }
}
