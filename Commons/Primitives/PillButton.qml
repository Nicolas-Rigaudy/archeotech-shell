import QtQuick
import QtQuick.Controls
import ".." as Commons

Button {
    property bool   active: false
    property string label: ""

    implicitHeight: 28
    implicitWidth: labelText.implicitWidth + 24

    background: Rectangle {
        radius: Commons.Appearance.radius.base
        antialiasing: true
        color: parent.active ? Commons.Appearance.colors.accent
                             : (parent.hovered ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.surface0Alpha)
        border.color: parent.active ? Commons.Appearance.colors.accent : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
    }

    contentItem: Text {
        id: labelText
        text: parent.label
        color: parent.active ? Commons.Appearance.colors.base : Commons.Appearance.colors.text
        font.pixelSize: Commons.Appearance.font.sizeSm
        font.family: Commons.Appearance.font.family
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
    }
}
