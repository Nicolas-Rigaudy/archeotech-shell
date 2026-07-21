import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"

Item {
    id: root
    property string label: ""
    property string description: ""
    property var options: []    // list of { value: string, label: string }
    property string currentValue: ""
    signal selected(string value)

    implicitHeight: _col.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 6

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.label !== "" || root.description !== ""
            spacing: 2

            Text {
                visible: root.label !== ""
                text: root.label
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
            }

            Text {
                visible: root.description !== ""
                text: root.description
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
            }
        }

        Flow {
            spacing: 4
            Layout.fillWidth: true

            Repeater {
                model: root.options
                delegate: GlassButton {
                    required property var modelData
                    text: modelData.label
                    active: modelData.value === root.currentValue
                    onClicked: root.selected(modelData.value)
                }
            }
        }
    }
}
