"""Accent picker works for every theme family, GTK degrades gracefully (item_091).

All theme.json palettes carry the same 14 colour names, so theme-switch.py's
apply_accent drives QML, kitty, rofi, mango and Obsidian from any of them; GTK, the
cursor and the VSCode extension accent only follow where per-accent packages exist
(Catppuccin) and are left alone elsewhere. Run: python3 -m unittest discover tests/py
"""
import copy
import importlib.util
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("theme_switch", ROOT / "scripts" / "theme-switch.py")
ts = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ts)

CATALOG = (ROOT / "Services" / "Theming" / "ThemeCatalog.qml").read_text()
NAMES = re.search(r"_namedAccents: \[(.*?)\]", CATALOG, re.S).group(1)
NAMES = re.findall(r'"(\w+)"', NAMES)
THEMES = sorted(p for p in (ROOT / "themes").iterdir() if (p / "theme.json").is_file())


def families():
    """family id -> accents expression in ThemeCatalog.qml."""
    return dict(re.findall(r'id: "([\w-]+)", label: "[^"]+",\s*(?:swatch:[^\n]*\n\s*)?accents: (_namedAccents|\[\])', CATALOG))


class AccentFamilies(unittest.TestCase):
    def test_catalog_offers_accents_for_all_but_monochrome(self):
        fams = families()
        self.assertEqual(set(fams), {"catppuccin", "dracula", "tokyo-night", "gruvbox", "nord", "monochrome"})
        for fam, expr in fams.items():
            with self.subTest(family=fam):
                self.assertEqual(expr, "[]" if fam == "monochrome" else "_namedAccents")

    def test_every_theme_carries_every_accent_name(self):
        for d in THEMES:
            colors = json.loads((d / "theme.json").read_text())["colors"]
            for name in NAMES:
                with self.subTest(theme=d.name, accent=name):
                    self.assertIn(name, colors)

    def test_apply_accent_drives_the_portable_targets(self):
        for d in THEMES:
            theme = json.loads((d / "theme.json").read_text())
            vars_ = {}
            with self.subTest(theme=d.name):
                before = copy.deepcopy(theme.get("gtk"))
                ts.apply_accent(theme, vars_, "pink")
                hexv = theme["colors"]["pink"]
                self.assertEqual(theme["accent"], "pink")
                self.assertEqual(theme["mango"]["focuscolor"], "0x" + hexv.lstrip("#") + "ff")
                self.assertEqual(theme["rofi"]["border"], hexv)
                self.assertEqual(theme["kitty"]["accent"], hexv)
                if theme.get("family") != "catppuccin":
                    self.assertEqual(theme.get("gtk"), before, "no per-accent GTK package: keep the variant's own")
                    self.assertNotIn("accent", theme.get("vscode", {}))

    def test_unknown_accent_is_ignored(self):
        theme = json.loads((THEMES[0] / "theme.json").read_text())
        before = copy.deepcopy(theme)
        ts.apply_accent(theme, {}, "not-a-colour")
        self.assertEqual(theme, before)


if __name__ == "__main__":
    unittest.main()
