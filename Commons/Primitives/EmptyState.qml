import QtQuick
import QtQuick.Layouts
import ".." as Commons

// Subtle empty-state for panels with no current content.
// Used by NotificationCenter ("No notifications"), Launcher recents row,
// and future "no devices" cases in CC. icon + title; optional hint line.
Item {
    id: root
    property string icon:     ""
    property string title:    ""
    property string hint:     ""
    property int    iconSize: 30

    implicitHeight: col.implicitHeight + 24

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.icon.length > 0
            text:    root.icon
            color:   Commons.Appearance.colors.surface1
            font.pixelSize: root.iconSize
            font.family:    Commons.Appearance.font.family
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.title.length > 0
            text:    root.title
            color:   Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.family:    Commons.Appearance.font.family
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hint.length > 0
            text:    root.hint
            color:   Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family:    Commons.Appearance.font.family
            opacity: 0.7
        }
    }
}
