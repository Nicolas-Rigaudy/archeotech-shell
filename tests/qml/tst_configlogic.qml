import QtQuick
import QtTest
import "../../Services/Persistence/ConfigLogic.js" as Logic

// Config.json path helpers (Services/Persistence/ConfigLogic.js).
// Run: tests/run.sh
TestCase {
    name: "ConfigLogic"

    function test_getPath() {
        var d = { a: { b: 1 }, n: null }
        compare(Logic.getPath(d, "a.b", 0), 1)
        compare(Logic.getPath(d, "a.x", 7), 7, "missing leaf")
        compare(Logic.getPath(d, "n.x", 7), 7, "null step")
        compare(Logic.getPath(d, "a.b.c", 7), 7, "primitive step")
    }
    function test_setPath_sharesUntouchedSubtrees() {
        var d = { appearance: { fontScale: 1 }, packs: { grimdark: { x: 1 } } }
        var n = Logic.setPath(d, "appearance.fontScale", 1.2)
        verify(n !== d, "new root so Config._data notifies")
        verify(n.packs === d.packs, "unrelated subtree keeps identity")
        verify(n.appearance !== d.appearance, "changed path is copied")
        compare(n.appearance.fontScale, 1.2)
        compare(d.appearance.fontScale, 1, "input not mutated")
    }
    function test_setPath_noop() {
        var d = { appearance: { fontScale: 1 }, launcher: { pinned: ["a"] } }
        verify(Logic.setPath(d, "appearance.fontScale", 1) === d, "equal primitive")
        verify(Logic.setPath(d, "launcher.pinned", ["a"]) === d, "equal array by value")
    }
    function test_setPath_sameObjectIsNotNoop() {
        var d = { launcher: { pinned: ["a"] } }
        var p = Logic.getPath(d, "launcher.pinned", [])
        p.push("b")                                    // caller mutated in place
        var n = Logic.setPath(d, "launcher.pinned", p)
        verify(n !== d, "same reference is written")
        compare(n.launcher.pinned, ["a", "b"])
    }
    function test_setPath_storesCopy() {
        var v = { x: 1 }
        var n = Logic.setPath({}, "packs.grimdark", v)
        v.x = 2
        compare(n.packs.grimdark.x, 1)
    }
    function test_setPath_createsAndReplaces() {
        compare(Logic.setPath({}, "a.b.c", 1), { a: { b: { c: 1 } } })
        compare(Logic.setPath({ a: 5 }, "a.b", 1), { a: { b: 1 } }, "primitive step replaced")
        var d = { list: [1, 2] }
        verify(Array.isArray(Logic.setPath(d, "list.0", 9).list), "array step stays an array")
    }
    function test_setPath_undefinedRemoves() {
        var d = { a: { b: 1, c: 2 } }
        verify(Logic.setPath(d, "a.x", undefined) === d, "absent key: no-op")
        var n = Logic.setPath(d, "a.b", undefined)
        compare(n, { a: { c: 2 } })
        verify(!("b" in n.a), "key deleted, not left undefined")
        compare(d.a.b, 1, "input not mutated")
    }
}
