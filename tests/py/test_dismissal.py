"""Dismissal is consistent across panel holders (item_017).

Esc: both holder types (Strip, BarPanel) claim keyboard focus when their panel
opens and close it on Escape. Global close: ShellState.closeAllAcross() (the
`ipc call panel close` bind, click outside, every panel's close()) emits
`dismissed`, and a bar uses it to drop its wifi/bluetooth/calendar/hover popups.
Run: python3 -m unittest discover tests/py
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text()


class Dismissal(unittest.TestCase):
    def test_holders_close_on_escape_and_claim_focus(self):
        for rel in ("Modules/Shell/Sides/Strip.qml", "Widgets/Bar/BarPanel.qml"):
            src = read(rel)
            with self.subTest(holder=rel):
                self.assertRegex(src, r"Keys\.onEscapePressed:\s*\w+\.close\(\)")
                self.assertIn("forceActiveFocus()", src)

    def test_close_all_emits_dismissed(self):
        src = read("Services/Shell/ShellState.qml")
        self.assertIn("signal dismissed()", src)
        body = re.search(r"function closeAllAcross\(\) \{(.*?)\n    \}", src, re.S).group(1)
        self.assertIn("root.dismissed()", body)

    def test_bar_drops_popups_on_dismissed(self):
        src = read("Modules/Shell/Sides/Bar.qml")
        handler = re.search(r"function onDismissed\(\) \{(.*?)\n        \}", src, re.S).group(1)
        for popup in ("_wifiPopupVisible", "_btPopupVisible", "_calendarVisible", "_popupVisible"):
            self.assertIn(popup, handler)

    def test_global_close_bind_exists(self):
        handler = re.search(r'target: "panel"(.*?)\n    \}', read("shell.qml"), re.S).group(1)
        self.assertIn("function close()", handler)
        self.assertIn("closeAllAcross()", handler.split("function close()")[1])


if __name__ == "__main__":
    unittest.main()
