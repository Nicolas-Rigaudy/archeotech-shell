#!/usr/bin/env python3
"""contrast-check.py — WCAG contrast of each theme's text tokens on its surfaces.

Token-level, not pixel-level: for every themes/*/theme.json it checks the text
roles the shell draws (text, subtext1, subtext0 for body copy; overlay1,
overlay0 for muted labels) against the surfaces they sit on (base, mantle,
surface0). Body copy needs 4.5:1 (AA), muted labels 3:1.

Informational by default (exit 0). --strict exits 1 when any pair is below its
floor; the design-system contrast floor (0.40) turns that on in CI.
"""
import argparse
import json
import pathlib
import sys

BODY = ["text", "subtext1", "subtext0"]
MUTED = ["overlay1", "overlay0"]
SURFACES = ["base", "mantle", "surface0"]
FLOOR = {"body": 4.5, "muted": 3.0}


def luminance(hex_color):
    h = hex_color.lstrip("#")[:6]
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def ratio(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--themes", default=str(pathlib.Path(__file__).resolve().parent.parent / "themes"))
    ap.add_argument("--strict", action="store_true", help="exit 1 when any pair is below its floor")
    args = ap.parse_args()

    failures = 0
    print(f"{'theme':<22} {'worst body':<28} {'worst muted':<28}")
    for tj in sorted(pathlib.Path(args.themes).glob("*/theme.json")):
        colors = json.loads(tj.read_text()).get("colors", {})
        worst = {}
        for kind, roles in (("body", BODY), ("muted", MUTED)):
            pairs = [(ratio(colors[r], colors[s]), r, s)
                     for r in roles for s in SURFACES if r in colors and s in colors]
            if not pairs:
                worst[kind] = "n/a"
                continue
            r_, role, surf = min(pairs)
            bad = r_ < FLOOR[kind]
            failures += sum(1 for p in pairs if p[0] < FLOOR[kind])
            worst[kind] = f"{r_:4.2f} {role}/{surf}{' FAIL' if bad else ''}"
        print(f"{tj.parent.name:<22} {worst['body']:<28} {worst['muted']:<28}")
    print(f"\ncontrast: {failures} token pair(s) below floor (body {FLOOR['body']}, muted {FLOOR['muted']})"
          + ("" if args.strict else " — informational"))
    return 1 if (args.strict and failures) else 0


if __name__ == "__main__":
    sys.exit(main())
