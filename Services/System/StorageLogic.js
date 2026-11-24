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

// The --run request for the ticked rows: [{id, commands}], admin rows first
// (the order the helper runs them, so the running page reads top to bottom).
function runList(entries, sel) {
    var root = [], user = []
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i]
        if (!sel || !sel[e.id] || e.action === "open" || !(e.commands || []).length) continue
        ;(e.root ? root : user).push({ id: e.id, commands: e.commands.slice() })
    }
    return root.concat(user)
}

// A command or path as shown on screen: $HOME/… → ~/… (the run gets the real one).
function tilde(text, home) {
    if (!text || !home) return text || ""
    return text.split(home + "/").join("~/")
}

// One JSON line of `storage-scan.py --run` ({event: start|done|result, ...}); null otherwise.
function parseEvent(line) {
    var d
    try { d = JSON.parse(line) } catch (e) { return null }
    return d && typeof d === "object" && typeof d.event === "string" ? d : null
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

// ── Explore (item_183) ──────────────────────────────────────────────────────

// Squarified treemap (Bruls, Huizing, van Wijk 2000): items [{bytes, ...}] in the
// rectangle (x, y, w, h) -> [{x, y, w, h, item}], largest first, each box's area
// proportional to its bytes. Items of 0 bytes or less are left out.
function treemap(items, x, y, w, h) {
    var out = [], tot = 0
    var its = (items || []).filter(function (i) { return typeof i.bytes === "number" && i.bytes > 0 })
                           .sort(function (a, b) { return b.bytes - a.bytes })
    for (var i = 0; i < its.length; i++) tot += its[i].bytes
    if (tot <= 0 || !(w > 0) || !(h > 0)) return out
    var vals = its.map(function (it) { return { item: it, a: it.bytes * w * h / tot } })
    var row = []

    // The worst aspect ratio of a row laid along a side of length `side`.
    function worst(r, side) {
        var s = 0, mx = 0, mn = Infinity
        for (var k = 0; k < r.length; k++) { s += r[k].a; mx = Math.max(mx, r[k].a); mn = Math.min(mn, r[k].a) }
        return Math.max(side * side * mx / (s * s), (s * s) / (side * side * mn))
    }
    // Lay the row along the short side, then shrink the free rectangle.
    function place() {
        var s = 0, k
        for (k = 0; k < row.length; k++) s += row[k].a
        if (w >= h) {
            var cw = s / h, yy = y
            for (k = 0; k < row.length; k++) {
                var rh = row[k].a / cw
                out.push({ x: x, y: yy, w: cw, h: rh, item: row[k].item })
                yy += rh
            }
            x += cw; w -= cw
        } else {
            var rh2 = s / w, xx = x
            for (k = 0; k < row.length; k++) {
                var rw = row[k].a / rh2
                out.push({ x: xx, y: y, w: rw, h: rh2, item: row[k].item })
                xx += rw
            }
            y += rh2; h -= rh2
        }
        row = []
    }
    while (vals.length) {
        var side = Math.min(w, h)
        if (row.length === 0 || worst(row.concat([vals[0]]), side) <= worst(row, side)) row.push(vals.shift())
        else place()
    }
    if (row.length) place()
    return out
}

// A folder whose map would show boxes without their contents: it has no children
// yet, or some sub-folder of it was cut off by the scan depth. The panel then
// asks the helper for a scoped scan of it (once per folder).
function needsScan(node) {
    if (!node || node.kind !== "dir" || !(node.bytes > 0)) return false
    if (!node.children) return true
    return node.children.some(function (c) { return c.kind === "dir" && c.bytes > 0 && !c.children })
}

// The folder that holds `path` ("/a/b/c" -> "/a/b").
function parentPath(path) {
    var i = (path || "").lastIndexOf("/")
    return i > 0 ? path.slice(0, i) : "/"
}

// Breadcrumb from the map's top folder `base` down to `path`:
// [{ name, path }], the first one named `baseName` ("~" for the home folder).
function crumbs(path, base, baseName) {
    var out = [{ name: baseName || base, path: base }]
    if (!path || path === base || path.indexOf(base + "/") !== 0) return out
    var parts = path.slice(base.length + 1).split("/"), p = base
    for (var i = 0; i < parts.length; i++) {
        p += "/" + parts[i]
        out.push({ name: parts[i], path: p })
    }
    return out
}

// Folders and named files in the scanned tree whose name contains `query`
// (case-insensitive), largest first, at most `limit` of them.
function search(tree, query, limit) {
    var q = (query || "").trim().toLowerCase(), out = []
    if (!tree || !q) return out
    ;(function walk(n) {
        var ch = n.children || []
        for (var i = 0; i < ch.length; i++) {
            var c = ch[i]
            if (c.kind !== "dir" && c.kind !== "file") continue
            if (c.name.toLowerCase().indexOf(q) >= 0) out.push(c)
            if (c.kind === "dir") walk(c)
        }
    })(tree)
    out.sort(function (a, b) { return b.bytes - a.bytes })
    return out.slice(0, limit || 50)
}

// The cleanup entry whose folder holds `path` (the most specific one), or null:
// what "Show in Clean up" points at.
function sourceFor(entries, path) {
    var best = null, bestLen = -1
    for (var i = 0; i < (entries || []).length; i++) {
        var ps = entries[i].paths || []
        for (var j = 0; j < ps.length; j++) {
            var p = ps[j].replace(/\/+$/, "")
            if ((path === p || path.indexOf(p + "/") === 0) && p.length > bestLen) { best = entries[i]; bestLen = p.length }
        }
    }
    return best
}

// The cleanup entries with a folder inside `path` (strictly below it): what an
// untiered folder such as ~/.cdx holds for Clean up.
function inside(entries, path) {
    var pre = (path || "").replace(/\/+$/, "") + "/"
    return (entries || []).filter(function (e) {
        return (e.paths || []).some(function (p) { return p.indexOf(pre) === 0 && p.replace(/\/+$/, "") + "/" !== pre })
    })
}
