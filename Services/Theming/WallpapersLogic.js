.pragma library
// Per-screen wallpaper helpers (item_148 wave 2), pure so tests/qml can run them.
//
// config.json `wallpaper`:
//   light / dark      the all-screens image per mode ("" = keep what is on screen)
//   fit / anchor      the all-screens fit (screens of the other orientation)
//   layout            "same" (one image everywhere) | "screens" (an image per screen)
//   screens           { "<output>": { light, dark, fit, anchor } }; a missing or
//                     empty field inherits the all-screens value. Fit and anchor
//                     apply in both layouts; the images only in "screens".

var FITS = ["fill", "blur", "edges"]
var ANCHORS = ["left", "centre", "right"]

function _obj(v) { return v && typeof v === "object" && !Array.isArray(v) ? v : {} }

// One field of one screen's entry ("" when unset).
function screenValue(screens, name, key) {
    var s = _obj(_obj(screens)[name])
    var v = s[key]
    return typeof v === "string" ? v : ""
}

// The fit / anchor a screen uses: its own valid value, else the all-screens one.
function fitOf(fit, screens, name) {
    var own = name ? screenValue(screens, name, "fit") : ""
    if (FITS.indexOf(own) >= 0) return own
    return FITS.indexOf(fit) >= 0 ? fit : "fill"
}
function anchorOf(anchor, screens, name) {
    var own = name ? screenValue(screens, name, "anchor") : ""
    if (ANCHORS.indexOf(own) >= 0) return own
    return ANCHORS.indexOf(anchor) >= 0 ? anchor : "centre"
}

// A copy of `screens` with screens[name][key] = value; "" or undefined removes
// the field, and a screen left with no fields is removed.
function withScreen(screens, name, key, value) {
    var next = JSON.parse(JSON.stringify(_obj(screens)))
    var s = _obj(next[name])
    if (value === undefined || value === null || value === "") delete s[key]
    else s[key] = value
    if (Object.keys(s).length) next[name] = s
    else delete next[name]
    return next
}

// { name: path } of the screens with their own image for `mode` (layout
// "screens" only), keeping only paths `known(path)` accepts when given.
function screenImages(layout, screens, mode, known) {
    var out = {}
    if (layout !== "screens") return out
    var all = _obj(screens)
    var names = Object.keys(all).sort()
    for (var i = 0; i < names.length; i++) {
        var p = screenValue(all, names[i], mode)
        if (p && (!known || known(p))) out[names[i]] = p
    }
    return out
}

// wallpaper-set.sh arguments: <main> [--screen NAME IMAGE]... (sorted by name).
function args(main, images) {
    var a = [main]
    var names = Object.keys(_obj(images)).sort()
    for (var i = 0; i < names.length; i++) a.push("--screen", names[i], images[names[i]])
    return a
}

// A string that is equal for two plans that put the same images on screen.
function signature(main, images) { return args(main || "", images).join("\n") }

// The image shown on `name`: its own, else the main one.
function shownOn(main, images, name) { return _obj(images)[name] || main || "" }

// Parse last-screens ("NAME<TAB>PATH" lines) into { name: path }.
function parseScreens(text) {
    var out = {}
    var lines = (text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var t = lines[i].indexOf("\t")
        if (t <= 0) continue
        var p = lines[i].slice(t + 1).trim()
        if (p) out[lines[i].slice(0, t)] = p
    }
    return out
}

// WALLPAPER_CONFIG for wallpaper-set.sh: the fits only (images go as arguments).
function envConfig(fit, anchor, screens) {
    var sc = {}
    var all = _obj(screens)
    var names = Object.keys(all)
    for (var i = 0; i < names.length; i++) {
        var f = screenValue(all, names[i], "fit"), a = screenValue(all, names[i], "anchor")
        if (f || a) sc[names[i]] = { fit: f, anchor: a }
    }
    return JSON.stringify({ fit: fit, anchor: anchor, screens: sc })
}
