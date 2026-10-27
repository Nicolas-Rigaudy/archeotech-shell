import QtQuick
import QtTest
import "../../Commons/PaletteLogic.js" as Palette

// Theme crossfade maths (Commons/PaletteLogic.js).
// Run: tests/run.sh
TestCase {
    name: "PaletteLogic"

    function test_parse() {
        compare(Palette.parse("#ff8000").r, 255)
        compare(Palette.parse("#f80").g, 0x88)
        compare(Palette.parse("#80ff0000").a, 128 / 255)
        compare(Palette.parse("red"), null)
        compare(Palette.parse(undefined), null)
    }
    function test_blendEndpoints() {
        compare(Palette.blend("#000000", "#ffffff", 0), "#000000")
        compare(Palette.blend("#000000", "#ffffff", 1), "#ffffff")
    }
    function test_blendMidpoint() {
        compare(Palette.blend("#000000", "#ffffff", 0.5), "#808080")
        compare(Palette.blend("#ff0000", "#0000ff", 0.5), "#800080")
    }
    function test_blendKeepsAlpha() {
        compare(Palette.blend("#80ff0000", "#80ff0000", 0.5), "#80ff0000")
        compare(Palette.blend("#000000", "#80ffffff", 0.5).length, 9, "alpha mixes in")
    }
    function test_unmixableSnapsToTarget() {
        compare(Palette.blend("transparent", "#ffffff", 0.3), "#ffffff")
        compare(Palette.blend("#000000", "bogus", 0.3), "bogus")
    }
    function test_differs() {
        verify(!Palette.differs({ colors: { a: "#1" } }, { colors: { a: "#1" } }))
        verify(Palette.differs({ colors: { a: "#1" } }, { colors: { a: "#2" } }))
        verify(Palette.differs({ colors: { a: "#1" } }, { colors: { a: "#1", b: "#2" } }))
        verify(Palette.differs({}, { colors: { a: "#1" } }))
        verify(!Palette.differs({}, {}))
    }
}
