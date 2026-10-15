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
//   Prim.Divider { thin: true }       // between rows of a dense list: the same
//                                     // shade + lip, 1 px of shade instead of 3
Item {
    id: root
    property bool vertical: false
    property bool thin: false

    readonly property bool _flat: Commons.Appearance.depthFlat
    readonly property int _sh: _flat || thin ? 1 : 3    // shade depth
    readonly property int _t: _flat ? 1 : _sh + 1
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
        width:  root.vertical ? root._sh : root.width
        height: root.vertical ? root.height : root._sh
        color: root._sh === 1 ? root._shade : "transparent"
        gradient: root._sh === 1 ? null : shadeRamp
        Gradient {
            id: shadeRamp
            orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical
            GradientStop { position: 0.0; color: root._shade }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {                      // the lit lip
        visible: !root._flat
        x: root.vertical ? root._sh : 0
        y: root.vertical ? 0 : root._sh
        width:  root.vertical ? 1 : root.width
        height: root.vertical ? root.height : 1
        color: root._lit
    }
}
