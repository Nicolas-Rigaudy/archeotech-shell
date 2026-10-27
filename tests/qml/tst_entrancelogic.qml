import QtQuick
import QtTest
import "../../Commons/Primitives/EntranceLogic.js" as Entrance

// EntranceStagger timing (Commons/Primitives/EntranceLogic.js). Run: tests/run.sh
TestCase {
    name: "EntranceLogic"

    function test_startDelayGrowsWithIndex() {
        compare(Entrance.startDelay(0, 55, 90), 90)
        compare(Entrance.startDelay(3, 55, 90), 255)
    }
    function test_negativeInputsFloorAtZero() {
        compare(Entrance.startDelay(-2, 55, -10), 0)
        compare(Entrance.startDelay(2, -5, 0), 0)
    }
    function test_totalTime() {
        compare(Entrance.totalTime(6, 55, 90, 350), 90 + 5 * 55 + 350)
        compare(Entrance.totalTime(0, 55, 90, 350), 90 + 350, "empty = base + duration")
    }
    function test_offset() {
        compare(Entrance.offset(0, 14), 14)
        compare(Entrance.offset(1, 14), 0)
        fuzzyCompare(Entrance.offset(0.5, 14), 7, 0.0001)
        compare(Entrance.offset(2, 14), 0, "over-shoot clamps")
        compare(Entrance.offset(-1, 14), 14, "under-shoot clamps")
    }
}
