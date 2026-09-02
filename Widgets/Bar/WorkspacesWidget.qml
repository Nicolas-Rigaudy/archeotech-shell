import QtQuick
import QtQuick.Layouts
import "../../Commons" as Commons
import "../../Commons/Primitives" as Prim
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
    // Bolted console segment (steel pack, horizontal bar) — pad the dot grid so it
    // sits balanced inside the housing, clear of the end rivets.
    readonly property bool _seg: _horizontal && holderRoot._consoleOn === true
        && Commons.Appearance.frameChamfer
    readonly property int _pad: _seg ? 16 : 0
    implicitWidth:  grid.implicitWidth + 2 * _pad
    // Fill the bar height on a horizontal bar so the housing is a real box around
    // the dots (was grid height ≈ 8px → a sliver clipped behind the pills).
    implicitHeight: _horizontal ? Commons.Appearance.bar.height : grid.implicitHeight
    Layout.alignment: _horizontal ? Qt.AlignVCenter : Qt.AlignHCenter

    Prim.BarSegment { z: -1; visible: root._seg; anchors.fill: parent }

    Grid {
        id: grid
        anchors.centerIn: parent
        rows:    root._horizontal ? 1 : -1   // -1 = auto (one row / one column)
        columns: root._horizontal ? -1 : 1
        spacing: 4

        Repeater {
            model: CompositorServices.MangoWC.tagsFor(root.holderRoot && root.holderRoot.screen ? root.holderRoot.screen.name : "")
            delegate: Rectangle {
                id: pillDot
                required property var modelData
                property bool sel: modelData.selected
                property bool occ: modelData.occupied
                property bool urg: modelData.urgent
                readonly property int _long: sel ? 22 : (occ ? 8 : 6)
                width:  root._horizontal ? _long : 8
                height: root._horizontal ? 8 : _long
                radius: Commons.Appearance.radius.pill
                antialiasing: true
                readonly property color _base: (urg && !sel) ? Commons.Appearance.colors.red
                     : sel ? Commons.Appearance.colors.accent
                     : occ ? Commons.Appearance.colors.surface1
                     :       Commons.Appearance.colors.surface0
                // NMM shading is PACK-SCOPED: only a pack shipping metal plating
                // (Appearance.panelPlate) opts in — the base/glass shell keeps its
                // original flat pill. When off, every stop is the base colour, so
                // the gradient renders identical to the old flat fill.
                readonly property bool _metal: Commons.Appearance.panelPlate !== "" && !Commons.Appearance.depthFlat
                color: _base
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: pillDot._metal ? Qt.lighter(pillDot._base, 1.35) : pillDot._base }
                    GradientStop { position: 0.24; color: pillDot._metal ? Qt.lighter(pillDot._base, 1.95) : pillDot._base }
                    GradientStop { position: 0.55; color: pillDot._base }
                    GradientStop { position: 1.0;  color: pillDot._metal ? Qt.darker(pillDot._base, 2.05) : pillDot._base }
                }
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
