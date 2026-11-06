.pragma library
// Module and pack manifest records (item_127): discovery cats each manifest
// raw, so jq is no longer needed to find modules or packs. A record is
//   module: "<dir>\n<module.json text>"
//   pack:   "<dir>\n<style ids, space-separated>\n<pack.json text>"
// and the result keeps the same fields the jq projection kept, missing ones
// as null. Pure, so tests/qml can check it without the shell.

var MODULE_FIELDS = ["id", "name", "author", "version", "canLiveIn", "entry", "icon", "defaultSize",
                     "panel", "configSchema", "official", "verified", "minShellVersion", "dependencies",
                     "description"]
var PACK_FIELDS = ["id", "name", "tier", "minShellVersion", "inherits", "configSchema", "wallpapers"]

function _pick(obj, fields) {
    var out = {}
    for (var i = 0; i < fields.length; i++) {
        var v = obj[fields[i]]
        out[fields[i]] = v === undefined ? null : v
    }
    return out
}

function _split(record, headerLines) {
    var rest = String(record || "").replace(/^\s+/, "")
    var heads = []
    for (var i = 0; i < headerLines; i++) {
        var nl = rest.indexOf("\n")
        if (nl === -1) return null
        heads.push(rest.slice(0, nl))
        rest = rest.slice(nl + 1)
    }
    var parsed
    try { parsed = JSON.parse(rest) } catch (e) { return null }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null
    return { heads: heads, json: parsed }
}

// → manifest object, or null for a blank, broken or incomplete record.
function parseModule(record) {
    var r = _split(record, 1)
    if (!r) return null
    var m = _pick(r.json, MODULE_FIELDS)
    if (!m.id || !m.entry) return null
    m.dir = r.heads[0]
    return m
}

function parsePack(record) {
    var r = _split(record, 2)
    if (!r) return null
    var p = _pick(r.json, PACK_FIELDS)
    if (!p.id) return null
    p.dir = r.heads[0]
    p.styles = r.heads[1].split(" ").filter(function (s) { return s !== "" })
    return p
}

// Absolute dir (trailing slash) of the wallpapers a pack ships (item_151):
// pack.json "wallpapers" names a folder inside the pack ("walls"). "" when the
// pack names none, or names one outside itself (absolute, ".."). The id keys
// thumbnail files, so an id that is not a plain name ships no wallpapers.
function packWallpaperDir(p) {
    if (!p || !p.dir || typeof p.wallpapers !== "string") return ""
    if (!/^[A-Za-z0-9_.-]+$/.test(String(p.id || "")) || p.id === "." || p.id === "..") return ""
    var rel = p.wallpapers.replace(/^\.\//, "").replace(/\/+$/, "")
    if (!rel || rel.charAt(0) === "/" || rel.split("/").indexOf("..") !== -1) return ""
    return p.dir + rel + "/"
}
