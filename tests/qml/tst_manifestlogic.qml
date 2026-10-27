import QtQuick
import QtTest
import "../../Services/Shell/ManifestLogic.js" as Logic

// Module / pack discovery records without jq (Services/Shell/ManifestLogic.js, item_127).
TestCase {
    name: "ManifestLogic"

    function test_module() {
        var m = Logic.parseModule('/x/modules/notes/\n{\n  "id": "notes",\n  "entry": "Notes.qml",\n  "extra": 1\n}\n')
        compare(m.id, "notes")
        compare(m.entry, "Notes.qml")
        compare(m.dir, "/x/modules/notes/")
        compare(m.panel, null, "missing fields are null, as the jq projection gave")
        compare(m.extra, undefined, "fields outside the projection are dropped")
    }
    function test_moduleNeedsIdAndEntry() {
        compare(Logic.parseModule('/d/\n{"id": "a"}'), null)
        compare(Logic.parseModule('/d/\n{"entry": "A.qml"}'), null)
    }
    function test_brokenRecords() {
        compare(Logic.parseModule(""), null)
        compare(Logic.parseModule("\n"), null)
        compare(Logic.parseModule('/d/\n{"id": "a", '), null, "half-written manifest")
        compare(Logic.parseModule('/d/\n[1]'), null)
        compare(Logic.parseModule('{"id":"a","entry":"A.qml"}'), null, "no dir line")
    }
    function test_pack() {
        var p = Logic.parsePack('\n/x/packs/grimdark/\nMetalSurface Button \n{"id": "grimdark", "tier": "flagship"}')
        compare(p.id, "grimdark")
        compare(p.dir, "/x/packs/grimdark/")
        compare(p.styles, ["MetalSurface", "Button"])
        compare(p.inherits, null)
    }
    function test_packWithoutStyles() {
        var p = Logic.parsePack('/x/packs/plain/\n\n{"id": "plain"}')
        compare(p.styles, [])
    }
}
