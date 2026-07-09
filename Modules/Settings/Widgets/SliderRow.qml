import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Commons" as Commons

Item {
    id: root
    property string label: ""
    property string description: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property string valueDisplay: Math.round(value * 100) + "%"
    signal moved(real value)

    implicitHeight: description ? 80 : 62
    Layout.fillWidth: true

    ColumnLayout {
        anchors { fill: parent; topMargin: 8; bottomMargin: 8 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
                Layout.fillWidth: true
            }

            Text {
                text: root.valueDisplay
                color: Commons.Appearance.colors.subtext1
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
            }
        }

        Text {
            visible: root.description !== ""
            text: root.description
            color: Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            padding: 0

            background: Rectangle {
                x: 0
                y: (slider.height - height) / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: Commons.Appearance.colors.surface1

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Commons.Appearance.colors.accent
                }
            }

            handle: Rectangle {
                x: slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 16; height: 16; radius: 8
                color: slider.pressed ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
            }

            onMoved: root.moved(value)
        }
    }
}
