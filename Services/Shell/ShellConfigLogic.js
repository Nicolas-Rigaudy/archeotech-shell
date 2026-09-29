.pragma library
// Pure shell-config normalisation, shared by ShellConfig.qml and the qmltestrunner
// tests (tests/qml). No Quickshell imports: Quickshell's QML types live inside the
// qs binary, so anything that must be unit-tested outside the shell goes here.

// Per-instance widget entry: { id, config }. A bare string id is the legacy form
// (pre-S26 shell-config.json); normalise on read so both forms load.
function normEntry(e) {
    if (typeof e === "string") return { id: e, config: {} }
    if (e && typeof e === "object") return { id: e.id, config: e.config || {} }
    return { id: "", config: {} }
}

// Content entry: { id, config, align }. `align` is the bar zone
// ("left"|"center"|"right"); "" is the strip/holder icon list.
function normContentEntry(e, defAlign) {
    var n = normEntry(e)
    var a = (e && typeof e === "object" && e.align !== undefined) ? e.align : defAlign
    return { id: n.id, config: n.config, align: a }
}

// A side as one ordered content list. Reads `content` if present, else flattens
// the legacy `zones{left,center,right}` (bar) / `icons[]` (strip) layout.
function sideContent(s) {
    if (!s) return []
    if (s.content) return s.content.map(function(e) { return normContentEntry(e, "") })
    var out = []
    if (s.zones) {
        var order = ["left", "center", "right"]
        for (var i = 0; i < order.length; i++) {
            var z = s.zones[order[i]] || []
            for (var j = 0; j < z.length; j++) out.push(normContentEntry(z[j], order[i]))
        }
    }
    if (s.icons)
        for (var k = 0; k < s.icons.length; k++) out.push(normContentEntry(s.icons[k], ""))
    return out
}

// Stable regroup: bar zones clustered (left, center, right), then the strip list
// ("") and anything else in original order. filter() preserves order.
function regroup(content) {
    var order = ["left", "center", "right"]
    var out = []
    for (var i = 0; i < order.length; i++)
        out = out.concat(content.filter(function(e) { return e.align === order[i] }))
    return out.concat(content.filter(function(e) { return order.indexOf(e.align) === -1 }))
}

// Resolve one side: the global definition (or the default, or type "none"),
// shallow-overridden key by key by a per-screen entry when there is one.
function resolveSide(data, defaults, name, screenName) {
    var base = (data.sides && data.sides[name]) || defaults.sides[name] || { type: "none" }
    var ps = screenName && data.perScreen && data.perScreen[screenName]
    var override = ps && ps.sides && ps.sides[name]
    if (!override) return base
    var merged = {}
    for (var k in base) merged[k] = base[k]
    for (var k2 in override) merged[k2] = override[k2]
    return merged
}
