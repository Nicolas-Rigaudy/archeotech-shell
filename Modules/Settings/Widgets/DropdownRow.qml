import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Commons" as Commons

Item {
    id: root
    property string label: ""
    property string description: ""
    property var options: []    // list of { value: string, label: string }
    property string currentValue: ""
    signal selected(string value)

    implicitHeight: description ? 56 : 40
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: Commons.Appearance.spacing.xl

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
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

        ComboBox {
            id: combo
            model: root.options.map(o => o.label)
            currentIndex: {
                for (var i = 0; i < root.options.length; i++) {
                    if (root.options[i].value === root.currentValue) return i
                }
                return 0
            }
            onActivated: root.selected(root.options[currentIndex].value)

            background: Rectangle {
                radius: Commons.Appearance.radius.base
                color: combo.hovered ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.base
                border.color: Commons.Appearance.colors.surface1
                border.width: 1
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
            }

            contentItem: Text {
                leftPadding: 8; rightPadding: 8
                text: combo.displayText
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
