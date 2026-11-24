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
}
