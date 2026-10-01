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
        anchors { fill: parent; leftMargin: Commons.Appearance.spacing.s7; rightMargin: Commons.Appearance.spacing.s7; topMargin: Commons.Appearance.spacing.s5; bottomMargin: Commons.Appearance.spacing.s4 }
        spacing: Commons.Appearance.spacing.s5

        Text {
            text: icon
            color: Commons.Appearance.colors.accent
            font.pixelSize: Commons.Appearance.font.size6xl
            font.family: Commons.Appearance.font.family
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                text: title
                color: Commons.Appearance.colors.textPrimary
                font.pixelSize: Commons.Appearance.font.sizeTitle
                // Display face (adr_027 font hook) — a pack's header font when it
                // ships one; the body family otherwise.
                font.family: Commons.Appearance.font.display
                font.weight: Commons.Appearance.font.weightBold
            }

            Text {
                text: description
                color: Commons.Appearance.colors.textSecondary
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
