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
    property string resetHint: "Reset to " + _optionLabel(configKey !== "" ? String(Persistence.Config.defaultFor(configKey)) : "", "default")
    signal reset()
    function _optionLabel(value, fallback) {
        for (var i = 0; i < options.length; i++) if (options[i].value === value) return options[i].label
        return fallback
    }
    onReset: if (configKey !== "" && autoReset) Persistence.Config.reset(configKey)
    property var options: []    // list of { value: string, label: string }
    property string currentValue: ""
    signal selected(string value)

    implicitHeight: _col.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Commons.Appearance.spacing.s2

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.label !== "" || root.description !== ""
            spacing: 2
            RowLabel {
                visible: root.label !== ""
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

        // Pick-one-of-N → the shared SegmentedControl, so settings selectors speak
        // the same language as the page/mode/flavor toggles (recessed track + raised
        // accent pill + base-glyph active) instead of a row of separate GlassButtons.
        // The public API stays value-keyed; map value↔index at the boundary.
        SegmentedControl {
            Layout.preferredWidth: Math.min(120 * root.options.length, 480)
            Layout.preferredHeight: 30
            model: root.options    // items are { value, label } — label is read, value ignored
            currentIndex: Math.max(0, root.options.findIndex(function(o) { return o.value === root.currentValue }))
            onActivated: index => root.selected(root.options[index].value)
        }
    }

    SearchTarget { key: root.searchKey; target: root }
}
