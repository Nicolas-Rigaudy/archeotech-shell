import QtQuick
import QtQuick.Layouts
import ".." as Commons

// The shell's one separator (panel frames, rows inside cards, popups), owner
// pick 2026-10-15: a soft recessed channel, a 3 px shade falling off away from
// the light and a 1 px lit lip. Light comes from the top-left, so the shade sits
// on the top/left side and the lip on the bottom/right. Flat mode drops the
// depth to a single 1 px shade line.
//
//   Prim.Divider { }                  // horizontal, fills the layout width
//   Prim.Divider { vertical: true }   // between side-by-side regions
Item {
    id: root
    property bool vertical: false

    readonly property bool _flat: Commons.Appearance.depthFlat
    readonly property int _t: _flat ? 1 : 4
    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    Layout.preferredWidth: vertical ? _t : -1
    Layout.preferredHeight: vertical ? -1 : _t
    implicitWidth: vertical ? _t : 0
    implicitHeight: vertical ? 0 : _t

    readonly property bool _light: Commons.Appearance.isLight
    readonly property color _shade: _light ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(0, 0, 0, 0.42)
    readonly property color _lit:   _light ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.10)

    Rectangle {                      // the shade, fading away from the light
        width:  root.vertical ? (root._flat ? 1 : 3) : root.width
        height: root.vertical ? root.height : (root._flat ? 1 : 3)
        color: root._flat ? root._shade : "transparent"
        gradient: root._flat ? null : shadeRamp
        Gradient {
            id: shadeRamp
            orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical
            GradientStop { position: 0.0; color: root._shade }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {                      // the lit lip
        visible: !root._flat
        x: root.vertical ? 3 : 0
        y: root.vertical ? 0 : 3
        width:  root.vertical ? 1 : root.width
        height: root.vertical ? root.height : 1
        color: root._lit
    }
}
