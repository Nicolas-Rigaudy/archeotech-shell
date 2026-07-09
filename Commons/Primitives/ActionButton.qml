import QtQuick
import QtQuick.Controls
import ".." as Commons

Button {
    property string iconName: ""
    property string label: ""

    implicitWidth: 68
    implicitHeight: 56

    background: Rectangle {
        radius: Commons.Appearance.radius.md
        color: parent.hovered ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.surface0Alpha
        border.color: parent.hovered ? Commons.Appearance.colors.accent : "transparent"
        border.width: 1

        Behavior on color        { ColorAnimation { duration: Commons.Appearance.anim.fast } }
        Behavior on border.color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
    }

    contentItem: Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.parent.iconName
            color: Commons.Appearance.colors.text
            font.pixelSize: 18
            font.family: Commons.Appearance.font.family
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.parent.label
            color: Commons.Appearance.colors.subtext0
            font.pixelSize: 10
            font.family: Commons.Appearance.font.family
        }
    }
}
