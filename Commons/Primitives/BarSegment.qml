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
    // Which bar cluster this plate houses ("bank", "clock", "media", "title",
    // "workspaces"), so a pack can style clusters differently (item_156), and
    // whether the bar runs vertically (left/right side).
    property string cluster: ""
    property bool vertical: false

    api: ({
        "chamfer": seg.chamfer,
        "vMargin": seg.vMargin,
        "cluster": seg.cluster,
        "vertical": seg.vertical,
        "palette": Commons.Appearance.colors,
        "steel":   Commons.Appearance.steel
    })
}
