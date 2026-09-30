#!/usr/bin/env python3
"""contrast-check.py — WCAG contrast of each theme's semantic text roles.

Token-level, not pixel-level: for every themes/*/theme.json it resolves the text
roles the shell draws (theme.json `roles`, falling back to the Catppuccin map)
to their palette slots and checks them against the surfaces text sits on
(base, mantle, surface0). Body roles (textPrimary, textSecondary) need 4.5:1
(AA); textMuted needs 3:1; focus (the accent) needs 3:1 on base. textDisabled
is exempt (WCAG 1.4.3). textOnAccent is reported but not gated; the selected
state's text (item_142: tonal on light, base on the accent on dark) is gated at
4.5 on every theme (packs: reported via textOnAccent). Packs that
own a palette (packs/*/tokens.json colors) are checked with their own roles,
once per faction register.

Owner rule (2026-09-29): official palettes only. A failing role is fixed by
mapping it to a stronger official slot in that theme's `roles`, never by mixing
a colour. --strict exits 1 on any failure (CI).
"""
import argparse
import json
import pathlib
import re
import sys

ROLES = {"textPrimary": ("body", "text"), "textSecondary": ("body", "subtext0"),
         "textMuted": ("muted", "overlay1")}
SURFACES = ["base", "mantle", "surface0"]
FLOOR = {"body": 4.5, "muted": 3.0, "focus": 3.0}
# Appearance.colors.selectedTint, read from the QML so the two cannot drift.
_TINT = re.search(r"property real\s+selectedTint:\s*([0-9.]+)",
                  (pathlib.Path(__file__).resolve().parent.parent / "Commons" / "Appearance.qml").read_text())
SELECTED_TINT = float(_TINT.group(1)) if _TINT else 0.20


def luminance(hex_color):
    h = hex_color.lstrip("#")[:6]
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def ratio(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def surfaces_for(data):
    """Text-bearing surfaces. Dark: base, mantle, cards on surface0. Light
    (item_111): cards are base and panels mantle, so surface0 carries no text.
    A theme may exempt a surface where its designer places text below the floor
    (theme.json contrastExempt: {surface: reason}); it is reported, not gated."""
    surf = ["base", "mantle"] if data.get("mode") == "light" else list(SURFACES)
    exempt = data.get("contrastExempt", {})
    return [s for s in surf if s not in exempt], exempt


def check(name, colors, roles, accent_name, surfaces=None, exempt=None, selected=None):
    """One row: the three text roles (gated), focus on base (gated 3:1) and
    text-on-accent (reported, not gated yet). Returns the number of failures."""
    failures, cells = 0, []
    for role, (kind, default) in ROLES.items():
        slot = roles.get(role, default)
        if slot not in colors:
            cells.append(f"{slot}: missing FAIL"); failures += 1; continue
        worst, surf = min((ratio(colors[slot], colors[s]), s) for s in (surfaces or SURFACES) if s in colors)
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
        if selected is not None and "base" in colors:
            # Selected text (item_142), mirrors Appearance.selectedFill/onSelected:
            # light = textPrimary on base tinted SELECTED_TINT toward the accent,
            # dark = base on the accent. Gated at 4.5 unless the theme exempts it.
            if selected == "light":
                fill = _mix(accent, colors["base"], SELECTED_TINT)
                text = colors.get(roles.get("textPrimary", "text"))
            else:
                fill, text = accent, colors["base"]
            r = ratio(text, fill)
            if "selectedFill" in (exempt or {}):
                cells.append(f"{r:5.2f} exempt")
            else:
                failures += r < FLOOR["body"]
                cells.append(f"{r:5.2f}{'' if r >= FLOOR['body'] else ' FAIL'}")
    print(f"{name:<22} " + " ".join(f"{c:<24}" for c in cells))
    for surf, why in (exempt or {}).items():
        print(f"{'':<22} exempt: {surf} ({why})")
    return failures


def _mix(fg, bg, a):
    """fg composited over bg at alpha a (sRGB, like the renderer)."""
    f, b = fg.lstrip("#")[:6], bg.lstrip("#")[:6]
    return "#" + "".join(f"{round(int(f[i:i+2], 16) * a + int(b[i:i+2], 16) * (1 - a)):02x}" for i in (0, 2, 4))


def glass_surfaces(data, table, preset, wall):
    """Effective text surfaces at a glass preset (item_139) over wallpaper `wall`:
    the panel (mantle at panel alpha) and a card on that panel (dark: surface0,
    light: base, at card alpha). Mirrors Appearance.qml glassBg/surfaceCard."""
    c = data.get("colors", {})
    m = table["presets"][preset]["light" if data.get("mode") == "light" else "dark"]
    panel = _mix(c["mantle"], wall, m["panel"])
    card = _mix(c["base" if data.get("mode") == "light" else "surface0"], panel, m["card"])
    return {**c, "panel": panel, "panelAlt": _mix(c["mantle"], wall, m["panelAlt"]), "card": card}


def glass_gated(data):
    """Glass surfaces to gate. A theme that exempts mantle (its designer puts text
    on that side-pane colour below the floor) exempts the panel and the cards
    resting on it too; they are reported, not gated."""
    if "mantle" in data.get("contrastExempt", {}):
        return [], {"panel/panelAlt/card": "mantle exempt: " + data["contrastExempt"]["mantle"][:60]}
    return ["panel", "panelAlt", "card"], {}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    root = pathlib.Path(__file__).resolve().parent.parent
    ap.add_argument("--themes", default=str(root / "themes"))
    ap.add_argument("--packs", default=str(root / "packs"))
    ap.add_argument("--strict", action="store_true", help="exit 1 when any gated role is below its floor")
    ap.add_argument("--glass", metavar="PRESET", nargs="?", const="all",
                    help="check text over a mid-grey wallpaper through the glass preset(s) "
                         "in themes/glass-presets.json (item_139) instead of the opaque slots")
    ap.add_argument("--wallpaper", default="#808080", help="wallpaper colour for --glass")
    args = ap.parse_args()
    if args.glass:
        return glass_main(args)

    failures = 0
    print(f"{'theme / pack':<22} " + " ".join(f"{r:<24}" for r in list(ROLES) + ["focus/base", "textOnAccent (info)", "selected text"]))
    for tj in sorted(pathlib.Path(args.themes).glob("*/theme.json")):
        d = json.loads(tj.read_text())
        surf, exempt = surfaces_for(d)
        failures += check(tj.parent.name, d.get("colors", {}), d.get("roles", {}), d.get("accent", "mauve"), surf, exempt,
                          selected=d.get("mode", "dark"))
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


def glass_main(args):
    table = json.loads((pathlib.Path(args.themes) / "glass-presets.json").read_text())
    presets = table["order"] if args.glass == "all" else [args.glass]
    failures = 0
    print(f"{'theme @ preset':<22} " + " ".join(f"{r:<24}" for r in list(ROLES) + ["focus/base", "textOnAccent (info)"]))
    for preset in presets:
        for tj in sorted(pathlib.Path(args.themes).glob("*/theme.json")):
            d = json.loads(tj.read_text())
            colors = glass_surfaces(d, table, preset, args.wallpaper)
            gated, exempt = glass_gated(d)
            if not gated:
                print(f"{tj.parent.name + '@' + preset:<22} exempt: {list(exempt.values())[0]}")
                continue
            failures += check(f"{tj.parent.name}@{preset}", colors, d.get("roles", {}),
                              d.get("accent", "mauve"), gated)
    print(f"\ncontrast over {args.wallpaper} through glass: {failures} gated role(s) below floor"
          + ("" if args.strict else " — informational"))
    return 1 if (args.strict and failures) else 0


if __name__ == "__main__":
    sys.exit(main())
