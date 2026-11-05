import QtQuick
import ".." as Commons

// Bar-cluster housing: a plate behind one bar cluster (workspaces, title, media,
// clock, the right status bank) so the bar reads as separate instrument
// segments. Core has no visual of its own: a pack draws it with a `BarSegment`
// style delegate (Grimdark: a recessed steel plate bolted on with one rivet per
// side). Bar layouts make room for it only while Appearance.hasStyle("BarSegment"),
// padding their content by Appearance.segmentPad(<cluster>). Drop in behind a
// cluster's content with `anchors.fill: parent` (z below the content).
StyleDelegate {
    id: seg
    componentId: "BarSegment"
    property int chamfer: 6
    // Vertical inset from the holder edges (the plate's top/bottom margin).
    property int vMargin: 2

    api: ({
        "chamfer": seg.chamfer,
        "vMargin": seg.vMargin,
        "palette": Commons.Appearance.colors,
        "steel":   Commons.Appearance.steel
    })
}
