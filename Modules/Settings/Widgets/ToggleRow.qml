import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"

Item {
    id: root
    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled(bool value)

    implicitHeight: description ? 56 : 44
    Layout.fillWidth: true

    ColumnLayout {
        anchors {
            left: parent.left
            right: toggle.left
            rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
            text: root.label
            color: Commons.Appearance.colors.text
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.family: Commons.Appearance.font.family
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            visible: root.description !== ""
            text: root.description
            color: Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ToggleSwitch {
        id: toggle
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        checked: root.checked
        onToggled: state => root.toggled(state)
    }
}
