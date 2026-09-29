#!/usr/bin/env python3
"""contrast-check.py — WCAG contrast of each theme's semantic text roles.

Token-level, not pixel-level: for every themes/*/theme.json it resolves the text
roles the shell draws (theme.json `roles`, falling back to the Catppuccin map)
to their palette slots and checks them against the surfaces text sits on
(base, mantle, surface0). Body roles (textPrimary, textSecondary) need 4.5:1
(AA); textMuted needs 3:1; focus (the accent) needs 3:1 on base. textDisabled
is exempt (WCAG 1.4.3). textOnAccent is reported but not gated yet. Packs that
own a palette (packs/*/tokens.json colors) are checked with their own roles,
once per faction register.

Owner rule (2026-09-29): official palettes only. A failing role is fixed by
mapping it to a stronger official slot in that theme's `roles`, never by mixing
a colour. --strict exits 1 on any failure (CI).
"""
import argparse
import json
import pathlib
import sys

ROLES = {"textPrimary": ("body", "text"), "textSecondary": ("body", "subtext0"),
         "textMuted": ("muted", "overlay1")}
SURFACES = ["base", "mantle", "surface0"]
FLOOR = {"body": 4.5, "muted": 3.0, "focus": 3.0}


def luminance(hex_color):
    h = hex_color.lstrip("#")[:6]
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def ratio(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def check(name, colors, roles, accent_name):
    """One row: the three text roles (gated), focus on base (gated 3:1) and
    text-on-accent (reported, not gated yet). Returns the number of failures."""
    failures, cells = 0, []
    for role, (kind, default) in ROLES.items():
        slot = roles.get(role, default)
        if slot not in colors:
            cells.append(f"{slot}: missing FAIL"); failures += 1; continue
        worst, surf = min((ratio(colors[slot], colors[s]), s) for s in SURFACES if s in colors)
        ok = worst >= FLOOR[kind]
        failures += not ok
        cells.append(f"{worst:5.2f} {slot}/{surf}{'' if ok else ' FAIL'}")
    accent = colors.get(roles.get("focus", accent_name) if roles.get("focus", "accent") != "accent" else accent_name)
    if accent and "base" in colors:
        f = ratio(accent, colors["base"])
        failures += f < FLOOR["focus"]
        cells.append(f"{f:5.2f}{'' if f >= FLOOR['focus'] else ' FAIL'}")
        on = colors.get(roles.get("textOnAccent", "base"))
        cells.append(f"{ratio(on, accent):5.2f}{'' if ratio(on, accent) >= 4.5 else ' (below 4.5)'}" if on else "n/a")
    print(f"{name:<22} " + " ".join(f"{c:<24}" for c in cells))
    return failures


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    root = pathlib.Path(__file__).resolve().parent.parent
    ap.add_argument("--themes", default=str(root / "themes"))
    ap.add_argument("--packs", default=str(root / "packs"))
    ap.add_argument("--strict", action="store_true", help="exit 1 when any gated role is below its floor")
    args = ap.parse_args()

    failures = 0
    print(f"{'theme / pack':<22} " + " ".join(f"{r:<24}" for r in list(ROLES) + ["focus/base", "textOnAccent (info)"]))
    for tj in sorted(pathlib.Path(args.themes).glob("*/theme.json")):
        d = json.loads(tj.read_text())
        failures += check(tj.parent.name, d.get("colors", {}), d.get("roles", {}), d.get("accent", "mauve"))
    # Packs that own a palette, checked with their own roles; each register
    # overlays its colours on the pack's.
    for tk in sorted(pathlib.Path(args.packs).glob("*/tokens.json")):
        d = json.loads(tk.read_text())
        if not d.get("colors"):
            continue
        variants = {tk.parent.name: d["colors"]}
        for reg, spec in (d.get("registers") or {}).items():
            if isinstance(spec, dict) and spec.get("colors"):
                variants[f"{tk.parent.name}:{reg}"] = {**d["colors"], **spec["colors"]}
        for name, colors in variants.items():
            failures += check(name, colors, d.get("roles", {}), d.get("accent", "mauve"))
    print(f"\ncontrast: {failures} gated role(s) below floor (body {FLOOR['body']}, muted {FLOOR['muted']}, focus {FLOOR['focus']})"
          + ("" if args.strict else " — informational"))
    return 1 if (args.strict and failures) else 0


if __name__ == "__main__":
    sys.exit(main())
