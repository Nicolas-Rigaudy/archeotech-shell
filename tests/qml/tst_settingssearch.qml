import QtQuick
import QtTest
import "../../Modules/Settings/SettingsSearchLogic.js" as Search
import "../../Services/Persistence/ConfigDefaults.js" as Defaults

// Settings row search and reset-to-default helpers (item_138).
// Run: tests/run.sh
TestCase {
    name: "SettingsSearch"

    function keys(rs) { return rs.map(function (r) { return r.key }) }

    function test_rowLevelResults() {
        var r = Search.search("toast")
        compare(r[0].key, "notifications.toastTimeout", "label match first")
        verify(keys(r).indexOf("notifications.maxToasts") !== -1)
        compare(r[0].section, "Toasts")
    }
    function test_labelBeatsKeyword() {
        // "Seconds" is a label; "clock" only a keyword/section for it.
        compare(Search.search("seconds")[0].key, "clock.seconds")
        var c = keys(Search.search("clock"))
        verify(c.indexOf("clock.format") !== -1 && c.indexOf("clock.date") !== -1)
    }
    function test_everyTokenMustMatch() {
        compare(keys(Search.search("touchpad speed")), ["input.pointerSpeed"])
        compare(Search.search("zzz").length, 0)
        compare(Search.search("  ").length, 0)
    }
    function test_paneLabelMatches() {
        var r = Search.search("power", function (id) { return id === "power" ? "Power" : id })
        verify(r.length >= 4)
    }
    function test_entryFor() {
        compare(Search.entryFor("clock.date").pane, "shell")
        compare(Search.entryFor("nope"), null)
    }
    function test_defaults() {
        compare(Defaults.value("clock.format"), "24h")
        verify(!Defaults.isModified("clock.format", undefined), "unset = default")
        verify(!Defaults.isModified("clock.format", "24h"), "explicit default")
        verify(Defaults.isModified("clock.format", "12h"))
        verify(!Defaults.isModified("dashboard.scanRoots", ["~/Projects"]), "arrays by value")
        verify(Defaults.isModified("dashboard.scanRoots", ["~/Code"]))
        verify(!Defaults.isModified("not.declared", 3), "no default, no reset")
    }
}
