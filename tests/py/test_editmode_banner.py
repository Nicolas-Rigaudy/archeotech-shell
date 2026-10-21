"""Edit Mode banner is a docked, opaque toolbar over the real bar (item_130).

The old floating pill let the dimmed bar's clock poke out around it. The banner now
spans the top edge, is opaque and at least as tall as the bar, so nothing of the
bar can show beside or through it. Run: python3 -m unittest discover tests/py
"""
import pathlib
import re
import unittest

SRC = (pathlib.Path(__file__).resolve().parents[2] / "Modules" / "Shell" / "Builder" / "EditOverlay.qml").read_text()


class EditModeBanner(unittest.TestCase):
    def banner(self):
        return re.search(r"id: banner\n(.*?)\n        Row \{\n            id: bannerRow", SRC, re.S).group(1)

    def test_spans_the_top_edge(self):
        self.assertIn("anchors { top: parent.top; left: parent.left; right: parent.right }", self.banner())

    def test_is_opaque(self):
        color = re.search(r"\n        color: (.*)", self.banner()).group(1)
        self.assertNotIn("rgba", color)
        self.assertIn("colors.base", color)

    def test_covers_the_bar_row(self):
        h = re.search(r"height: (.*)", self.banner()).group(1)
        self.assertIn("bar.marginTop + Commons.Appearance.bar.height", h)


if __name__ == "__main__":
    unittest.main()
