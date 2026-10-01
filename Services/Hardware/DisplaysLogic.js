.pragma library
// Pure display-layout helpers (item_135), shared by Displays.qml, the Settings
// arrangement canvas and the qmltestrunner tests (tests/qml). No Quickshell
// imports, so it is testable outside the shell.
//
// An output is { name, make, model, serial, description, enabled, x, y, width,
// height, refresh, transform, scale, modes: [{width, height, refresh, preferred}] }
// in wlr-randr terms: width/height/refresh = the current mode in physical px.

// `wlr-randr --json` text → outputs[] (or null when it is not a JSON array).
function parse(text) {
    var data
    try { data = JSON.parse(text) } catch (e) { return null }
    if (!Array.isArray(data)) return null
    var out = []
    for (var i = 0; i < data.length; i++) {
        var o = data[i]
        var cur = null, modes = []
        for (var j = 0; j < (o.modes || []).length; j++) {
            var m = o.modes[j]
            modes.push({ width: m.width, height: m.height, refresh: m.refresh, preferred: !!m.preferred })
            if (m.current) cur = m
        }
        // A disabled output may report no current mode: fall back to its native one.
        if (!cur) cur = modes.filter(function (m) { return m.preferred })[0] || modes[0] || null
        out.push({
            name: o.name, make: o.make || "", model: o.model || "", serial: o.serial || "",
            description: o.description || o.name,
            enabled: !!o.enabled,
            x: (o.position && o.position.x) || 0, y: (o.position && o.position.y) || 0,
            width: cur ? cur.width : 0, height: cur ? cur.height : 0,
            refresh: cur ? cur.refresh : 0,
            transform: o.transform || "normal", scale: o.scale || 1,
            modes: modes
        })
    }
    return out
}

function rotated(transform) { return /90|270/.test(transform || "") }

// Size an output occupies in the layout (logical px): 90/270 swap w/h, scale divides.
function logicalSize(o) {
    var w = o.width, h = o.height
    if (rotated(o.transform)) { var t = w; w = h; h = t }
    var s = o.scale > 0 ? o.scale : 1
    return { w: Math.round(w / s), h: Math.round(h / s) }
}

// One wlr-randr argv for every output, so the layout changes atomically.
// A 0 Hz refresh (virtual/headless outputs) means "unspecified": omitted.
function argv(list) {
    var a = ["wlr-randr"]
    for (var i = 0; i < list.length; i++) {
        var o = list[i]
        a.push("--output", o.name)
        if (!o.enabled) { a.push("--off"); continue }
        a.push("--on")
        if (o.width > 0 && o.height > 0)   // no known mode: let the compositor pick
            a.push("--mode", o.width + "x" + o.height + (o.refresh > 0 ? "@" + Number(o.refresh).toFixed(3) + "Hz" : ""))
        a.push("--pos", Math.round(o.x) + "," + Math.round(o.y),
               "--transform", o.transform,
               "--scale", String(o.scale))
    }
    return a
}

// Shift the enabled outputs so the layout starts at 0,0 (returns a new list).
function normalize(list) {
    var next = JSON.parse(JSON.stringify(list))
    var on = next.filter(function (o) { return o.enabled })
    if (!on.length) return next
    var mx = Math.min.apply(null, on.map(function (o) { return o.x }))
    var my = Math.min.apply(null, on.map(function (o) { return o.y }))
    on.forEach(function (o) { o.x -= mx; o.y -= my })
    return next
}

function _overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}
function _alignAxis(v, len, lo, olen, align) {
    // Snap a free coordinate to the neighbour's start / end / centre when close.
    var c = [lo, lo + olen - len, lo + (olen - len) / 2]
    for (var i = 0; i < c.length; i++) if (Math.abs(v - c[i]) <= align) return c[i]
    return v
}

// Where output `name` lands when dropped at logical (px, py): flush against the
// nearest side of another enabled output, sliding along that edge, edges aligned
// within `align` px, never overlapping anything. A lone output goes to 0,0.
function snap(list, name, px, py, align) {
    if (align === undefined) align = 64
    var me = null, others = []
    for (var i = 0; i < list.length; i++) {
        var o = list[i]
        if (!o.enabled) continue
        var s = logicalSize(o)
        var r = { x: o.x, y: o.y, w: s.w, h: s.h }
        if (o.name === name) me = r; else others.push(r)
    }
    if (!me) return { x: px, y: py }
    if (!others.length) return { x: 0, y: 0 }
    var best = null, bestD = 1e18
    for (var j = 0; j < others.length; j++) {
        var O = others[j]
        var ySlide = Math.max(O.y - me.h + 1, Math.min(O.y + O.h - 1, py))
        var xSlide = Math.max(O.x - me.w + 1, Math.min(O.x + O.w - 1, px))
        var cands = [
            { x: O.x - me.w, y: _alignAxis(ySlide, me.h, O.y, O.h, align) },   // left of O
            { x: O.x + O.w,  y: _alignAxis(ySlide, me.h, O.y, O.h, align) },   // right of O
            { x: _alignAxis(xSlide, me.w, O.x, O.w, align), y: O.y - me.h },   // above O
            { x: _alignAxis(xSlide, me.w, O.x, O.w, align), y: O.y + O.h }     // below O
        ]
        for (var k = 0; k < cands.length; k++) {
            var c = { x: Math.round(cands[k].x), y: Math.round(cands[k].y), w: me.w, h: me.h }
            var clash = false
            for (var m = 0; m < others.length && !clash; m++) clash = _overlaps(c, others[m])
            if (clash) continue
            var d = (c.x - px) * (c.x - px) + (c.y - py) * (c.y - py)
            if (d < bestD) { bestD = d; best = c }
        }
    }
    return best ? { x: best.x, y: best.y } : { x: me.x, y: me.y }
}

// True when two enabled outputs overlap (a layout Apply should refuse).
function hasOverlap(list) {
    var r = list.filter(function (o) { return o.enabled }).map(function (o) {
        var s = logicalSize(o); return { x: o.x, y: o.y, w: s.w, h: s.h }
    })
    for (var i = 0; i < r.length; i++)
        for (var j = i + 1; j < r.length; j++)
            if (_overlaps(r[i], r[j])) return true
    return false
}
