.pragma library
// Pure config.json path helpers, shared by Config.qml and the qmltestrunner tests
// (tests/qml). No Quickshell imports, so it is testable outside the shell.
//
// setPath() copies only the objects along the changed path (structural sharing):
// every other subtree keeps its identity, so a `var` binding on an unrelated key
// (Config.get("packs.<id>")) gets the same object back and QML emits no change.

// Value at dotted `key` in `data`, or `defaultValue` when any step is missing.
function getPath(data, key, defaultValue) {
    var parts = key.split(".")
    var obj = data
    for (var i = 0; i < parts.length; i++) {
        if (obj === null || obj === undefined || typeof obj !== "object") return defaultValue
        obj = obj[parts[i]]
    }
    return obj !== undefined ? obj : defaultValue
}

// New root with `value` at dotted `key`, or `data` itself when that key already
// holds an equal value (no-op: no notify, no write). The value is stored as a
// JSON copy, so a caller mutating its object later cannot change the config
// behind Config's back. A caller handing back the very object it got from
// get() may have mutated it in place, so that is never treated as a no-op.
// `undefined` removes the key (a no-op when it is already absent).
function setPath(data, key, value) {
    var parts = key.split(".")
    var cur = getPath(data, key, undefined)
    if (value === undefined && cur === undefined) return data
    var sameObject = cur === value && typeof value === "object" && value !== null
    if (!sameObject && cur !== undefined && JSON.stringify(cur) === JSON.stringify(value)) return data
    var root = Object.assign({}, data)
    var src = data, dst = root
    for (var i = 0; i < parts.length - 1; i++) {
        var k = parts[i]
        var next = (src && typeof src[k] === "object" && src[k] !== null) ? src[k] : null
        dst[k] = !next ? {} : Array.isArray(next) ? next.slice() : Object.assign({}, next)
        src = next
        dst = dst[k]
    }
    var leaf = parts[parts.length - 1]
    if (value === undefined) delete dst[leaf]
    else dst[leaf] = JSON.parse(JSON.stringify(value))
    return root
}

// Keys nothing reads any more. Config drops them once config.json has loaded, so
// an old file does not keep stale settings around (2026-10-12, item_137).
var OBSOLETE_KEYS = [
    "bar.clockFormat",        // replaced by clock.format / clock.seconds / clock.date
    "bar.height",             // bar height comes from theme tokens
    "bar.modules",            // a widget shows when it is in the bar layout (Edit Layout)
    "audio.rememberVolume"    // WirePlumber restores volumes; the toggle was removed
]

// `data` without `keys`, pruning parents left empty; `data` itself when none is set.
function dropKeys(data, keys) {
    var out = data
    for (var i = 0; i < keys.length; i++) {
        out = setPath(out, keys[i], undefined)
        var parts = keys[i].split(".")
        for (var n = parts.length - 1; n > 0; n--) {
            var parent = parts.slice(0, n).join(".")
            var v = getPath(out, parent, undefined)
            if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).length) break
            out = setPath(out, parent, undefined)
        }
    }
    return out
}
