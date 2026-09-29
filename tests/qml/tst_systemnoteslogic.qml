import QtQuick
import QtTest
import "../../Modules/Dashboard/panels/SystemNotesLogic.js" as Logic

// System Notes stat selection + source parsing (SystemNotesLogic.js).
TestCase {
    name: "SystemNotesLogic"

    function test_selection_defaultsToAll() {
        compare(Logic.selection(undefined), Logic.ids())
        compare(Logic.selection(null), Logic.ids())
        compare(Logic.selection("garbage"), Logic.ids(), "a non-array config means all")
    }
    function test_selection_cleansAndOrders() {
        compare(Logic.selection(["ip", "bogus", "uptime", "ip"]), ["uptime", "ip"],
                "unknown ids and duplicates dropped, registry order kept")
        compare(Logic.selection([]), [], "an empty list shows nothing")
    }
    function test_toggle() {
        compare(Logic.toggle(null, "aws", false).indexOf("aws"), -1, "off from the default set")
        compare(Logic.toggle(["ip"], "uptime", true), ["uptime", "ip"], "on keeps registry order")
        compare(Logic.toggle(["ip"], "ip", true), ["ip"], "no duplicates")
        verify(Logic.isOn(["vpn"], "vpn")); verify(!Logic.isOn(["vpn"], "aws"))
    }

    function test_parseSnapper() {
        compare(Logic.parseSnapper("number,date\n0,\n7,2025-12-02 16:30:11\n2288,2026-09-29 10:24:59\n12,2025-12-03 09:00:00"),
                "2026-09-29 10:24:59", "newest by number, not by line order")
        compare(Logic.parseSnapper("number,date\n0,\n"), "none", "only the current system")
        compare(Logic.parseSnapper(""), "none")
    }

    function test_shortStamp() {
        var now = new Date(2026, 8, 29, 12, 0)
        compare(Logic.shortStamp("2026-09-29 10:24:59", now), "today 10:24")
        compare(Logic.shortStamp("2026-09-28 17:00:08", now), "Sep 28 17:00")
        compare(Logic.shortStamp("none", now), "none", "non-dates pass through")
    }

    function test_parseVpn_typeOnly() {
        compare(Logic.parseVpn("vpn-lab:802-11-wireless\ndocker0:bridge"), "inactive",
                "a Wi-Fi named vpn-lab is not a VPN")
        compare(Logic.parseVpn("Home:802-11-wireless\nwg-work:wireguard"), "wg-work", "WireGuard counts")
        compare(Logic.parseVpn("Office VPN:vpn"), "Office VPN")
        compare(Logic.parseVpn("a\\:b:vpn"), "a:b", "nmcli -t escaped colon")
        compare(Logic.parseVpn(""), "inactive")
    }

    function test_formatUpdates() {
        compare(Logic.formatUpdates("0 0"), "up to date")
        compare(Logic.formatUpdates("9 0"), "9 pkgs")
        compare(Logic.formatUpdates("0 3"), "3 AUR")
        compare(Logic.formatUpdates("9 3\n"), "9 + 3 AUR")
    }
}
