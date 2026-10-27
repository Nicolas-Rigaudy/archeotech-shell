"""Interactive primitives show keyboard focus and a disabled state (item_113).

Every primitive a user can operate must join the Tab chain, draw the shared
FocusRing, and dim when `enabled: false`. Add new interactive primitives to
INTERACTIVE. Run: python3 -m unittest discover tests/py
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PRIM = ROOT / "Commons" / "Primitives"
INTERACTIVE = ["GlassButton", "ToggleSwitch", "SegmentedControl"]


class PrimitiveStates(unittest.TestCase):
    def test_interactive_primitives_have_focus_and_disabled_states(self):
        for name in INTERACTIVE:
            src = (PRIM / f"{name}.qml").read_text()
            with self.subTest(primitive=name):
                self.assertIn("activeFocusOnTab: enabled", src)
                self.assertIn("FocusRing {", src)
                self.assertIn("Appearance.disabledOpacity", src)
                self.assertIn("Keys.on", src, "keyboard activation")


if __name__ == "__main__":
    unittest.main()
