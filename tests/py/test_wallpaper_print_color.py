"""wallpaper-set.sh --print-color: the picker's colour preview (item_006).

Prints the accent extracted from an image without applying anything or writing
the colour cache, so scrolling the picker never touches the applied wallpaper.
Needs ImageMagick (magick); skipped without it. Run: python3 -m unittest discover tests/py
"""
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "wallpaper-set.sh"


@unittest.skipUnless(shutil.which("magick"), "ImageMagick not installed")
class PrintColor(unittest.TestCase):
    def run_script(self, home, *args):
        env = {"HOME": str(home), "PATH": "/usr/bin:/bin"}
        return subprocess.run(["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True, timeout=60)

    def test_prints_a_hex_colour_and_writes_no_state(self):
        with tempfile.TemporaryDirectory() as d:
            home = pathlib.Path(d)
            img = home / "wall.png"
            subprocess.run(["magick", "-size", "64x64", "xc:#20406a", "-fill", "#e0602a",
                            "-draw", "rectangle 0,0 40,64", str(img)], check=True)
            r = self.run_script(home, "--print-color", str(img))
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertRegex(r.stdout.strip(), r"^#[0-9a-fA-F]{6}$")
            cache = home / ".cache" / "wallpaper"
            self.assertFalse((cache / "last-color").exists(), "preview must not write the colour cache")
            self.assertFalse((cache / "last-wallpaper").exists(), "preview must not record a wallpaper")

    def test_missing_image_is_a_usage_error(self):
        with tempfile.TemporaryDirectory() as d:
            r = self.run_script(pathlib.Path(d), "--print-color", "/nonexistent.png")
            self.assertEqual(r.returncode, 2)
            self.assertIn("usage", r.stderr)

    def test_documented_in_the_header(self):
        self.assertRegex(SCRIPT.read_text(), re.compile(r"^#\s+wallpaper-set\.sh --print-color", re.M))


if __name__ == "__main__":
    unittest.main()
