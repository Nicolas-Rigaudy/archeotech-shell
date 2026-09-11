import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
            model: CompositorServices.CompositorService.tagsFor(root.holderRoot && root.holderRoot.screen ? root.holderRoot.screen.name : "")
            delegate: Item {
                id: cell
                required property var modelData
                property bool sel: modelData.selected
                property bool occ: modelData.occupied
                property bool urg: modelData.urgent
                // Sized + coloured so all three states read at a glance: empty is a
                // small dim + matte bead (surface1, no gloss — see specular below),
                // occupied jumps brighter and glossy (overlay1) so "has windows"
                // reads on both brightness and sheen, selected elongates into the
                // accent pill.
                readonly property int _long: sel ? 22 : (occ ? 9 : 7)
                width:  root._horizontal ? _long : 8
                height: root._horizontal ? 8 : _long
                readonly property color _base: (urg && !sel) ? Commons.Appearance.colors.red
                     : sel ? Commons.Appearance.colors.accent
                     : occ ? Commons.Appearance.colors.overlay1
                     :       Commons.Appearance.colors.surface1
                // NMM shading is PACK-SCOPED: only a pack shipping metal plating
                // (Appearance.panelPlate) opts in. The base/glass shell gets a real
                // raised-glass read instead: drop shadow + top-lit sheen + a specular
                // gloss cap. depthFlat mode drops all depth cues to a flat bead.
                readonly property bool _metal: Commons.Appearance.panelPlate !== "" && !Commons.Appearance.depthFlat
                readonly property bool _glass: !Commons.Appearance.depthFlat && !_metal

                Behavior on width  { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on height { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                // Soft shadow lifts every bead off the bar face (glass mode) — this
                // is what delineates the dim empty beads, no hard outline needed.
                RectangularShadow {
                    anchors.fill: pill
                    radius: pill.radius
                    blur:   6
                    offset: Qt.vector2d(0, 1)
                    spread: 0
                    visible: cell._glass
                    color:  Qt.rgba(0, 0, 0, (cell.sel ? 0.5 : cell.occ ? 0.45 : 0.28) * Commons.Appearance.shadowStrength)
                }

                Rectangle {
                    id: pill
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.pill
                    antialiasing: true
                    color: cell._base
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: cell._metal ? Qt.lighter(cell._base, 1.35) : cell._glass ? Commons.Appearance.sheenHi(cell._base, Commons.Appearance.sheen.knob.hi) : cell._base }
                        GradientStop { position: 0.24; color: cell._metal ? Qt.lighter(cell._base, 1.95) : cell._glass ? Commons.Appearance.sheenHi(cell._base, Commons.Appearance.sheen.knob.hi) : cell._base }
                        GradientStop { position: 0.55; color: cell._base }
                        GradientStop { position: 1.0;  color: cell._metal ? Qt.darker(cell._base, 2.05) : cell._glass ? Commons.Appearance.sheenLo(cell._base, Commons.Appearance.sheen.knob.lo) : cell._base }
                    }
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                    // Specular gloss cap — only the "active" beads (occupied +
                    // selected) get it, so a matte empty bead reads clearly distinct
                    // from a glossy occupied one. Gentle, to avoid a plasticky sheen.
                    Rectangle {
                        visible: cell._glass && (cell.sel || cell.occ)
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
                        height: Math.max(2, Math.round(parent.height * 0.5))
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, cell.sel ? 0.30 : 0.16) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: CompositorServices.CompositorService.switchTag(
                        root.holderRoot.screen ? root.holderRoot.screen.name : "", modelData.num)
                }
            }
        }
    }
}
