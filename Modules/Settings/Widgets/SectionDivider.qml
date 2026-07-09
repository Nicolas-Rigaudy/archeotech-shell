import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

Item {
    property string label: ""
    implicitHeight: 32
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: Commons.Appearance.spacing.base

        Text {
            text: label.toUpperCase()
            color: Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
            font.weight: Font.Medium
            font.letterSpacing: 1
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Commons.Appearance.colors.surface0
        }
    }
}
