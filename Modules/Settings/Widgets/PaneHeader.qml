import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

Item {
    property string icon: ""
    property string title: ""
    property string description: ""

    implicitHeight: 88
    Layout.fillWidth: true

    RowLayout {
        anchors { fill: parent; leftMargin: 28; rightMargin: 28; topMargin: 20; bottomMargin: 16 }
        spacing: 18

        Text {
            text: icon
            color: Commons.Appearance.colors.accent
            font.pixelSize: 30
            font.family: Commons.Appearance.font.family
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                text: title
                color: Commons.Appearance.colors.text
                font.pixelSize: 18
                font.family: Commons.Appearance.font.family
                font.weight: Font.Bold
            }

            Text {
                text: description
                color: Commons.Appearance.colors.subtext0
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
