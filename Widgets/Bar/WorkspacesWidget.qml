import QtQuick
import QtQuick.Layouts
import "../../Commons" as Commons
import "../../Services/Compositor" as CompositorServices

// Tag dots for the focused screen. Click to switch tag. Row on a horizontal
// bar, column on a vertical one — the selected pill elongates along the bar
// axis either way (no text, so no rotation concern).
Item {
    id: root
    required property var holderRoot
    property string widgetId

    readonly property bool _horizontal: holderRoot && holderRoot.horizontal
    visible: holderRoot
    implicitWidth:  grid.implicitWidth
    implicitHeight: grid.implicitHeight
    Layout.alignment: _horizontal ? Qt.AlignVCenter : Qt.AlignHCenter

    Grid {
        id: grid
        anchors.centerIn: parent
        rows:    root._horizontal ? 1 : -1   // -1 = auto (one row / one column)
        columns: root._horizontal ? -1 : 1
        spacing: 4

        Repeater {
            model: CompositorServices.MangoWC.tagsFor(root.holderRoot && root.holderRoot.screen ? root.holderRoot.screen.name : "")
            delegate: Rectangle {
                required property var modelData
                property bool sel: modelData.selected
                property bool occ: modelData.occupied
                property bool urg: modelData.urgent
                readonly property int _long: sel ? 22 : (occ ? 8 : 6)
                width:  root._horizontal ? _long : 8
                height: root._horizontal ? 8 : _long
                radius: Commons.Appearance.radius.pill
                color: (urg && !sel) ? Commons.Appearance.colors.red
                     : sel ? Commons.Appearance.colors.accent
                     : occ ? Commons.Appearance.colors.surface1
                     :       Commons.Appearance.colors.surface0
                Behavior on width  { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on height { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on color  { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                MouseArea {
                    anchors.fill: parent
                    onClicked: CompositorServices.MangoWC.switchTag(
                        root.holderRoot.screen ? root.holderRoot.screen.name : "", modelData.num)
                }
            }
        }
    }
}
