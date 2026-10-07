"""Tests for scripts/display-profile.py (item_135 wave 2). Run: python3 -m unittest discover tests/py"""
import importlib.util
import pathlib
import unittest

_p = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "display-profile.py"
_spec = importlib.util.spec_from_file_location("display_profile", _p)
dp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dp)


def out(name, make, model, serial, x, y, w=1920, h=1080, transform="normal", enabled=True):
    return {"name": name, "make": make, "model": model, "serial": serial, "enabled": enabled,
            "position": {"x": x, "y": y}, "transform": transform, "scale": 1,
            "modes": [{"width": 1280, "height": 720, "refresh": 60, "current": False, "preferred": False},
                      {"width": w, "height": h, "refresh": 60.0, "current": True, "preferred": True}]}


# The owner's work desk (wlr-randr, 2026-10-01).
EDP = out("eDP-1", "BOE", "0x0A32", None, 0, 0, 1920, 1200)
HDMI = out("HDMI-A-1", "Iiyama North America", "PL2493H", "1211534013071", 1920, 60)
DP3 = out("DP-3", "Iiyama North America", "PL2493H", "1238341902693", 3840, 0, transform="270")
WORK = [EDP, HDMI, DP3]


class DisplayProfile(unittest.TestCase):
    def test_identity(self):
        self.assertEqual(dp.identity(HDMI), "Iiyama North America|PL2493H|1211534013071")
        self.assertEqual(dp.identity(EDP), "BOE|0x0A32|@eDP-1", "no serial: connector stands in")
        self.assertNotEqual(dp.identity(HDMI), dp.identity(DP3), "identical models told apart by serial")

    def test_junk_serial_is_no_serial(self):
        self.assertEqual(dp.identity(dict(HDMI, serial="0")), "Iiyama North America|PL2493H|@HDMI-A-1")
        self.assertEqual(dp.identity(dict(HDMI, serial="Unknown")), "Iiyama North America|PL2493H|@HDMI-A-1")

    def test_why_not(self):
        store = dp.save({}, "Work", WORK)
        self.assertEqual(dp.why_not(store["profiles"][0], [EDP]), "needs monitors that are not connected")
        off = dp.save({}, "Off", [dict(EDP, enabled=False)])
        self.assertEqual(dp.why_not(off["profiles"][0], [EDP]), "would turn every screen off")

    def test_set_changed_announces_once_per_set(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            dp.STAMP = pathlib.Path(d) / "last-set"
            work, laptop = dp.set_key(WORK), dp.set_key([EDP])
            self.assertTrue(dp.set_changed(work), "dock: first time this set is seen")
            self.assertFalse(dp.set_changed(work), "reload with the same screens: silent")
            self.assertTrue(dp.set_changed(laptop), "undock")
            self.assertTrue(dp.set_changed(work), "re-dock announces again")

    def test_snapshot_uses_current_mode(self):
        e = dp.snapshot([EDP])[0]
        self.assertEqual(e["mode"], {"width": 1920, "height": 1200, "refresh": 60.0})
        self.assertEqual((e["x"], e["y"], e["transform"]), (0, 0, "normal"))

    def test_match_exact_set_only(self):
        store = dp.save({}, "Work", WORK)
        store = dp.save(store, "Laptop", [EDP])
        self.assertEqual(dp.match(store["profiles"], WORK)["name"], "Work")
        self.assertEqual(dp.match(store["profiles"], [EDP])["name"], "Laptop")
        self.assertIsNone(dp.match(store["profiles"], [EDP, HDMI]), "a subset is a different setup")

    def test_match_follows_monitor_not_connector(self):
        store = dp.save({}, "Work", WORK)
        # The same two Iiyamas plugged into swapped ports still match by serial...
        swapped = [EDP, dict(HDMI, name="DP-3"), dict(DP3, name="HDMI-A-1")]
        self.assertEqual(dp.match(store["profiles"], swapped)["name"], "Work")
        # ...and the portrait settings follow the DP-3 MONITOR to its new port.
        a = " ".join(dp.argv(store["profiles"][0], swapped))
        self.assertIn("--output HDMI-A-1 --on --mode 1920x1080@60.000Hz --pos 3840,0 --transform 270", a)
        # A different monitor on HDMI-A-1 is not the work screen.
        home = [EDP, out("HDMI-A-1", "Dell", "U2723QE", "XYZ", 1920, 0)]
        self.assertIsNone(dp.match(store["profiles"], home))

    def test_save_replaces_same_name_or_same_set(self):
        store = dp.save({}, "Work", WORK)
        store = dp.save(store, "Office", WORK)          # same monitors, new name
        self.assertEqual([p["name"] for p in store["profiles"]], ["Office"])
        store = dp.save(store, "Office", [EDP])          # same name, other monitors
        self.assertEqual(len(store["profiles"]), 1)
        self.assertEqual(len(store["profiles"][0]["outputs"]), 1)

    def test_argv_refuses_missing_or_all_off(self):
        store = dp.save({}, "Work", WORK)
        self.assertIsNone(dp.argv(store["profiles"][0], [EDP]), "profile monitor not connected")
        off = dp.save({}, "Off", [dict(EDP, enabled=False)])
        self.assertIsNone(dp.argv(off["profiles"][0], [EDP]), "would turn every screen off")

    def test_argv_skips_mode_the_monitor_no_longer_offers(self):
        store = dp.save({}, "Work", WORK)
        no_modes = [EDP, dict(HDMI, modes=[]), DP3]       # e.g. disabled, lists no modes
        a = " ".join(dp.argv(store["profiles"][0], no_modes))
        self.assertIn("--output HDMI-A-1 --on --pos 1920,60", a, "no --mode: compositor picks native")
        self.assertIn("--output DP-3 --on --mode 1920x1080@60.000Hz", a)

    def test_in_place(self):
        store = dp.save({}, "Work", WORK)
        self.assertTrue(dp.in_place(store["profiles"][0], WORK))
        self.assertFalse(dp.in_place(store["profiles"][0], [EDP, HDMI, dict(DP3, transform="normal")]))
        self.assertFalse(dp.in_place(store["profiles"][0], [EDP, dict(HDMI, enabled=False), DP3]))

    def test_mismatches(self):
        store = dp.save({}, "Work", WORK)
        self.assertEqual(dp.mismatches(store["profiles"][0], WORK), [])
        moved = [EDP, dict(HDMI, position={"x": 5760, "y": 0}), DP3]
        self.assertEqual(dp.mismatches(store["profiles"][0], moved), ["HDMI-A-1"])

    def test_argv_disabled_output(self):
        store = dp.save({}, "Lid", [dict(EDP, enabled=False), HDMI])
        a = " ".join(dp.argv(store["profiles"][0], [EDP, HDMI]))
        self.assertIn("--output eDP-1 --off", a)
        self.assertIn("--output HDMI-A-1 --on", a)


if __name__ == "__main__":
    unittest.main()
