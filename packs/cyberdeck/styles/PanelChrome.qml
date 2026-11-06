pragma ComponentBehavior: Bound
import QtQuick
import "parts"

// Cyberdeck Netrunner: strip panel body (adr_027 Layer C delegate for
// PanelChrome). A dark plate with a teal hairline, both corners away from the
// strip cut at 45°; the strip-attached edge stays open so the panel reads as
// docked into the frame.
Item {
    id: pc
    property var api: ({})
    property string register: ""

    readonly property var  _p: api.palette
    readonly property string _s: api.side || "bottom"
    // bodyRect stops a neck-fillet short of the strip (the core sheen fills
    // that with curves); this plate has no fillets, so its open strip edge
    // runs on to the card edge, else the wallpaper shows in between. One px
    // more reaches under the frame rule (FrameStyle draws it 1 px outside the
    // hole).
    readonly property rect _b: {
        const b = api.bodyRect || Qt.rect(0, 0, width, height)
        if (_s === "bottom") return Qt.rect(b.x, b.y, b.width, height + 1 - b.y)
        if (_s === "top")    return Qt.rect(b.x, -1, b.width, b.y + b.height + 1)
        if (_s === "left")   return Qt.rect(-1, b.y, b.x + b.width + 1, b.height)
        return Qt.rect(b.x, b.y, width + 1 - b.x, b.height)
    }
    readonly property real _c: Math.min(22, _b.width / 4, _b.height / 4)

    // Points walk the body clockwise from the strip edge's first corner; the
    // two far corners are cut.
    readonly property var _pts: {
        const x0 = _b.x + 0.75, y0 = _b.y + 0.75
        const x1 = _b.x + _b.width - 0.75, y1 = _b.y + _b.height - 0.75, c = _c
        if (_s === "bottom") return [Qt.point(x0, y1), Qt.point(x0, y0 + c), Qt.point(x0 + c, y0),
                                     Qt.point(x1 - c, y0), Qt.point(x1, y0 + c), Qt.point(x1, y1)]
        if (_s === "top")    return [Qt.point(x1, y0), Qt.point(x1, y1 - c), Qt.point(x1 - c, y1),
                                     Qt.point(x0 + c, y1), Qt.point(x0, y1 - c), Qt.point(x0, y0)]
        if (_s === "left")   return [Qt.point(x0, y0), Qt.point(x1 - c, y0), Qt.point(x1, y0 + c),
                                     Qt.point(x1, y1 - c), Qt.point(x1 - c, y1), Qt.point(x0, y1)]
        return [Qt.point(x1, y1), Qt.point(x0 + c, y1), Qt.point(x0, y1 - c),
                Qt.point(x0, y0 + c), Qt.point(x0 + c, y0), Qt.point(x1, y0)]
    }

    CutPlate {
        anchors.fill: parent
        colors: pc._p
        points: pc._pts
    }
}
