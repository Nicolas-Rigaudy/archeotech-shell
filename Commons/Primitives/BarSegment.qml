import QtQuick
import ".." as Commons

// Bar-cluster housing (Grimdark console language) — the approved media-readout
// look, single-sourced so every bar cluster matches: a soft chamfered recessed
// steel plate (no raised top-light + faint seat, so it delineates without popping
// off the bar face) with ONE domed copper rivet per side, vertically centred,
// bolting it on. Pack-gated via Appearance.frameChamfer; zero-cost on base/glass
// packs. Drop in behind a cluster's content with `anchors.fill: parent` (z below
// the content); the host pads its content so the readout sits balanced between the
// rivets.
Item {
    id: seg
    property int chamfer: 6
    readonly property bool _on: Commons.Appearance.frameChamfer
    readonly property string _pack:  Commons.Appearance.activePackDir
    readonly property string _rivet: _pack === "" ? "" : "file://" + _pack + "panels/rivet.png"

    // Vertical inset from the holder edges (the plate's top/bottom margin). Small,
    // so the box is tall within the 30px bar and the content (icons ≈18px, clock
    // text) keeps real vertical breathing room inside it.
    property int vMargin: 2
    MetalSurface {
        id: plate
        anchors.fill: parent
        anchors.topMargin: seg.vMargin
        anchors.bottomMargin: seg.vMargin
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        visible: seg._on
        chamfer: seg.chamfer
        // Subtle framing: no raised top-light, faint seat — a segment on the bar
        // face, not a card that pops off it. The brass hairline does the delineating.
        topLit: false
        seatOpacity: 0.35
    }

    // One domed copper rivet per side, vertically centred — bolts the housing on.
    Repeater {
        model: (seg._on && seg._rivet !== "") ? ["left", "right"] : []
        delegate: Image {
            required property var modelData
            z: 1
            source: seg._rivet
            width: 6; height: 6; sourceSize: Qt.size(12, 12); smooth: true
            x: modelData === "left" ? plate.x + 4
                                    : plate.x + plate.width - width - 4
            y: plate.y + (plate.height - height) / 2
        }
    }
}
