import QtQuick

// Shared snap-to-centre carousel — the wallpaper / theme / logo pickers all use
// this so they feel identical. The CENTRED item is the focus: delegates read
// `PathView.isCurrentItem` to enlarge/emphasise, and scrolling brings the next
// item to centre (that's the "preview as you scroll"). Only a handful of
// delegates are ever materialised (cacheItemCount), so it stays light and opens
// instantly no matter how many items exist. Callers set `model` + `delegate`
// (and `slotWidth` / a Layout height). Based on Caelestia's WallpaperList.
PathView {
    id: root

    // X-distance between adjacent item centres. Set it a bit below the item
    // width for a slight overlap of the enlarged centre onto its neighbours.
    property int itemSpacing: 170
    readonly property int _half: itemSpacing * pathItemCount / 2

    pathItemCount: Math.max(1, Math.min(5, count))
    cacheItemCount: 4
    snapMode: PathView.SnapToItem
    highlightRangeMode: PathView.StrictlyEnforceRange
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    interactive: true
    clip: false

    // Straight horizontal track centred on the view; items advance by exactly
    // `itemSpacing`. z peaks at the middle so the enlarged current item overlaps
    // its neighbours cleanly.
    path: Path {
        startX: root.width / 2 - root._half
        startY: root.height / 2
        PathAttribute { name: "z"; value: 0 }
        PathLine { x: root.width / 2; relativeY: 0 }
        PathAttribute { name: "z"; value: 2 }
        PathLine { x: root.width / 2 + root._half; relativeY: 0 }
        PathAttribute { name: "z"; value: 0 }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (d < 0) root.incrementCurrentIndex()
            else       root.decrementCurrentIndex()
            event.accepted = true
        }
    }
}
