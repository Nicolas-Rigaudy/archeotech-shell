.pragma library
// Palette crossfade maths (item_009): pure helpers behind Appearance's theme
// crossfade, so tests/qml/tst_palettelogic.qml covers them without a compositor.
// Colours are theme.json strings: "#rgb", "#rrggbb" or Qt's "#aarrggbb". Anything
// else (a named colour, garbage) cannot be mixed and snaps to the target.

function parse(c) {
    if (typeof c !== "string") return null
    var m = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(c)
    if (!m) return null
    var h = m[1]
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
    var a = 1
    if (h.length === 8) { a = parseInt(h.substr(0, 2), 16) / 255; h = h.substr(2) }
    return { r: parseInt(h.substr(0, 2), 16), g: parseInt(h.substr(2, 2), 16),
             b: parseInt(h.substr(4, 2), 16), a: a }
}

function _hex2(v) {
    var s = Math.max(0, Math.min(255, Math.round(v))).toString(16)
    return s.length < 2 ? "0" + s : s
}

function format(c) {
    var rgb = _hex2(c.r) + _hex2(c.g) + _hex2(c.b)
    return c.a >= 0.999 ? "#" + rgb : "#" + _hex2(c.a * 255) + rgb
}

// from -> to at t (0 = from, 1 = to), per channel in sRGB like a Qt colour animation.
function blend(from, to, t) {
    if (t >= 1) return to
    var a = parse(from), b = parse(to)
    if (!a || !b) return to
    if (t <= 0) return from
    return format({ r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t,
                    b: a.b + (b.b - a.b) * t, a: a.a + (b.a - a.a) * t })
}

// True when two theme.json colour maps differ in any key.
function differs(a, b) {
    var ca = (a && a.colors) || {}, cb = (b && b.colors) || {}
    var k
    for (k in ca) if (ca[k] !== cb[k]) return true
    for (k in cb) if (!(k in ca)) return true
    return false
}
