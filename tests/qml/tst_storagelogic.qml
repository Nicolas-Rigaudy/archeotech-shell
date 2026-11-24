import QtQuick
import QtTest
import "../../Services/System/StorageLogic.js" as S

// Storage helpers (Services/System/StorageLogic.js, item_181).
// Run: tests/run.sh
TestCase {
    name: "StorageLogic"

    readonly property real gib: 1024 * 1024 * 1024
    readonly property var entries: [
        { id: "uv", tier: "safe", bytes: 30 * gib, action: "command", checked: true, commands: ["uv cache clean"] },
        { id: "pac", tier: "safe", bytes: 8 * gib, action: "command", root: true, upto: true, checked: true,
          commands: ["paccache -rk2 && paccache -ruk0"] },
        { id: "docker", tier: "review", bytes: null, action: "command", checked: false, commands: ["docker system prune -f"] },
        { id: "dl", tier: "review", bytes: 3 * gib, action: "open", checked: false, commands: [], label: "Downloads",
          paths: ["/home/u/Downloads"] },
        { id: "old", tier: "review", bytes: 2 * gib, action: "trash", checked: false, label: "Old cdx profile",
          detail: ".a.remove.1", commands: ["gio trash -- /home/u/.cdx/profiles/.a.remove.1"] }
    ]

    function test_parse() {
        compare(S.parse("nope"), null)
        compare(S.parse("[]"), null)
        compare(S.parse('{"x":1}'), null)
        compare(S.parse('{"root":{"free_pct":9}}').root.free_pct, 9)
        compare(S.parse('{"error":"no such folder"}').error, "no such folder")
    }

    function test_level_matches_disk_alert() {
        compare(S.level(null, 15, 8), "")
        compare(S.level({ free_pct: 40 }, 15, 8), "ok")
        compare(S.level({ free_pct: 15 }, 15, 8), "warn", "at the threshold counts")
        compare(S.level({ free_pct: 8 }, 15, 8), "critical")
        compare(S.level({ free_pct: 40, btrfs_metadata_free: 0.5 * gib, btrfs_unallocated: 1048576 }, 15, 8),
                "critical", "metadata nearly full with nothing left to allocate")
        compare(S.level({ free_pct: 40, btrfs_metadata_free: 0.5 * gib, btrfs_unallocated: 20 * gib }, 15, 8),
                "ok", "metadata can grow into unallocated space")
        compare(S.level({ free_pct: 40, btrfs_metadata_free: null, btrfs_unallocated: null }, 15, 8), "ok", "not btrfs")
        verify(S.metadataTight({ btrfs_metadata_free: 0.2 * gib, btrfs_unallocated: 0 }))
        verify(!S.metadataTight({ free_pct: 50 }))
    }

    function test_groups() {
        var g = S.groups(entries)
        compare(g.map(function (x) { return x.tier }).join(), "safe,review")
        compare(g[0].bytes, 38 * gib)
        compare(g[1].bytes, 5 * gib, "an unknown size counts as nothing")
        compare(S.groups([]).length, 0)
        compare(S.groups([{ id: "a", tier: "review", bytes: 1 }]).length, 1, "empty tiers are left out")
    }

    function test_selection() {
        var sel = S.defaultSelection(entries)
        compare(Object.keys(sel).sort().join(), "pac,uv")
        var r = S.selection(entries, sel)
        compare(r.count, 2)
        compare(r.bytes, 38 * gib)
        verify(r.approx, "pacman's size is an upper bound")
        compare(r.root.join("|"), "paccache -rk2 && paccache -ruk0")
        compare(r.user.join("|"), "uv cache clean")
        r = S.selection(entries, { docker: true, dl: true, old: true })
        compare(r.count, 2, "open-only rows never run")
        compare(r.unknown, 1)
        compare(r.bytes, 2 * gib)
        verify(!r.approx)
        compare(S.selection(entries, {}).count, 0)
    }

    function test_filter() {
        compare(S.filter(entries, "").length, entries.length)
        compare(S.filter(entries, "DOWN")[0].id, "dl")
        compare(S.filter(entries, "remove.1")[0].id, "old", "matches the detail")
        compare(S.filter(entries, "/home/u/Down")[0].id, "dl", "matches the path")
        compare(S.filter(entries, "zzz").length, 0)
    }

    function test_formatBytes() {
        compare(S.formatBytes(null), "")
        compare(S.formatBytes(0), "0 B")
        compare(S.formatBytes(1536), "1.5 K")
        compare(S.formatBytes(30006715764), "27.9 G")
        compare(S.formatBytes(500 * 1024 * 1024), "500 M")
        compare(S.formatBytes(-2 * gib), "-2.0 G")
    }

    function test_age() {
        var now = 1000000000000
        compare(S.age(0, now), "")
        compare(S.age(now - 20000, now), "just now")
        compare(S.age(now - 4 * 60000, now), "4 min ago")
        compare(S.age(now - 2 * 3600000, now), "2 h ago")
        compare(S.age(now - 86400000, now), "1 day ago")
        compare(S.age(now - 3 * 86400000, now), "3 days ago")
    }

    function test_tree_find_and_graft() {
        var tree = { name: "~", path: "/h", kind: "dir", bytes: 10, children: [
            { name: "a", path: "/h/a", kind: "dir", bytes: 6, tier: "safe", children: [
                { name: "b", path: "/h/a/b", kind: "dir", bytes: 4 },
                { name: "2 more folders", path: "/h/a", kind: "more", bytes: 2 } ] },
            { name: "ab", path: "/h/ab", kind: "dir", bytes: 4 } ] }
        compare(S.findNode(tree, "/h/a/b").name, "b")
        compare(S.findNode(tree, "/h/ab").name, "ab", "a sibling sharing a prefix is not a parent")
        compare(S.findNode(tree, "/h/a").name, "a", "never the 'more' box of the same path")
        compare(S.findNode(tree, "/h/zz"), null)
        var sub = { name: "/h/a/b", path: "/h/a/b", kind: "dir", bytes: 4, children: [
            { name: "c", path: "/h/a/b/c", kind: "dir", bytes: 4 } ] }
        var next = S.graft(tree, "/h/a/b", sub)
        verify(next !== tree)
        compare(S.findNode(next, "/h/a/b/c").bytes, 4)
        compare(S.findNode(next, "/h/a/b").name, "b", "keeps the node's own name")
        compare(next.children[1], tree.children[1], "untouched branches keep their objects")
        compare(S.findNode(tree, "/h/a/b").children, undefined, "the old tree is not changed")
        compare(S.graft(tree, "/h/a", { path: "/h/a", kind: "dir", bytes: 6 }).children[0].tier, "safe",
                "keeps the node's tier")
        verify(!("tier" in S.graft(tree, "/h/ab", { path: "/h/ab", kind: "dir", bytes: 4 }).children[1]),
               "no tier key when the node had none")
    }

    function test_run_list_and_events() {
        var es = [ { id: "u", commands: ["rm -rf -- '/h/.cache/x'"] },
                   { id: "o", action: "open", commands: [] },
                   { id: "r", root: true, commands: ["journalctl --vacuum-size=500M"] },
                   { id: "n", commands: ["true"] } ]
        compare(S.runList(es, { u: true, o: true, r: true }),
                [ { id: "r", commands: ["journalctl --vacuum-size=500M"] },
                  { id: "u", commands: ["rm -rf -- '/h/.cache/x'"] } ], "admin first; open rows never run")
        compare(S.runList(es, null), [])
        compare(S.parseEvent('{"event":"done","id":"u","ok":true}').id, "u")
        compare(S.parseEvent('{"root":{}}'), null)
        compare(S.parseEvent("not json"), null)
        compare(S.tilde("rm -rf -- /h/me/.cache/a /h/me/.npm", "/h/me"), "rm -rf -- ~/.cache/a ~/.npm")
        compare(S.tilde("/h/meow/x", "/h/me"), "/h/meow/x", "a prefix that is not the home folder stays")
    }

    // item_183: squarified layout, the lazy-scan rule, breadcrumb, search, source lookup.
    function test_treemap_areas_proportional() {
        var items = [{ bytes: 60 }, { bytes: 25 }, { bytes: 10 }, { bytes: 4 }, { bytes: 1 }, { bytes: 0 }, { bytes: -3 }]
        var w = 640, h = 400
        var r = S.treemap(items, 10, 20, w, h)
        compare(r.length, 5, "empty and negative items are left out")
        compare(r[0].item.bytes, 60, "largest first")
        var area = 0
        for (var i = 0; i < r.length; i++) {
            var b = r[i]
            area += b.w * b.h
            fuzzyCompare(b.w * b.h / (w * h), b.item.bytes / 100, 1e-9, "area share = byte share")
            verify(b.x >= 10 - 1e-9 && b.y >= 20 - 1e-9 && b.x + b.w <= 10 + w + 1e-6 && b.y + b.h <= 20 + h + 1e-6, "inside the rectangle")
            for (var j = 0; j < i; j++) {
                var o = r[j]
                var ox = Math.min(b.x + b.w, o.x + o.w) - Math.max(b.x, o.x)
                var oy = Math.min(b.y + b.h, o.y + o.h) - Math.max(b.y, o.y)
                verify(ox <= 1e-6 || oy <= 1e-6, "boxes do not overlap")
            }
        }
        fuzzyCompare(area, w * h, 1e-6, "the boxes fill the rectangle")
        compare(S.treemap([], 0, 0, 10, 10).length, 0)
        compare(S.treemap(items, 0, 0, 0, 10).length, 0, "no room")
        compare(S.treemap(null, 0, 0, 10, 10).length, 0)
    }

    function test_treemap_squarish() {
        // Equal items in a square: squarified rows keep each box near square.
        var items = []
        for (var i = 0; i < 16; i++) items.push({ bytes: 1 })
        var r = S.treemap(items, 0, 0, 400, 400)
        for (i = 0; i < r.length; i++) {
            var ratio = Math.max(r[i].w / r[i].h, r[i].h / r[i].w)
            verify(ratio < 2, "aspect " + ratio)
        }
    }

    function test_needs_scan() {
        verify(!S.needsScan(null))
        verify(!S.needsScan({ kind: "more", bytes: 5 }))
        verify(!S.needsScan({ kind: "dir", bytes: 0 }), "empty folder")
        verify(S.needsScan({ kind: "dir", bytes: 5 }), "contents not scanned")
        verify(S.needsScan({ kind: "dir", bytes: 5, children: [{ kind: "dir", bytes: 3 }, { kind: "files", bytes: 2 }] }),
               "a sub-folder was cut off by the depth")
        verify(!S.needsScan({ kind: "dir", bytes: 5, children: [{ kind: "dir", bytes: 3, children: [] }, { kind: "file", bytes: 2 }] }))
    }

    function test_crumbs_and_parent() {
        compare(S.crumbs("/home/u", "/home/u", "~"), [{ name: "~", path: "/home/u" }])
        compare(S.crumbs("/home/u/.cache/paru", "/home/u", "~"),
                [{ name: "~", path: "/home/u" }, { name: ".cache", path: "/home/u/.cache" },
                 { name: "paru", path: "/home/u/.cache/paru" }])
        compare(S.crumbs("/elsewhere", "/home/u", "~").length, 1, "outside the map: the top only")
        compare(S.crumbs("/home/user2", "/home/u", "~").length, 1, "a sibling with the same prefix is outside")
        compare(S.parentPath("/home/u/.cache"), "/home/u")
        compare(S.parentPath("/home"), "/")
    }

    function test_search_tree() {
        var t = { name: "u", path: "/u", kind: "dir", bytes: 100, children: [
            { name: "Cache", path: "/u/Cache", kind: "dir", bytes: 40, children: [
                { name: "cache-b", path: "/u/Cache/cache-b", kind: "dir", bytes: 30 },
                { name: "2 more folders", path: "/u/Cache", kind: "more", bytes: 10 }] },
            { name: "notes.cache", path: "/u/notes.cache", kind: "file", bytes: 50 },
            { name: "other files", path: "/u", kind: "files", bytes: 10 }] }
        var r = S.search(t, " CACHE ", 10)
        compare(r.map(n => n.name), ["notes.cache", "Cache", "cache-b"], "largest first; more/files boxes left out")
        compare(S.search(t, "cache", 1).length, 1)
        compare(S.search(t, "", 10).length, 0)
        compare(S.search(null, "x", 10).length, 0)
    }

    function test_source_for() {
        var es = [{ id: "app", paths: ["/u/.cache/zen", "/u/.cache/aws"] }, { id: "zen-sub", paths: ["/u/.cache/zen/x/"] },
                  { id: "none" }]
        compare(S.sourceFor(es, "/u/.cache/aws").id, "app")
        compare(S.sourceFor(es, "/u/.cache/zen/a").id, "app")
        compare(S.sourceFor(es, "/u/.cache/zen/x/y").id, "zen-sub", "the most specific source wins")
        compare(S.sourceFor(es, "/u/.cache/zenith"), null, "a prefix of the name is not the folder")
        compare(S.sourceFor(es, "/u/.cache"), null)
    }

    function test_inside_entries() {
        var es = [{ id: "a", paths: ["/h/.cdx/profiles/x"] }, { id: "b", paths: ["/h/.cache/"] },
                  { id: "c", paths: ["/h/.cdx/"] }, { id: "d" }]
        compare(S.inside(es, "/h/.cdx").map(e => e.id), ["a"])
        compare(S.inside(es, "/h").map(e => e.id), ["a", "b", "c"])
        compare(S.inside(es, "/h/.cache").length, 0)
        compare(S.inside(null, "/h").length, 0)
    }
}
