.pragma library
// Storage helpers (item_181): parse scripts/storage-scan.py output, group the
// cleanup entries by tier, sum a selection, format sizes and pick the alert
// level. Pure functions, so tests/qml/tst_storagelogic.qml checks them without
// the shell.

var TIERS = ["safe", "review"]
var GIB = 1024 * 1024 * 1024

// JSON text from the helper → object, or null when it is not a scan result.
function parse(text) {
    var d
    try { d = JSON.parse(text) } catch (e) { return null }
    if (!d || typeof d !== "object" || (!d.root && !d.tree && !d.error)) return null
    return d
}

// Free-space level for / with the same rules as dotfiles disk-alert.sh:
// "critical" at free <= crit % or when btrfs metadata has under 1 GiB free and
// no unallocated space left to grow into; "warn" at free <= warn %; else "ok".
// No reading yet → "".
function level(root, warnPct, critPct) {
    if (!root || typeof root.free_pct !== "number") return ""
    var meta = root.btrfs_metadata_free, unalloc = root.btrfs_unallocated
    var metaTight = typeof meta === "number" && typeof unalloc === "number"
                    && meta >= 0 && meta < GIB && unalloc >= 0 && unalloc < GIB
    if (root.free_pct <= critPct || metaTight) return "critical"
    if (root.free_pct <= warnPct) return "warn"
    return "ok"
}

function metadataTight(root) {
    return level({ free_pct: 100, btrfs_metadata_free: root && root.btrfs_metadata_free,
                   btrfs_unallocated: root && root.btrfs_unallocated }, 0, 0) === "critical"
}

// Entries → [{ tier, entries, bytes }] in TIERS order, empty tiers left out.
// A tier's bytes count only entries whose size is known.
function groups(entries) {
    var out = []
    for (var i = 0; i < TIERS.length; i++) {
        var list = (entries || []).filter(function (e) { return e.tier === TIERS[i] })
        if (list.length) out.push({ tier: TIERS[i], entries: list, bytes: sumBytes(list) })
    }
    return out
}

function sumBytes(list) {
    var b = 0
    for (var i = 0; i < list.length; i++) if (typeof list[i].bytes === "number") b += list[i].bytes
    return b
}

// The entries' default selection: { id: true } for the ones the helper pre-ticks.
function defaultSelection(entries) {
    var sel = {}
    for (var i = 0; i < (entries || []).length; i++) if (entries[i].checked) sel[entries[i].id] = true
    return sel
}

// What a selection frees: { count, bytes, approx, unknown, root, user }.
// approx = some sizes are estimates ("up to"), unknown = some have no size.
// Root commands are listed apart: the panel runs them under one pkexec prompt.
// Open-only entries never run anything and do not count.
function selection(entries, sel) {
    var r = { count: 0, bytes: 0, approx: false, unknown: 0, root: [], user: [] }
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i]
        if (!sel || !sel[e.id] || e.action === "open") continue
        r.count++
        if (typeof e.bytes === "number") r.bytes += e.bytes
        else r.unknown++
        if (e.approx || e.upto) r.approx = true
        var cmds = e.commands || []
        for (var j = 0; j < cmds.length; j++) (e.root ? r.root : r.user).push(cmds[j])
    }
    return r
}

// Entries whose label, detail or path contains `query` (case-insensitive).
function filter(entries, query) {
    var q = (query || "").trim().toLowerCase()
    if (!q) return entries || []
    return (entries || []).filter(function (e) {
        var hay = [e.label, e.detail, (e.paths || []).join(" ")].join(" ").toLowerCase()
        return hay.indexOf(q) >= 0
    })
}

// 1536 → "1.5 K", 30006715764 → "27.9 G" (binary units, like du -h / df -h).
// null / undefined → "".
function formatBytes(b) {
    if (typeof b !== "number" || isNaN(b)) return ""
    var units = ["B", "K", "M", "G", "T", "P"], i = 0, v = Math.abs(b)
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
    var s = i === 0 ? String(Math.round(v)) : (v >= 100 ? v.toFixed(0) : v.toFixed(1))
    return (b < 0 ? "-" : "") + s + " " + units[i]
}

// Scan age for the footer: "just now", "4 min ago", "2 h ago", "3 days ago".
function age(scannedAtMs, nowMs) {
    if (!scannedAtMs) return ""
    var s = Math.max(0, Math.round((nowMs - scannedAtMs) / 1000))
    if (s < 60) return "just now"
    if (s < 3600) return Math.floor(s / 60) + " min ago"
    if (s < 86400) return Math.floor(s / 3600) + " h ago"
    var d = Math.floor(s / 86400)
    return d + (d === 1 ? " day ago" : " days ago")
}

// Tree node by path (Explore drill-down), or null.
function findNode(tree, path) {
    if (!tree) return null
    if (tree.path === path && tree.kind !== "more" && tree.kind !== "files") return tree
    var ch = tree.children || []
    for (var i = 0; i < ch.length; i++) {
        if (ch[i].kind !== "dir") continue
        if (path === ch[i].path || path.indexOf(ch[i].path + "/") === 0) {
            var n = findNode(ch[i], path)
            if (n) return n
        }
    }
    return null
}

// Replace the node at `path` with a deeper scoped scan of it (item_183 lazy
// drill-down); returns a new tree so bindings see the change.
function graft(tree, path, sub) {
    if (!tree || !sub) return tree
    if (tree.path === path && tree.kind !== "more" && tree.kind !== "files")
        return tree.tier === undefined ? Object.assign({}, sub, { name: tree.name })
                                       : Object.assign({}, sub, { name: tree.name, tier: tree.tier })
    if (!tree.children) return tree
    var changed = false
    var kids = tree.children.map(function (c) {
        if (c.kind !== "dir" || !(path === c.path || path.indexOf(c.path + "/") === 0)) return c
        var n = graft(c, path, sub)
        if (n !== c) changed = true
        return n
    })
    return changed ? Object.assign({}, tree, { children: kids }) : tree
}
