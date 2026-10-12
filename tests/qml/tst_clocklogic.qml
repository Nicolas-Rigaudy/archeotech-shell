import QtQuick
import QtTest
import "../../Services/System/ClockLogic.js" as Clock

// Global clock format patterns (Services/System/ClockLogic.js).
// Run: tests/run.sh
TestCase {
    name: "ClockLogic"

    function test_timeFormat() {
        compare(Clock.timeFormat("24h", false), "HH:mm")
        compare(Clock.timeFormat("24h", true), "HH:mm:ss")
        compare(Clock.timeFormat("12h", false), "h:mm AP")
        compare(Clock.timeFormat("12h", true), "h:mm:ss AP")
        compare(Clock.timeFormat(undefined, undefined), "HH:mm", "unset = 24h, no seconds")
    }
    function test_hourFormat() {
        compare(Clock.hourFormat("24h"), "HH")
        compare(Clock.hourFormat("12h"), "h")
    }
    function test_dateFormat() {
        compare(Clock.dateFormat("short"), "ddd d MMM")
        compare(Clock.dateFormat("iso"), "yyyy-MM-dd")
        compare(Clock.dateFormat("none"), "")
        compare(Clock.dateFormat("bogus"), "ddd d MMM", "unknown = short")
        compare(Qt.formatDateTime(new Date(2026, 9, 12, 14, 5, 9), Clock.timeFormat("12h", true)), "2:05:09 PM")
    }
}
