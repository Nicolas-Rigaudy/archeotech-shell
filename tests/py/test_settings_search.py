"""Settings search index and config defaults stay in sync with the panes (item_138).

Panes are lazy-loaded, so the search index (Modules/Settings/SettingsSearchLogic.js)
is declared rather than registered at runtime. These checks keep it honest:
  - every index key has a row or SearchTarget in its pane (a jump never dead-ends);
  - every searchable row is in the index (a new row is findable);
  - a key with a default in ConfigDefaults.js has no inline default at call sites
    (declared once, so reset and readers agree).
Run: python3 -m unittest discover tests/py
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PANES = ROOT / "Modules" / "Settings" / "Panes"


def _index():
    js = (ROOT / "Modules" / "Settings" / "SettingsSearchLogic.js").read_text()
    return re.findall(r'\{ pane: "([a-z]+)",\s*key: "([^"]+)"', js)


def _pane_keys(pane):
    qml = (PANES / (pane[0].upper() + pane[1:] + "Pane.qml")).read_text()
    return set(re.findall(r'(?:searchKey|configKey|SearchTarget \{ key): "([^"]+)"', qml))


class SettingsSearch(unittest.TestCase):
    def test_index_keys_unique(self):
        keys = [k for _, k in _index()]
        self.assertEqual(len(keys), len(set(keys)))

    def test_every_index_key_has_a_target_in_its_pane(self):
        for pane, key in _index():
            with self.subTest(key=key):
                self.assertIn(key, _pane_keys(pane), f"{key}: no searchKey/configKey/SearchTarget in {pane}")

    def test_every_searchable_row_is_indexed(self):
        indexed = {(p, k) for p, k in _index()}
        panes = {p for p, _ in indexed}
        for pane in panes:
            for key in _pane_keys(pane):
                with self.subTest(pane=pane, key=key):
                    self.assertIn((pane, key), indexed, f"{key} in {pane} is not in SettingsSearchLogic.INDEX")

    def test_defaults_declared_once(self):
        js = (ROOT / "Services" / "Persistence" / "ConfigDefaults.js").read_text()
        keys = re.findall(r'^\s*"([a-zA-Z.]+)":', js, re.M)
        self.assertTrue(keys)
        for f in ROOT.rglob("*.qml"):
            src = f.read_text()
            for key in keys:
                with self.subTest(file=str(f.relative_to(ROOT)), key=key):
                    self.assertNotRegex(src, r'Config\.get\("' + re.escape(key) + r'",',
                                        "inline default for a key declared in ConfigDefaults.js")


if __name__ == "__main__":
    unittest.main()
