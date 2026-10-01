import QtQuick
import QtTest
import "../../Services/Hardware/DisplaysLogic.js" as Logic

// Display layout helpers (Services/Hardware/DisplaysLogic.js, item_135).
// The work desk: eDP-1 1920x1200 | HDMI-A-1 1920x1080 @ y60 | DP-3 portrait (270).
// Run: tests/run.sh
TestCase {
    name: "DisplaysLogic"

    function _out(name, x, y, w, h, transform, enabled) {
        return { name: name, x: x, y: y, width: w, height: h, refresh: 60, scale: 1,
                 transform: transform || "normal", enabled: enabled === undefined ? true : enabled, modes: [] }
    }
    function _desk() {
        return [_out("eDP-1", 0, 0, 1920, 1200), _out("HDMI-A-1", 1920, 60, 1920, 1080),
                _out("DP-3", 3840, 0, 1920, 1080, "270")]
    }

    function test_parse() {
        var t = JSON.stringify([{ name: "DP-3", make: "Iiyama", model: "PL2493H", serial: "123", enabled: true,
            position: { x: 3840, y: 0 }, transform: "270", scale: 1,
            modes: [{ width: 1280, height: 720, refresh: 60, preferred: false, current: false },
                    { width: 1920, height: 1080, refresh: 60, preferred: true, current: true }] }])
        var o = Logic.parse(t)[0]
        compare(o.width, 1920, "current mode, not the first one")
        compare(o.x, 3840); compare(o.transform, "270"); compare(o.serial, "123")
        compare(o.modes.length, 2)
        compare(Logic.parse("not json"), null)
        compare(Logic.parse("{}"), null, "must be an array")
    }
    function test_parseDisabledFallsBackToNative() {
        var t = JSON.stringify([{ name: "HDMI-A-1", enabled: false, position: { x: 0, y: 0 },
            modes: [{ width: 1280, height: 720, refresh: 60, preferred: false, current: false },
                    { width: 1920, height: 1080, refresh: 60, preferred: true, current: false }] }])
        compare(Logic.parse(t)[0].width, 1920, "no current mode: the preferred one, not the first")
    }
    function test_argvWithoutModes() {
        var o = _out("X", 0, 0, 0, 0); o.refresh = 0
        var a = Logic.argv([o]).join(" ")
        verify(a.indexOf("--mode") < 0, "no 0x0 mode: " + a)
        verify(a.indexOf("--output X --on --pos 0,0") >= 0)
    }
    function test_logicalSize() {
        compare(Logic.logicalSize(_out("a", 0, 0, 1920, 1080, "270")).w, 1080, "portrait swaps")
        var s = _out("b", 0, 0, 2560, 1440); s.scale = 2
        compare(Logic.logicalSize(s).h, 720, "scale divides")
    }
    function test_argv() {
        var l = _desk(); l[1].enabled = false; l[0].refresh = 0
        var a = Logic.argv(l)
        compare(a[0], "wlr-randr")
        verify(a.join(" ").indexOf("--output eDP-1 --on --mode 1920x1200 --pos 0,0 --transform normal --scale 1") >= 0,
               "0 Hz refresh omitted: " + a.join(" "))
        verify(a.join(" ").indexOf("--output HDMI-A-1 --off") >= 0, "disabled output turned off")
        verify(a.join(" ").indexOf("--mode 1920x1080@60.000Hz --pos 3840,0 --transform 270") >= 0)
    }
    function test_deskHasNoOverlap() {
        verify(!Logic.hasOverlap(_desk()))
        var l = _desk(); l[2].x = 3000          // portrait slid onto the middle screen
        verify(Logic.hasOverlap(l))
        l[1].enabled = false                    // ...but HDMI is off, and DP-3 at 3000 clears eDP-1
        verify(!Logic.hasOverlap(l), "disabled outputs never count")
    }
    function test_snapFlushRightOfNeighbour() {
        // Drop the portrait screen roughly right of HDMI, a bit low: lands flush at x=3840.
        var p = Logic.snap(_desk(), "DP-3", 3900, 40)
        compare(p.x, 3840)
        verify(p.y >= -1080 && p.y <= 1080)
    }
    function test_snapNeverOverlaps() {
        var l = _desk()
        // Dropped right on top of the laptop panel: must end beside something, not on it.
        var p = Logic.snap(l, "DP-3", 200, 100)
        l[2].x = p.x; l[2].y = p.y
        verify(!Logic.hasOverlap(l), "snapped to " + p.x + "," + p.y)
    }
    function test_snapAlignsEdges() {
        // HDMI dropped 30 px below the laptop's top edge snaps to y=0 (align threshold 64).
        var l = _desk()
        var p = Logic.snap(l, "HDMI-A-1", 1920, 30)
        compare(p.x, 1920); compare(p.y, 0)
    }
    function test_snapLoneOutputToOrigin() {
        var l = [_out("eDP-1", 500, 300, 1920, 1200)]
        var p = Logic.snap(l, "eDP-1", 500, 300)
        compare(p.x, 0); compare(p.y, 0)
    }
    function test_risky() {
        var before = _desk()
        var moved = _desk(); moved[1].y = 0
        verify(!Logic.risky(before, moved), "moving a screen is safe")
        var rot = _desk(); rot[1].transform = "90"
        verify(Logic.risky(before, rot), "rotation can blank a screen")
        var off = _desk(); off[2].enabled = false
        verify(Logic.risky(before, off), "turning a screen off")
        var sc = _desk(); sc[0].scale = 1.5
        verify(Logic.risky(before, sc), "scale")
        var md = _desk(); md[1].width = 1280; md[1].height = 720
        verify(Logic.risky(before, md), "resolution")
        var added = _desk().concat([_out("DP-4", 5760, 0, 1920, 1080)])
        verify(Logic.risky(before, added), "a new output")
    }
    function test_normalize() {
        var l = [_out("a", 100, 50, 10, 10), _out("b", 110, 40, 10, 10), _out("c", -500, -500, 10, 10, "normal", false)]
        var n = Logic.normalize(l)
        compare(n[0].x, 0); compare(n[1].y, 0)
        compare(n[2].x, -500, "disabled outputs untouched")
        compare(l[0].x, 100, "input not mutated")
    }
}
