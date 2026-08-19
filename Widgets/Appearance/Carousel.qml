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

    // Distance between adjacent item centres along the track. Set it a bit
    // below the item extent for a slight overlap of the enlarged centre.
    property int itemSpacing: 170
    // vertical: track runs top→bottom (side panels) instead of left→right
    // (top/bottom panels). Callers pass !panelRoot._horizontal.
    property bool vertical: false
    readonly property int _half: itemSpacing * pathItemCount / 2
    // Along-track viewport — height in a side panel, width in a top/bottom bar.
    readonly property real _trackExtent: vertical ? height : width

    // Accumulated scroll delta — touchpads emit many tiny events, so we advance
    // one item only per threshold instead of on every event (that caused jitter).
    property real _wheelAcc: 0

    // Number of on-path tiles. Horizontally the track runs off the left/right
    // SCREEN edges (clip:false, intended peek) so we always want the full 5 —
    // overflow there is harmless. VERTICALLY the top of the track sits under the
    // mode/flavor/accent rows, so an over-long track bleeds up through them; there
    // we cap to what the along-track viewport holds at the natural itemSpacing
    // (short panel → fewer neighbours, spacing unchanged, no overlap).
    // Result MUST stay odd: this is a centre-hero carousel (highlight range 0.5),
    // so an even count pushes the hero off-centre → asymmetric neighbours + a cut
    // edge tile. Round any capped value down to the nearest odd number.
    readonly property int _maxOnPath: {
        var n = Math.min(5, count)
        if (vertical) n = Math.min(n, Math.floor(_trackExtent / itemSpacing))
        if (n % 2 === 0) n -= 1          // even → nearest lower odd
        return Math.max(1, n)
    }
    pathItemCount: _maxOnPath
    cacheItemCount: 4
    snapMode: PathView.SnapToItem
    highlightRangeMode: PathView.StrictlyEnforceRange
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    // Non-interactive: an interactive PathView swallows wheel/touchpad events
    // along its own (horizontal) flick axis before the WheelHandler runs, which
    // is why a side-to-side two-finger swipe did nothing. With flicking off, the
    // WheelHandler below owns all scrolling and drives currentIndex directly
    // (which still animates). Click-to-select in the delegates is unaffected.
    interactive: false
    // Never clip — neighbours peek off the edges (the "cards over the edges"
    // look) in both orientations. In a vertical side panel the top card would
    // peek up over the tabs, so the host draws the tab bar on top with its own
    // backing to occlude just that top edge (the bottom card still peeks).
    clip: false

    // Straight track centred on the view; items advance by exactly
    // `itemSpacing` along the chosen axis. z peaks at the middle so the enlarged
    // current item overlaps its neighbours cleanly.
    readonly property real _cx: width / 2
    readonly property real _cy: height / 2
    path: Path {
        startX: root.vertical ? root._cx : root._cx - root._half
        startY: root.vertical ? root._cy - root._half : root._cy
        PathAttribute { name: "z"; value: 0 }
        PathLine { x: root._cx; y: root._cy }
        PathAttribute { name: "z"; value: 2 }
        PathLine { x: root.vertical ? root._cx : root._cx + root._half
                   y: root.vertical ? root._cy + root._half : root._cy }
        PathAttribute { name: "z"; value: 0 }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            // Scroll on the vertical (y) axis: MangoWC doesn't deliver horizontal
            // two-finger scroll to this layer-shell surface (angleDelta.x is always
            // 0; a side-to-side swipe sends no event at all), so y is the only axis
            // we get — and it drives the strip fine for both mouse and touchpad.
            //
            // A touchpad sends high-res pixelDelta (small, many events, momentum);
            // a mouse sends angleDelta in 120-unit notches. Pick the source, then
            // ACCUMULATE to one item per threshold so a touchpad glides smoothly
            // instead of jumping an item on every micro-event.
            var isTouch = event.pixelDelta.y !== 0
            var dy = isTouch ? event.pixelDelta.y : event.angleDelta.y
            if (dy === 0) return
            if ((dy < 0) !== (root._wheelAcc < 0)) root._wheelAcc = 0   // reset on reverse
            root._wheelAcc += dy

            var step = 120   // touch: ~120px per item · mouse: one 120-unit notch
            while (root._wheelAcc <= -step) { root.incrementCurrentIndex(); root._wheelAcc += step }
            while (root._wheelAcc >=  step) { root.decrementCurrentIndex(); root._wheelAcc -= step }
            event.accepted = true
        }
    }
}
