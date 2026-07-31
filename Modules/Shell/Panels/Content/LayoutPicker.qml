import QtQuick
import "../../../../Widgets/Appearance" as Appearance

// Tiling-layout picker panel (Super+Shift+T). Thin wrapper: the grid of layout
// cards lives in LayoutPickerBody (the same Widgets/Appearance home as the
// wallpaper/theme picker bodies). Orientation follows the holder so it works
// from a bar or a strip on any side.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot: null

    readonly property bool _panelHorizontal:
        !panelRoot ? true
        : panelRoot._horizontal !== undefined ? panelRoot._horizontal
        : panelRoot.horizontal  !== undefined ? panelRoot.horizontal
        : true
    readonly property bool _vertical: !_panelHorizontal
    // Along-strip extent for axisSize:"auto" — wide enough for ~5 cards per row
    // horizontally; narrower (single column of cards) when vertical.
    readonly property real implicitAxis: _vertical ? 380 : 900

    Appearance.LayoutPickerBody {
        anchors.fill: parent
        panelRoot: root.panelRoot
        vertical: root._vertical
    }
}
