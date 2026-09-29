#!/usr/bin/env python3
"""theme-fidelity.py — every colour in a theme must come from its official palette.

Owner rule (2026-09-29): themes use their designers' official colours exactly.
Nothing is mixed, lightened or interpolated to fill a slot; when a palette has
fewer tones than the slot ladder, slots reuse an official colour. Official
palettes are snapshotted in themes/_official/<family>.json with their upstream
source and commit. Themes that are Archeotech's own design are listed in CUSTOM.
"""
import argparse, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# theme dir -> (official family file, variant)
OFFICIAL = {
    "archeotech-latte": ("catppuccin", "latte"),
    "archeotech-frappe": ("catppuccin", "frappe"),
    "archeotech-macchiato": ("catppuccin", "macchiato"),
    "archeotech-mocha": ("catppuccin", "mocha"),
    "tokyo-night": ("tokyo-night", "night"),
    "tokyo-night-day": ("tokyo-night", "day"),
    "gruvbox": ("gruvbox", "dark"),
    "gruvbox-light": ("gruvbox", "light"),
    "nord": ("nord", "dark"),
    "dracula": ("dracula", "dracula"),
    "dracula-alucard": ("dracula", "alucard"),
}
CUSTOM = {"monochrome", "monochrome-light"}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--themes", default=str(ROOT / "themes"))
    args = ap.parse_args()
    themes = pathlib.Path(args.themes)
    bad = 0
    for tj in sorted(themes.glob("*/theme.json")):
        name = tj.parent.name
        if name in CUSTOM:
            continue
        if name not in OFFICIAL:
            print(f"{name}: not mapped to an official palette (add it to OFFICIAL or CUSTOM)")
            bad += 1
            continue
        fam, var = OFFICIAL[name]
        official = json.loads((themes / "_official" / f"{fam}.json").read_text())["variants"][var]
        allowed = {v.lower() for v in official.values()}
        for slot, value in json.loads(tj.read_text()).get("colors", {}).items():
            if isinstance(value, str) and value.startswith("#") and value[:7].lower() not in allowed:
                print(f"{name}: {slot} = {value} is not in the official {fam}/{var} palette")
                bad += 1
    print(f"theme fidelity: {bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
