import QtQuick
import QtTest
import "../../Services/Theming/WallpapersLogic.js" as Logic

// Per-screen wallpaper helpers (Services/Theming/WallpapersLogic.js, item_148).
// Run: tests/run.sh
TestCase {
    name: "WallpapersLogic"

    readonly property var screens: ({
        "DP-3": { dark: "/w/tall.png", fit: "fill", anchor: "right" },
        "HDMI-A-1": { light: "/w/day.png", fit: "zoom" }
    })

    function test_fit_and_anchor_inherit() {
        compare(Logic.fitOf("blur", screens, "DP-3"), "fill", "own fit")
        compare(Logic.fitOf("blur", screens, "HDMI-A-1"), "blur", "invalid own fit inherits")
        compare(Logic.fitOf("blur", screens, "eDP-1"), "blur", "unknown screen inherits")
        compare(Logic.fitOf("blur", screens, ""), "blur", "all screens")
        compare(Logic.fitOf(undefined, {}, ""), "fill")
        compare(Logic.anchorOf("left", screens, "DP-3"), "right")
        compare(Logic.anchorOf("left", screens, "HDMI-A-1"), "left")
        compare(Logic.anchorOf("up", null, "x"), "centre")
    }

    function test_with_screen_copies_and_prunes() {
        var n = Logic.withScreen(screens, "eDP-1", "fit", "edges")
        compare(n["eDP-1"].fit, "edges")
        verify(screens["eDP-1"] === undefined, "input untouched")
        n = Logic.withScreen(n, "eDP-1", "fit", "")
        verify(n["eDP-1"] === undefined, "empty screen removed")
        n = Logic.withScreen(screens, "DP-3", "dark", undefined)
        compare(n["DP-3"].fit, "fill", "other fields kept")
        verify(n["DP-3"].dark === undefined)
        compare(screens["DP-3"].dark, "/w/tall.png", "input untouched")
        compare(JSON.stringify(Logic.withScreen(null, "A", "light", "/x")), '{"A":{"light":"/x"}}')
    }

    function test_screen_images_only_in_screens_layout() {
        compare(JSON.stringify(Logic.screenImages("same", screens, "dark")), "{}")
        compare(JSON.stringify(Logic.screenImages("screens", screens, "dark")), '{"DP-3":"/w/tall.png"}')
        compare(JSON.stringify(Logic.screenImages("screens", screens, "light")), '{"HDMI-A-1":"/w/day.png"}')
        compare(JSON.stringify(Logic.screenImages("screens", screens, "light", p => p !== "/w/day.png")), "{}",
                "unknown paths dropped")
    }

    function test_args_signature_shown() {
        var im = { "Z": "/z.png", "A": "/a.png" }
        compare(Logic.args("/m.png", im).join(" "), "/m.png --screen A /a.png --screen Z /z.png")
        compare(Logic.signature("/m.png", im), Logic.signature("/m.png", { "A": "/a.png", "Z": "/z.png" }))
        verify(Logic.signature("/m.png", im) !== Logic.signature("/m.png", {}))
        compare(Logic.shownOn("/m.png", im, "A"), "/a.png")
        compare(Logic.shownOn("/m.png", im, "B"), "/m.png")
    }

    function test_parse_screens() {
        var p = Logic.parseScreens("DP-3\t/w/a b.png\nbad line\n\nHDMI-A-1\t/w/c.png\n")
        compare(JSON.stringify(p), '{"DP-3":"/w/a b.png","HDMI-A-1":"/w/c.png"}')
        compare(JSON.stringify(Logic.parseScreens("")), "{}")
    }

    function test_env_config_keeps_fits_only() {
        var e = JSON.parse(Logic.envConfig("blur", "centre", screens))
        compare(e.fit, "blur")
        compare(e.screens["DP-3"].fit, "fill")
        compare(e.screens["DP-3"].anchor, "right")
        verify(e.screens["DP-3"].dark === undefined, "images go as arguments")
        compare(e.screens["HDMI-A-1"].fit, "zoom", "the script validates")
    }
}
