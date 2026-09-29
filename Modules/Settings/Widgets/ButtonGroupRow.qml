import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"

Item {
    id: root
    property string label: ""
    property string description: ""
    property var options: []    // list of { value: string, label: string }
    property string currentValue: ""
    signal selected(string value)

    implicitHeight: _col.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 6

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.label !== "" || root.description !== ""
            spacing: 2

            Text {
                visible: root.label !== ""
                text: root.label
                color: Commons.Appearance.colors.textPrimary
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
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
}
