"""The tray context menu is the shell's own glass menu (item_039).

TrayWidget draws the app's DBusMenu through TrayMenu (a focus-grabbing PopupWindow
over a QsMenuOpener) instead of the platform QMenu, and raises the usual bar hover
card for the item's tooltip. TrayMenuList expands submenus by loading its own file
by URL: QML refuses a component that instantiates itself statically ("instantiated
recursively"), which silently removed the whole tray widget. Run: python3 -m unittest discover tests/py
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BAR = ROOT / "Widgets" / "Bar"


def read(name):
    return (BAR / name).read_text()


class TrayMenu(unittest.TestCase):
    def test_tray_uses_the_glass_menu_not_the_platform_menu(self):
        src = read("TrayWidget.qml")
        self.assertNotIn("QsMenuAnchor", src)
        self.assertIn("TrayMenu {", src)

    def test_menu_is_a_grabbing_popup_over_an_opener(self):
        src = read("TrayMenu.qml")
        self.assertRegex(src, r"PopupWindow\s*\{")
        self.assertIn("grabFocus", src)
        self.assertIn("TrayMenuList", src)
        self.assertIn("QsMenuOpener", read("TrayMenuList.qml"))

    def test_menu_waits_for_its_entries(self):
        # A popup window cannot grow after it is shown, so it opens once entries exist.
        self.assertIn("visible: wanted && list.rowCount > 0", read("TrayMenu.qml"))

    def test_submenus_load_by_url_never_by_self_component(self):
        src = read("TrayMenuList.qml")
        self.assertIn('source: "TrayMenuList.qml"', src)
        self.assertNotRegex(src, r"sourceComponent:\s*TrayMenuList")

    def test_tray_hover_card_matches_the_other_widgets(self):
        src = read("TrayWidget.qml")
        self.assertRegex(src, r"holderRoot\.showPopup\(cell, \"TRAY\"")
        self.assertRegex(src, r"holderRoot\.hidePopup\(cell\)")


if __name__ == "__main__":
    unittest.main()
