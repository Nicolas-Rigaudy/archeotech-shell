import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../Services/Shell" as ShellServices

// Sprint 17 Stage 4 — thin transparent PanelWindows that reserve compositor
// exclusiveZone on each side. The full-screen ShellSurface can't claim
// exclusiveZone (it's ExclusionMode.Ignore), so these slim windows do the job.
//
// Each side spawns one PanelWindow per screen, conditional on
// `sides.<name>.type !== "none"`. `exclusiveZone = sideSize + outerGap`:
// the visible bar/strip is `sideSize` wide, the extra `outerGap` is empty
// space between the side and tiled windows — owned by Quickshell instead of
// MangoWC's `gappoh/gappov` (which would multiply between tiled windows too).
Variants {
    model: Quickshell.screens

    delegate: Scope {
        id: _row
        required property var modelData
        readonly property string _name: modelData ? modelData.name : ""

        // A bar/strip claims its full body size; holder/none claim no body. But
        // EVERY edge keeps the breathing gap (_pad) so tiled windows never reach
        // the physical screen edge — an off/holder edge keeps the same clearance
        // a bar/strip would have left (S22 issue 3).
        function _active(side) {
            var t = ShellServices.ShellConfig.sideType(side, _name)
            return t !== "none" && t !== "holder"
        }
        function _zone(side) {
            return (_active(side) ? _size(side) : 0) + _pad()
        }
        function _size(side) {
            return ShellServices.ShellConfig.sideSize(side, _name)
        }
        // Empty space the side owns beyond its body: outerGap always, plus the
        // pillGap in pill mode (the side floats inward, so windows need the same
        // clearance on its inner edge to keep it visually free-floating).
        function _pad() {
            return ShellServices.ShellConfig.outerGap()
                 + (ShellServices.ShellConfig.pillMode() ? ShellServices.ShellConfig.pillGap() : 0)
        }

        // Top
        PanelWindow {
            visible: true
            screen: _row.modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "archeotech-exclude-top"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: _row._zone("top")
            anchors { top: true; left: true; right: true }
            implicitHeight: _row._size("top")
            mask: Region { x: 0; y: 0; width: 0; height: 0 }
        }

        // Bottom
        PanelWindow {
            visible: true
            screen: _row.modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "archeotech-exclude-bottom"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: _row._zone("bottom")
            anchors { bottom: true; left: true; right: true }
            implicitHeight: _row._size("bottom")
            mask: Region { x: 0; y: 0; width: 0; height: 0 }
        }

        // Right
        PanelWindow {
            visible: true
            screen: _row.modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "archeotech-exclude-right"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: _row._zone("right")
            anchors { top: true; bottom: true; right: true }
            implicitWidth: _row._size("right")
            mask: Region { x: 0; y: 0; width: 0; height: 0 }
        }

        // Left
        PanelWindow {
            visible: true
            screen: _row.modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "archeotech-exclude-left"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: _row._zone("left")
            anchors { top: true; bottom: true; left: true }
            implicitWidth: _row._size("left")
            mask: Region { x: 0; y: 0; width: 0; height: 0 }
        }
    }
}
