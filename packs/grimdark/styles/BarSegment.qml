import QtQuick

// Grimdark: bar-cluster housing (adr_027 Layer C style delegate for BarSegment),
// the approved media-readout look shared by every bar cluster: a soft chamfered
// recessed steel plate (no raised top-light, faint seat, so it delineates
// without popping off the bar face) with ONE domed copper rivet per side,
// vertically centred, bolting it on. Reuses this pack's MetalSurface delegate
// (same directory). No Commons import: everything arrives through `api`.
Item {
    id: seg
    property var api: ({})

    readonly property int _vMargin: api.vMargin !== undefined ? api.vMargin : 2

    MetalSurface {
        id: plate
        anchors.fill: parent
        anchors.topMargin: seg._vMargin
        anchors.bottomMargin: seg._vMargin
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        // Subtle framing: no raised top-light, faint seat; the copper hairline
        // does the delineating.
        api: ({
            "chamfer":     seg.api.chamfer !== undefined ? seg.api.chamfer : 6,
            "topLit":      false,
            "seatOpacity": 0.35,
            "palette":     seg.api.palette,
            "steel":       seg.api.steel
        })
    }

    // One domed copper rivet per side, vertically centred.
    Repeater {
        model: ["left", "right"]
        delegate: Image {
            required property var modelData
            z: 1
            source: Qt.resolvedUrl("../panels/rivet.png")
            width: 6; height: 6; sourceSize: Qt.size(12, 12); smooth: true
            x: modelData === "left" ? plate.x + 4
                                    : plate.x + plate.width - width - 4
            y: plate.y + (plate.height - height) / 2
        }
    }
}
