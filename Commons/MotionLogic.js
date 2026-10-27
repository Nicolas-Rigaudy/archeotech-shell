.pragma library
// Motion scaling (item_114): the animation-scale and reduced-motion settings
// applied to a duration in ms. Pure, so tests/qml/tst_motionlogic.qml covers it.
//
// scale     0 = animations off, 1 = as designed, up to 2 (clamped; NaN = 1).
// reduced   "reduce motion": spatial motion (slides, pops, morphs) becomes instant
//           while effects (fades, colour) keep their duration, the usual accessible
//           substitute for movement.
// Infinite spinners and countdowns are state indicators, not decoration: they do
// not go through here (Commons.Spin uses an unscaled token).

var MAX_SCALE = 2

function clampScale(v) {
    var n = Number(v)
    if (isNaN(n)) return 1
    return Math.max(0, Math.min(MAX_SCALE, n))
}

function effects(ms, scale) {
    return Math.round(ms * clampScale(scale))
}

function spatial(ms, scale, reduced) {
    return reduced ? 0 : effects(ms, scale)
}
