import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence
import "../../../Commons/Primitives"

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
    property string resetHint: "Reset to " + (configKey !== "" ? (Persistence.Config.defaultFor(configKey) ? "on" : "off") : "default")
    signal reset()
    onReset: if (configKey !== "" && autoReset) Persistence.Config.reset(configKey)
    property bool checked: false
    signal toggled(bool value)

    implicitHeight: description ? 56 : 44
    Layout.fillWidth: true

    ColumnLayout {
        anchors {
            left: parent.left
            right: toggle.left
            rightMargin: Commons.Appearance.spacing.s4
            verticalCenter: parent.verticalCenter
        }
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
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ToggleSwitch {
        id: toggle
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        checked: root.checked
        onToggled: state => root.toggled(state)
    }

    SearchTarget { key: root.searchKey; target: root }
}
