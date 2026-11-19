"""wallpaper-set.sh fit modes (item_148): each output gets an image built at its
own size; screens of the image's orientation get the raw image (centre crop by
awww); the fit and anchor come from config.json or WALLPAPER_FIT/_ANCHOR.

Uses a fake `awww` on PATH (query lists three outputs, img calls are logged), so
no wallpaper daemon is touched. Needs ImageMagick; skipped without it.
Run: python3 -m unittest discover tests/py
"""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "wallpaper-set.sh"

FAKE_AWWW = """#!/bin/bash
if [ "$1" = query ]; then
  printf ': eDP-1: 160x100, scale: 1, currently displaying: image: x\\n'
  printf ': DP-3: 90x160, scale: 1, currently displaying: image: x\\n'
else echo "$*" >> "$AWWW_LOG"; fi
"""


@unittest.skipUnless(shutil.which("magick"), "ImageMagick not installed")
class Harness(unittest.TestCase):
    def setUp(self):
        self._d = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.home = pathlib.Path(self._d.name)
        bindir = self.home / "bin"
        bindir.mkdir()
        (bindir / "awww").write_text(FAKE_AWWW)
        (bindir / "awww").chmod(0o755)
        self.bin = bindir
        self.log = self.home / "awww.log"
        # Landscape 3:2 test image: left third red, middle green, right third blue.
        self.img = self.home / "wall.png"
        subprocess.run(["magick", "-size", "300x200", "xc:#00ff00",
                        "-fill", "#ff0000", "-draw", "rectangle 0,0 99,199",
                        "-fill", "#0000ff", "-draw", "rectangle 200,0 299,199", str(self.img)], check=True)

    def tearDown(self):
        self._d.cleanup()

    def env(self, **extra):
        e = {"HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin", "AWWW_LOG": str(self.log)}
        e.update(extra)
        return e

    def run_script(self, config=None, args=None, rc=0, **env_extra):
        if config is not None:
            cfg = self.home / ".config" / "archeotech"
            cfg.mkdir(parents=True, exist_ok=True)
            (cfg / "config.json").write_text(json.dumps(config))
        argv = args if args is not None else [str(self.img)]
        r = subprocess.run(["bash", str(SCRIPT), *argv], env=self.env(**env_extra), capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, rc, r.stderr)
        sent = {}
        for line in self.log.read_text().splitlines():
            parts = line.split()
            sent[parts[parts.index("--outputs") + 1]] = parts[1]
        return sent

    def size(self, path):
        return subprocess.run(["magick", "identify", "-format", "%wx%h", path],
                              capture_output=True, text=True, check=True).stdout

    def pixel(self, path, x, y):
        return subprocess.run(["magick", path, "-format", f"%[hex:p{{{x},{y}}}]", "info:"],
                              capture_output=True, text=True, check=True).stdout[:6].upper()


class Fit(Harness):
    def test_default_fill_centre_sends_the_raw_image_everywhere(self):
        sent = self.run_script()
        self.assertEqual(sent, {"eDP-1": str(self.img), "DP-3": str(self.img)})

    def test_anchor_from_config_crops_the_portrait_output_only(self):
        sent = self.run_script({"wallpaper": {"fit": "fill", "anchor": "left"}})
        self.assertEqual(sent["eDP-1"], str(self.img), "same orientation stays a raw centre crop")
        self.assertEqual(self.size(sent["DP-3"]), "90x160")
        self.assertEqual(self.pixel(sent["DP-3"], 45, 80), "FF0000", "left anchor keeps the left (red) part")

    def test_env_overrides_config(self):
        sent = self.run_script({"wallpaper": {"fit": "fill", "anchor": "left"}}, WALLPAPER_ANCHOR="right")
        self.assertEqual(self.pixel(sent["DP-3"], 45, 80), "0000FF")

    def test_blur_and_edges_build_full_size_portrait_images(self):
        for fit in ("blur", "edges"):
            with self.subTest(fit=fit):
                self.log.unlink(missing_ok=True)
                sent = self.run_script(WALLPAPER_FIT=fit)
                self.assertEqual(self.size(sent["DP-3"]), "90x160")
                self.assertIn(f"-plain-{fit}-centre-90x160.png", sent["DP-3"])

    def test_unknown_values_fall_back_to_fill_centre(self):
        sent = self.run_script({"wallpaper": {"fit": "zoom", "anchor": "up"}})
        self.assertEqual(sent["DP-3"], str(self.img))

    @unittest.skipUnless(shutil.which("rsvg-convert"), "rsvg-convert not installed")
    def test_logo_builds_one_composite_per_output_size_and_reuses_it(self):
        cache = self.home / ".cache" / "wallpaper"
        cache.mkdir(parents=True)
        (cache / "logo-active").write_text("arch")
        sent = self.run_script(WALLPAPER_FIT="edges")
        # Same orientation: fill/centre; the rotated screen: the chosen fit.
        self.assertTrue(sent["eDP-1"].endswith("-arch-fill-centre-160x100.png"), sent)
        self.assertTrue(sent["DP-3"].endswith("-arch-edges-centre-90x160.png"), sent)
        self.assertEqual(self.size(sent["eDP-1"]), "160x100")
        self.assertEqual(self.size(sent["DP-3"]), "90x160")
        mtime = os.path.getmtime(sent["DP-3"])
        self.log.unlink()
        again = self.run_script(WALLPAPER_FIT="edges")
        self.assertEqual(again, sent)
        self.assertEqual(os.path.getmtime(sent["DP-3"]), mtime, "second run is a cache hit")
        # The detached warm (other logos) may still be building: give it time,
        # then no build scratch may remain.
        deadline = time.time() + 60
        while True:
            left = [p.name for p in (cache / "composed").iterdir() if p.name.startswith((".work", "edges."))]
            if not left or time.time() > deadline:
                break
            time.sleep(0.2)
        self.assertEqual(left, [], "no build scratch left behind")

    @unittest.skipUnless(shutil.which("rsvg-convert"), "rsvg-convert not installed")
    def test_warm_all_builds_every_logo_for_every_output(self):
        walls = self.home / "walls"
        walls.mkdir()
        shutil.copy(self.img, walls / "wall.png")
        r = subprocess.run(["bash", str(SCRIPT), "--warm-all", str(walls)], env=self.env(WALLPAPER_FIT="blur"),
                           capture_output=True, text=True, timeout=180)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("FAILED", r.stdout)
        names = sorted(p.name.split("-", 1)[1] for p in (self.home / ".cache/wallpaper/composed").glob("*.png"))
        expect = sorted(f"{lg}-{fit}-{sz}.png" for lg in ("arch", "rebel", "imperial")
                        for fit, sz in (("fill-centre", "160x100"), ("blur-centre", "90x160")))
        self.assertEqual(names, expect)


class PerScreen(Harness):
    """Wave 2: an image per output (--screen NAME IMAGE, replayed from
    last-screens) and a fit per output (wallpaper.screens.<NAME>)."""

    def setUp(self):
        super().setUp()
        # Portrait 2:3 image: top third red, middle green, bottom third blue.
        self.tall = self.home / "tall.png"
        subprocess.run(["magick", "-size", "200x300", "xc:#00ff00",
                        "-fill", "#ff0000", "-draw", "rectangle 0,0 199,99",
                        "-fill", "#0000ff", "-draw", "rectangle 0,200 199,299", str(self.tall)], check=True)
        self.cache = self.home / ".cache" / "wallpaper"

    def test_screen_gets_its_own_image_and_others_the_main_one(self):
        sent = self.run_script(args=[str(self.img), "--screen", "DP-3", str(self.tall)])
        self.assertEqual(sent, {"eDP-1": str(self.img), "DP-3": str(self.tall)})
        self.assertEqual((self.cache / "last-screens").read_text(), f"DP-3\t{self.tall}\n")
        self.assertEqual((self.cache / "last-wallpaper").read_text().strip(), str(self.img))

    def test_restore_and_logo_toggle_replay_the_screen_images(self):
        self.run_script(args=[str(self.img), "--screen", "DP-3", str(self.tall)])
        for argv in (["--restore"], ["--toggle-logo"]):
            with self.subTest(argv=argv):
                self.log.unlink()
                sent = self.run_script(args=argv)
                self.assertEqual(sent, {"eDP-1": str(self.img), "DP-3": str(self.tall)})

    def test_plain_set_clears_the_screen_images(self):
        self.run_script(args=[str(self.img), "--screen", "DP-3", str(self.tall)])
        self.log.unlink()
        sent = self.run_script()
        self.assertEqual(sent, {"eDP-1": str(self.img), "DP-3": str(self.img)})
        self.assertFalse((self.cache / "last-screens").exists())

    def test_missing_screen_image_falls_back_to_the_main_one(self):
        # Applied, then exit 3 so the shell does not retry the same plan forever.
        sent = self.run_script(args=[str(self.img), "--screen", "DP-3", str(self.home / "gone.png"),
                                     "--screen", "eDP-1", str(self.tall)], rc=3)
        self.assertEqual(sent["DP-3"], str(self.img))
        self.assertEqual(sent["eDP-1"], str(self.tall))

    def test_bad_output_names_fail(self):
        for name in ["", "a b", "x]", "@", "*"]:
            r = subprocess.run(["bash", str(SCRIPT), str(self.img), "--screen", name, str(self.tall)],
                               env=self.env(), capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 2, name)

    def test_bad_arguments_fail(self):
        r = subprocess.run(["bash", str(SCRIPT), str(self.img), "--screen", "DP-3"], env=self.env(),
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 2)

    def test_fit_per_screen_overrides_the_all_screens_fit(self):
        cfg = {"wallpaper": {"fit": "blur", "screens": {"DP-3": {"fit": "fill", "anchor": "right"}}}}
        sent = self.run_script(cfg)
        self.assertEqual(self.pixel(sent["DP-3"], 45, 80), "0000FF", "DP-3: its own fill + right")
        # A screen without its own fit keeps the all-screens one: eDP-1 shows a
        # tall image (rotated relative to it) with blur.
        self.log.unlink()
        sent = self.run_script(cfg, args=[str(self.img), "--screen", "eDP-1", str(self.tall)])
        self.assertIn("-plain-blur-centre-160x100.png", sent["eDP-1"])

    def test_missing_screen_fields_inherit(self):
        cfg = {"wallpaper": {"fit": "fill", "anchor": "left", "screens": {"DP-3": {"fit": "fill"}}}}
        sent = self.run_script(cfg)
        self.assertEqual(self.pixel(sent["DP-3"], 45, 80), "FF0000", "anchor inherited: left")

    def test_env_config_replaces_the_file(self):
        cfg = {"wallpaper": {"fit": "fill", "anchor": "left"}}
        env_cfg = json.dumps({"fit": "fill", "screens": {"DP-3": {"anchor": "right"}}})
        sent = self.run_script(cfg, WALLPAPER_CONFIG=env_cfg)
        self.assertEqual(self.pixel(sent["DP-3"], 45, 80), "0000FF")

    @unittest.skipUnless(shutil.which("rsvg-convert"), "rsvg-convert not installed")
    def test_only_the_main_image_writes_the_colour_cache(self):
        self.cache.mkdir(parents=True)
        (self.cache / "logo-active").write_text("arch")
        sent = self.run_script(args=[str(self.img), "--screen", "DP-3", str(self.tall)])
        self.assertTrue(sent["DP-3"].endswith("-arch-fill-centre-90x160.png"), sent)
        self.assertEqual((self.cache / "last-color-for").read_text().strip(), str(self.img))


if __name__ == "__main__":
    unittest.main()
