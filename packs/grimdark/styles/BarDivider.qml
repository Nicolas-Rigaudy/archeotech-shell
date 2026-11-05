import QtQuick

// Grimdark: seam hardware on the bar's zone dividers (adr_027 Layer C style
// delegate for BarDivider). The core draws the groove; this bolts a copper
// rivet pair onto the plate either side, inset 4px from the bar edges so they
// clear the frame bezel. Positioned on the groove's x (the host has no width).
Item {
    id: div
    property var api: ({})
    readonly property url _rivet: Qt.resolvedUrl("../panels/rivet.png")

    // left-plate rivets
    Image { source: div._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: -9; y: 4 }
    Image { source: div._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: -9; y: div.height - 11 }
    // right-plate rivets
    Image { source: div._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: 3; y: 4 }
    Image { source: div._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: 3; y: div.height - 11 }
}
