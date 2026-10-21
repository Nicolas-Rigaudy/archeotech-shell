.pragma library
// Geometry for OrbitViz (Commons/Primitives/OrbitViz.qml): where each node sits,
// how big it is, and the sine-perturbed "energy strand" between two points.
// Pure functions of (index, time, size) so tests/qml/tst_orbitlogic.qml can pin
// them without a Canvas.

// Fraction of a full turn the whole ring advances per second.
var TURNS_PER_SEC = 0.045

function clamp01(v) { return Math.max(0, Math.min(1, v)) }

// Node i of n on an ellipse around (cx, cy). Nodes start evenly spaced from the
// top and the ring turns slowly with `t` (seconds). `ry` squashes the orbit so a
// wide, short card still reads as a ring seen at an angle.
function nodePos(i, n, t, cx, cy, rx, ry) {
    var a = -Math.PI / 2 + 2 * Math.PI * (i / Math.max(1, n) + t * TURNS_PER_SEC)
    return { x: cx + rx * Math.cos(a), y: cy + ry * Math.sin(a), angle: a }
}

// Node radius grows with its value (0..100) between rMin and rMax.
function nodeRadius(value, rMin, rMax) {
    return rMin + (rMax - rMin) * clamp01(value / 100)
}

// Strand brightness: strong at the core, fading with distance (never fully off).
function strandAlpha(dist, reach, value) {
    var falloff = 1 - clamp01(dist / Math.max(1, reach)) * 0.6
    return clamp01(0.35 + 0.6 * clamp01(value / 100)) * falloff
}

// Points of a strand from (x0,y0) to (x1,y1): a straight line displaced
// sideways by a travelling sine wave. The displacement is zero at both ends
// (so the strand stays glued to core and node) and its amplitude scales with
// `amp`; `seed` de-phases strands from one another.
function strandPoints(x0, y0, x1, y1, t, amp, seed, steps) {
    var dx = x1 - x0, dy = y1 - y0
    var len = Math.sqrt(dx * dx + dy * dy)
    var pts = []
    if (len < 0.001) { pts.push({ x: x0, y: y0 }); return pts }
    var nx = -dy / len, ny = dx / len
    for (var s = 0; s <= steps; s++) {
        var u = s / steps
        var env = Math.sin(Math.PI * u)
        var w = Math.sin(u * 9 - t * 2.4 + seed * 1.7) * 0.7
              + Math.sin(u * 5 + t * 1.3 + seed * 0.9) * 0.3
        var off = amp * env * w
        pts.push({ x: x0 + dx * u + nx * off, y: y0 + dy * u + ny * off })
    }
    return pts
}
