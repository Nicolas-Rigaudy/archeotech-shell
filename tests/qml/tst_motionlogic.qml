import QtQuick
import QtTest
import "../../Commons/MotionLogic.js" as Motion

// Animation scale and reduced motion (Commons/MotionLogic.js).
// Run: tests/run.sh
TestCase {
    name: "MotionLogic"

    function test_clampScale() {
        compare(Motion.clampScale(1), 1)
        compare(Motion.clampScale("0.5"), 0.5)
        compare(Motion.clampScale(-1), 0)
        compare(Motion.clampScale(9), 2)
        compare(Motion.clampScale(undefined), 1, "unset = as designed")
        compare(Motion.clampScale("fast"), 1, "garbage = as designed")
    }
    function test_effectsScale() {
        compare(Motion.effects(200, 1), 200)
        compare(Motion.effects(200, 0.5), 100)
        compare(Motion.effects(150, 1.5), 225)
        compare(Motion.effects(200, 0), 0, "off")
    }
    function test_reducedKeepsEffectsDropsSpatial() {
        compare(Motion.effects(200, 1), 200)
        compare(Motion.spatial(400, 1, true), 0)
        compare(Motion.spatial(400, 1, false), 400)
        compare(Motion.spatial(400, 0.5, false), 200)
    }
}
