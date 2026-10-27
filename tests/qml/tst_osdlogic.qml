import QtQuick
import QtTest
import "../../Modules/OSD/OsdLogic.js" as Logic

// OSD follows state changes (Modules/OSD/OsdLogic.js, item_120).
TestCase {
    name: "OsdLogic"

    function ctx(now, sinkAt) { return { now: now, armedAt: 0, sinkChangedAt: sinkAt } }

    function test_volumeFromAnySource() {
        compare(Logic.trigger("volume", 40, 45, ctx(10000, -100000)), "volume")
        compare(Logic.trigger("muted", false, true, ctx(10000, -100000)), "volume", "mute shows the volume OSD")
        compare(Logic.trigger("brightness", 50, 55, ctx(10000)), "brightness")
    }
    function test_noChangeNoOsd() {
        compare(Logic.trigger("volume", 40, 40, ctx(10000, -100000)), "")
        compare(Logic.trigger("brightness", 50, 50, ctx(10000)), "")
    }
    function test_startupReadsAreSilent() {
        compare(Logic.trigger("volume", 0, 45, ctx(Logic.ARM_DELAY_MS - 1, -100000)), "")
        compare(Logic.trigger("brightness", 50, 80, ctx(500)), "", "first brightnessctl read")
        compare(Logic.trigger("brightness", 50, 80, ctx(Logic.ARM_DELAY_MS)), "brightness")
    }
    function test_sinkSwitchIsSilent() {
        compare(Logic.trigger("volume", 30, 70, ctx(10000, 10000 - 100)), "", "new sink's volume")
        compare(Logic.trigger("muted", false, true, ctx(10000, 10000 - 100)), "")
        compare(Logic.trigger("volume", 30, 70, ctx(10000, 10000 - Logic.SINK_SETTLE_MS)), "volume")
        compare(Logic.trigger("brightness", 50, 55, ctx(10000, 10000 - 100)), "brightness", "sink switch does not mute brightness")
    }
    function test_unknownKind() {
        compare(Logic.trigger("micVolume", 10, 20, ctx(10000)), "")
    }
}
