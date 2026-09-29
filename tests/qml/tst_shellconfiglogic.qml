import QtQuick
import QtTest
import "../../Services/Shell/ShellConfigLogic.js" as Logic

// Pure shell-config normalisation (Services/Shell/ShellConfigLogic.js).
// Run: tests/run.sh
TestCase {
    name: "ShellConfigLogic"

    function test_normEntry_legacyString() {
        compare(Logic.normEntry("clock"), { id: "clock", config: {} })
    }
    function test_normEntry_object() {
        compare(Logic.normEntry({ id: "clock", config: { fmt: "HH:mm" } }),
                { id: "clock", config: { fmt: "HH:mm" } })
        compare(Logic.normEntry({ id: "clock" }).config, {}, "missing config defaults to {}")
    }
    function test_normEntry_garbage() {
        compare(Logic.normEntry(null), { id: "", config: {} })
        compare(Logic.normEntry(42), { id: "", config: {} })
    }

    function test_normContentEntry_align() {
        compare(Logic.normContentEntry("clock", "center").align, "center", "string takes the default")
        compare(Logic.normContentEntry({ id: "clock", align: "left" }, "center").align, "left",
                "explicit align wins")
        compare(Logic.normContentEntry({ id: "clock", align: "" }, "center").align, "",
                "empty align is kept, not replaced by the default")
    }

    function test_sideContent_legacyBar() {
        var s = { zones: { right: ["battery"], left: ["workspaces", { id: "title", config: { max: 40 } }],
                           center: ["clock"] } }
        compare(Logic.sideContent(s).map(function(e) { return e.id + "@" + e.align }),
                ["workspaces@left", "title@left", "clock@center", "battery@right"],
                "zones flatten in left, center, right order")
        compare(Logic.sideContent(s)[1].config, { max: 40 })
    }
    function test_sideContent_legacyStrip() {
        compare(Logic.sideContent({ icons: ["launcher", "dashboard"] }),
                [{ id: "launcher", config: {}, align: "" }, { id: "dashboard", config: {}, align: "" }])
    }
    function test_sideContent_contentWins() {
        var s = { content: [{ id: "clock", align: "center" }], zones: { left: ["workspaces"] } }
        compare(Logic.sideContent(s), [{ id: "clock", config: {}, align: "center" }],
                "a `content` list replaces the legacy fields")
    }
    function test_sideContent_empty() {
        compare(Logic.sideContent(null), [])
        compare(Logic.sideContent({}), [])
    }

    function test_regroup_stable() {
        var c = [{ id: "a", align: "" }, { id: "b", align: "right" }, { id: "c", align: "left" },
                 { id: "d", align: "right" }, { id: "e", align: "center" }]
        compare(Logic.regroup(c).map(function(e) { return e.id }), ["c", "e", "b", "d", "a"])
    }

    readonly property var _defaults: ({ sides: { top: { type: "bar", size: 30 } } })
    function test_resolveSide_defaultsAndNone() {
        compare(Logic.resolveSide({}, _defaults, "top").type, "bar")
        compare(Logic.resolveSide({}, _defaults, "left"), { type: "none" })
    }
    function test_resolveSide_perScreenOverride() {
        var data = { sides: { top: { type: "bar", size: 30, outerGap: 6 } },
                     perScreen: { "DP-3": { sides: { top: { size: 24 } } } } }
        compare(Logic.resolveSide(data, _defaults, "top", "DP-3"), { type: "bar", size: 24, outerGap: 6 })
        compare(Logic.resolveSide(data, _defaults, "top", "eDP-1").size, 30, "other screens keep the global side")
        compare(data.sides.top.size, 30, "override does not mutate the global side")
    }
}
