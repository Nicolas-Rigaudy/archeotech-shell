import QtQuick
import QtTest
import "../../Services/System/NotificationsLogic.js" as Logic

// Notification history save / restore (Services/System/NotificationsLogic.js, item_119).
TestCase {
    name: "NotificationsLogic"

    function entry(id, summary) {
        return { id: id, appIcon: "", appName: "app", summary: summary, body: "b", urgency: 1, timestamp: "10:00" }
    }

    function test_roundTripDropsLiveObject() {
        var e = entry(3, "hello")
        e._notif = { id: 3 }
        var back = Logic.restore(Logic.serialize([e]))
        compare(back.length, 1)
        compare(back[0].summary, "hello")
        compare(back[0].id, 3)
        compare(back[0]._notif, undefined, "the live notification is never written")
    }
    function test_keepsNewestUpToLimit() {
        var h = []
        for (var i = 0; i < Logic.HISTORY_LIMIT + 5; i++) h.push(entry(i, "n" + i))
        var back = Logic.restore(Logic.serialize(h))
        compare(back.length, Logic.HISTORY_LIMIT)
        compare(back[0].summary, "n5", "oldest dropped")
        compare(back[back.length - 1].summary, "n" + (Logic.HISTORY_LIMIT + 4))
    }
    function test_badContentRestoresNothing() {
        compare(Logic.restore(""), [])
        compare(Logic.restore("{not json"), [])
        compare(Logic.restore("[1,2]"), [])
        compare(Logic.restore('{"history": "x"}'), [])
        compare(Logic.restore('{"history": [null, 4, {"summary": ""}]}'), [], "empty or foreign rows skipped")
    }
    function test_missingFieldsGetDefaults() {
        var back = Logic.restore('{"history": [{"summary": "s"}]}')
        compare(back[0].urgency, 0)
        compare(back[0].id, -1)
        compare(back[0].body, "")
    }
    function test_reattachById() {
        var live = { id: 7 }
        var h = Logic.reattach([entry(7, "a"), entry(8, "b"), entry(-1, "c")], [live, { id: 9 }])
        verify(h[0]._notif === live)
        compare(h[1]._notif, undefined, "not tracked any more")
        compare(h[2]._notif, undefined)
    }
}
