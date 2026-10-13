"""Every tooltip uses the shell's Tooltip primitive (Commons/Primitives/Tooltip.qml).

A stock QtQuick.Controls ToolTip renders in the platform style, which does not
match the shell (owner, 2026-10-13). Run: python3 -m unittest discover tests/py
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PRIMITIVE = ROOT / "Commons" / "Primitives" / "Tooltip.qml"


class Tooltips(unittest.TestCase):
    def test_no_stock_tooltip(self):
        for f in ROOT.rglob("*.qml"):
            if f == PRIMITIVE or ".git" in f.parts:
                continue
            for n, line in enumerate(f.read_text().splitlines(), 1):
                code = line.split("//", 1)[0]
                with self.subTest(file=f"{f.relative_to(ROOT)}:{n}"):
                    self.assertNotRegex(code, r"\bToolTip\s*(\{|\.)",
                                        "use Prim.Tooltip (Commons/Primitives/Tooltip.qml), not a stock ToolTip")


if __name__ == "__main__":
    unittest.main()
