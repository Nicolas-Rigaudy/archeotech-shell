"""Tests for the mango colour key names theme-switch writes (mango 0.18 renamed
bordercolor -> border_color, ...). Run: python3 -m unittest discover tests/py"""
import importlib.util
import pathlib
import unittest

_p = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "theme-switch.py"
_spec = importlib.util.spec_from_file_location("theme_switch", _p)
ts = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ts)

THEME = {"mango": {"shadowscolor": "0x00000066", "bordercolor": "0x111111ff",
                   "focuscolor": "0x222222ff", "urgentcolor": "0x333333ff"}}
OLD = "shadowscolor=0x0\nbordercolor=0x0\nfocuscolor=0x0\nurgentcolor=0x0\n"
NEW = "shadows_color=0x0\nborder_color=0x0\nfocus_color=0x0\nurgent_color=0x0\n"


def keys(text):
    return {l.split("=", 1)[0]: l.split("=", 1)[1] for l in text.splitlines() if "=" in l}


class MangoKeys(unittest.TestCase):
    def test_018_config_gets_018_names(self):
        k = keys(ts.mango_theme_text(NEW, THEME))
        self.assertEqual(k["border_color"], "0x111111ff")
        self.assertEqual(k["focus_color"], "0x222222ff")
        self.assertEqual(k["urgent_color"], "0x333333ff")
        self.assertEqual(k["shadows_color"], "0x00000066")
        self.assertFalse({"bordercolor", "focuscolor", "urgentcolor", "shadowscolor"} & k.keys())

    def test_017_config_keeps_017_names(self):
        k = keys(ts.mango_theme_text(OLD, THEME))
        self.assertEqual(k["bordercolor"], "0x111111ff")
        self.assertFalse({"border_color", "focus_color", "urgent_color", "shadows_color"} & k.keys())

    def test_other_keys_unchanged(self):
        self.assertEqual(ts.mango_key(NEW, "cursor_theme"), "cursor_theme")
        self.assertEqual(ts.mango_key("", "bordercolor"), "border_color")


if __name__ == "__main__":
    unittest.main()
