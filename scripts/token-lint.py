#!/usr/bin/env python3
"""token-lint.py — no raw typography outside the token file (item_110 wave 2).

Every font size, weight and letter-spacing in the shell's QML must come from
Commons/Appearance.qml (`Appearance.font.size*`, `weight*`, `tracking*`), so the
type scale, pack overrides and the Text size setting reach every label. Flags:
  - `pixelSize: <number>`
  - `Font.Normal|Medium|DemiBold|Bold|Light` in a weight binding
  - `letterSpacing: <number>`
Computed sizes (e.g. derived from a cell size) are allowed. Exits 1 on any hit.
Hex colours outside Commons are item_110 wave 4.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOWED = {pathlib.Path("Commons/Appearance.qml")}
# A numeric literal anywhere in the binding (plain value, ternary branch, or
# arithmetic like `size + 2`), except the `* 0.4`-style factor of a size computed
# from geometry, which is allowed when no bare literal size appears.
_NUM = r"(?<![\w.])\d+(\.\d+)?(?![\w.])"
RULES = [
    ("raw font size", re.compile(r"pixelSize:(?![^;}]*\*)[^;}]*" + _NUM)),
    ("raw font weight", re.compile(r"\bweight\b.*\bFont\.(Thin|ExtraLight|Light|Normal|Medium|DemiBold|Bold|ExtraBold|Black)\b")),
    ("raw letter spacing", re.compile(r"letterSpacing:[^;}]*" + _NUM)),
]
# modules/ holds the plugin examples: they run against the plugin API and keep
# literal fallbacks for hosts without Appearance (docs/WIDGET_API.md).
SKIP_DIRS = {"tests", "modules"}


def main():
    hits = 0
    for p in sorted(ROOT.rglob("*.qml")):
        rel = p.relative_to(ROOT)
        if rel in ALLOWED or rel.parts[0] in SKIP_DIRS:
            continue
        for n, line in enumerate(p.read_text().splitlines(), 1):
            code = line.split("//", 1)[0]
            for name, rx in RULES:
                if rx.search(code):
                    print(f"{rel}:{n}: {name}: {line.strip()[:100]}")
                    hits += 1
    print(f"token-lint: {hits} raw typography value(s) outside {', '.join(map(str, ALLOWED))}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
