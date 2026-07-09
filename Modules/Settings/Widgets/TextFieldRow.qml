import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Commons" as Commons

// Sprint 26 — free-text config field. Used by ConfigForm for schema type
// "string". Emits `edited` on each keystroke so config writes stay live.
Item {
    id: root
    property string label: ""
    property string description: ""
    property string text: ""
    property string placeholder: ""
    signal edited(string value)

    implicitHeight: description ? 68 : 52
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

        TextField {
            id: field
            Layout.preferredWidth: 160
            text: root.text
            placeholderText: root.placeholder
            color: Commons.Appearance.colors.text
            placeholderTextColor: Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.family: Commons.Appearance.font.family
            leftPadding: 8; rightPadding: 8

            background: Rectangle {
                radius: Commons.Appearance.radius.base
                color: field.activeFocus ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.base
                border.color: field.activeFocus ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface1
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
            }

            onTextEdited: root.edited(text)
        }
    }
}
