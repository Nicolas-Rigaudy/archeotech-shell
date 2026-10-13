import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence

// Sprint 26 — free-text config field. Used by ConfigForm for schema type
// "string". Emits `edited` on each keystroke so config writes stay live.
Item {
    id: root
    property string label: ""
    property string description: ""
    // item_138: search anchor + reset to default (see RowLabel / SearchTarget).
    // A config.json-backed row just sets configKey (a key with a default in
    // ConfigDefaults.js): search key, ↺ state and the reset all follow from it.
    // autoReset: false keeps the ↺ but leaves the reset to the onReset handler
    // (for a service that must apply the change itself).
    property string configKey: ""
    property bool autoReset: true
    property string searchKey: configKey
    property bool modified: configKey !== "" && Persistence.Config.isModified(configKey)
    property string resetHint: "Reset to default"
    signal reset()
    onReset: if (configKey !== "" && autoReset) Persistence.Config.reset(configKey)
    property string text: ""
    property string placeholder: ""
    signal edited(string value)
    signal accepted(string value)   // Enter pressed
    function clear() { field.clear() }
    // What the field shows right now (user edits included).
    readonly property alias value: field.text

    implicitHeight: description ? 68 : 52
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: Commons.Appearance.spacing.xl

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLabel {
                Layout.fillWidth: true
                text: root.label
                modified: root.modified
                resetHint: root.resetHint
                onReset: root.reset()
            }

            Text {
                visible: root.description !== ""
                text: root.description
                color: Commons.Appearance.colors.textMuted
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
            }
        }

        TextField {
            id: field
            Layout.preferredWidth: 160
            text: root.text
            placeholderText: root.placeholder
            color: Commons.Appearance.colors.textPrimary
            placeholderTextColor: Commons.Appearance.colors.textMuted
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.family: Commons.Appearance.font.family
            leftPadding: Commons.Appearance.spacing.s2; rightPadding: Commons.Appearance.spacing.s2

            background: Rectangle {
                radius: Commons.Appearance.radius.base
                color: field.activeFocus ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.base
                border.color: field.activeFocus ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface1
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
            }

            onTextEdited: root.edited(text)
            onAccepted:   root.accepted(text)
        }
    }

    SearchTarget { key: root.searchKey; target: root }
}
