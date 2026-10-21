.pragma library
// Timing for EntranceStagger (Commons/Primitives/EntranceStagger.qml): item i of
// a panel starts its entrance `baseDelay + i*step` ms after the panel mounts.

function clamp01(v) { return Math.max(0, Math.min(1, v)) }

function startDelay(index, step, baseDelay) {
    return Math.max(0, baseDelay) + Math.max(0, index) * Math.max(0, step)
}

// Total time until the last of `count` items has finished its `duration`.
function totalTime(count, step, baseDelay, duration) {
    return startDelay(Math.max(0, count - 1), step, baseDelay) + duration
}

// Remaining pixel offset for entrance progress p (0 = fresh, 1 = settled).
function offset(progress, distance) {
    return (1 - clamp01(progress)) * distance
}
