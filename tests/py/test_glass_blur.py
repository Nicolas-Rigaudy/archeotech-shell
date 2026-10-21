"""Tests for the layer-blur lines theme-switch writes into mango (item_116).
Run: python3 -m unittest discover tests/py"""
import importlib.util
import pathlib
import unittest

_p = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "theme-switch.py"
_spec = importlib.util.spec_from_file_location("theme_switch", _p)
ts = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ts)

CONF = "focused_opacity=1.0\nunfocused_opacity=1.0\nblur=1\nblur_layer=0\nblur_optimized=1\n"


def val(text, key):
    return next(l.split("=", 1)[1] for l in text.splitlines() if l.startswith(key + "="))


class GlassBlur(unittest.TestCase):
    def test_glass_turns_layer_blur_on(self):
        out = ts.mango_opacity_lines(CONF, "dark", "glass")
        self.assertEqual(val(out, "blur_layer"), "1")
        self.assertEqual(val(out, "blur_optimized"), "1")   # xray by default

    def test_windows_source_disables_the_cached_blur(self):
        out = ts.mango_opacity_lines(CONF, "dark", "glass", blur="windows")
        self.assertEqual(val(out, "blur_optimized"), "0")

    def test_solid_and_packs_have_no_layer_blur(self):
        self.assertEqual(val(ts.mango_opacity_lines(CONF, "dark", "solid"), "blur_layer"), "0")
        self.assertEqual(val(ts.mango_opacity_lines(CONF, "dark", "glass", pack=True), "blur_layer"), "0")

    def test_missing_blur_keys_are_added(self):
        out = ts.mango_opacity_lines("blur=1\n", "dark", "glass", blur="windows")
        self.assertEqual(val(out, "blur_layer"), "1")
        self.assertEqual(val(out, "blur_optimized"), "0")

    def test_unknown_preset_uses_the_default_blur(self):
        self.assertEqual(val(ts.mango_opacity_lines(CONF, "dark", "nope"), "blur_layer"), "1")

    def test_window_blur_untouched(self):
        self.assertEqual(val(ts.mango_opacity_lines(CONF, "dark", "glass"), "blur"), "1")

    def test_brightness_tune_is_blur_mode_only(self):
        c = CONF + "blur_params_brightness=0.9\n"
        self.assertEqual(val(ts.mango_opacity_lines(c, "dark", "glass", blur="windows", tune="brightness"),
                             "blur_params_brightness"), "1.0")
        for blur in ("xray", "windows"):
            self.assertEqual(val(ts.mango_opacity_lines(c, "dark", "glass", blur=blur), "blur_params_brightness"), "0.9")
        self.assertEqual(val(ts.mango_opacity_lines(c, "dark", "glass", blur="xray", tune="brightness"),
                             "blur_params_brightness"), "0.9")

    def test_dropping_the_tune_restores_only_the_tuned_value(self):
        tuned = CONF + "blur_params_brightness=1.0\n"
        self.assertEqual(val(ts.mango_opacity_lines(tuned, "dark", "glass", blur="windows"),
                             "blur_params_brightness"), "0.9")
        hand = CONF + "blur_params_brightness=0.7\n"
        self.assertEqual(val(ts.mango_opacity_lines(hand, "dark", "glass", blur="windows"),
                             "blur_params_brightness"), "0.7")

    def test_brightness_tune_without_the_key_adds_nothing(self):
        self.assertNotIn("blur_params_brightness",
                         ts.mango_opacity_lines(CONF, "dark", "glass", blur="windows", tune="brightness"))


if __name__ == "__main__":
    unittest.main()
