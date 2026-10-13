import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"

// A settings row's label with its reset control (item_138): a small muted ↺
// right after the text, only while the value differs from its default
// (`modified`). Hover names the default ("Reset to 5 s"); a click emits reset().
RowLayout {
    id: root
    property string text: ""
    property bool modified: false
    property string resetHint: "Reset to default"
    signal reset()

    spacing: Commons.Appearance.spacing.s2

    Text {
        id: label
        text: root.text
        color: Commons.Appearance.colors.textPrimary
        font.pixelSize: Commons.Appearance.font.sizeBase
        font.family: Commons.Appearance.font.family
        elide: Text.ElideRight
        Layout.maximumWidth: root.width - (root.modified ? resetBtn.width + root.spacing : 0)
    }

    Rectangle {
        id: resetBtn
        visible: root.modified
        // Text height, so showing it never changes the row's height.
        Layout.preferredWidth: 22; Layout.preferredHeight: label.implicitHeight
        Layout.alignment: Qt.AlignVCenter
        radius: Commons.Appearance.radius.base
        color: "transparent"
        Text {
            anchors.centerIn: parent
            text: "↺"
            color: resetLayer.hovered ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textMuted
            font.pixelSize: Commons.Appearance.font.sizeMd
            font.family: Commons.Appearance.font.family
        }
        StateLayer { id: resetLayer; anchors.fill: parent; onClicked: root.reset() }
        // Built only while hovered: no tooltip object per row otherwise.
        Loader {
            active: resetLayer.hovered
            sourceComponent: Tooltip { parent: resetBtn; visible: true; text: root.resetHint }
        }
    }

    // Keeps the ↺ next to the text, not pushed to the far edge.
    Item { Layout.fillWidth: true }
}
