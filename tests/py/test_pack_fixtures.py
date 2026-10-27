"""Bundled packs are real packs only; the engine's test packs live in tests/fixtures/packs.

Angular (recoloured base) and HUD (glow, grid texture, window brackets) were testing
packs. They stay loadable as fixtures so the engine capabilities they exercise keep a
regression check, but the Settings pack picker only lists packs/ (PackRegistry).
Run: python3 -m unittest discover tests/py
"""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "packs"
FIXTURES = ROOT / "tests" / "fixtures" / "packs"


def pack_dirs(parent):
    return sorted(p for p in parent.iterdir() if (p / "pack.json").is_file())


class PackFixtures(unittest.TestCase):
    def test_bundled_packs_are_real_packs_only(self):
        self.assertEqual([p.name for p in pack_dirs(BUNDLED)], ["grimdark"])

    def test_fixture_packs_exist(self):
        self.assertEqual([p.name for p in pack_dirs(FIXTURES)], ["angular", "hud"])

    def test_every_pack_loads(self):
        for d in pack_dirs(BUNDLED) + pack_dirs(FIXTURES):
            with self.subTest(pack=d.name):
                manifest = json.loads((d / "pack.json").read_text())
                tokens = json.loads((d / "tokens.json").read_text())
                self.assertEqual(manifest["id"], d.name)
                self.assertEqual(manifest["inherits"], "base")
                self.assertIsInstance(tokens, dict)
                for style in manifest.get("styles", []):
                    self.assertTrue((d / "styles" / f"{style}.qml").is_file(), style)

    def test_hud_fixture_keeps_the_engine_hooks(self):
        hud = json.loads((FIXTURES / "hud" / "pack.json").read_text())
        for key in ("fx.glow.strength", "fx.texture.opacity", "fx.brackets.enabled", "window.cornerRadius"):
            self.assertIn(key, hud["configSchema"])


if __name__ == "__main__":
    unittest.main()
