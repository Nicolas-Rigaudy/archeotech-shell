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


def walk(node, path=""):
    """(dotted path, string) for every string leaf."""
    if isinstance(node, dict):
        for k, v in node.items():
            if not k.startswith("_"):
                yield from walk(v, f"{path}.{k}" if path else k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}[{i}]")
    elif isinstance(node, str):
        yield path, node


def to_hex(value):
    v = value.strip().lower()
    if len(v) in (7, 9) and v.startswith("#") and all(c in "0123456789abcdef" for c in v[1:]):
        return v[:7]
    if len(v) == 10 and v.startswith("0x") and all(c in "0123456789abcdef" for c in v[2:]):
        return "#" + v[2:8]
    return None


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
        # Every colour anywhere in theme.json (colors, rofi, mango, card swatches),
        # as #rrggbb or mango's 0xRRGGBBAA. Shadow colours are neutral by design.
        for where, value in walk(json.loads(tj.read_text())):
            if where.endswith("shadowscolor"):
                continue
            hexv = to_hex(value)
            if hexv and hexv not in allowed:
                print(f"{name}: {where} = {value} is not in the official {fam}/{var} palette")
                bad += 1
    print(f"theme fidelity: {bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
