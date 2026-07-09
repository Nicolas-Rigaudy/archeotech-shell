#!/usr/bin/env python3
# theme-switch.py — Archeotech system-wide theme switcher.
#
# Reads ~/.config/archeotech/themes/<variant>/theme.json, then applies that
# palette across every targeted app via a declarative per-target table.
#
# Patterns lifted from Caelestia (atomic temp+rename writes, fcntl lock,
# template registry) and DMS (refresh-by-signal instead of restart).
#
# Usage: theme-switch.py <variant> [accent]
#   accent (optional) = a palette color name (e.g. "blue") that overrides the
#   variant's built-in accent across QML/mango/rofi/GTK/VSCode/Obsidian. Only
#   accent-capable families (those shipping per-accent GTK packages, i.e.
#   Catppuccin) honor it; others ignore the arg.

from __future__ import annotations

import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable, Dict, List

HOME = Path.home()
ARCHEOTECH_DIR = HOME / ".config" / "archeotech"
THEMES_DIR = ARCHEOTECH_DIR / "themes"
ACTIVE_THEME_FILE = ARCHEOTECH_DIR / "theme.json"
LOCK_FILE = ARCHEOTECH_DIR / "theme.lock"

REPO_DIR = Path(__file__).resolve().parent.parent
TEMPLATES_DIR = Path(__file__).resolve().parent / "themes" / "templates"


# ── Helpers ──────────────────────────────────────────────────────────────────

def atomic_write(path: Path, content: str) -> None:
    """Temp file + rename — readers never see a torn file.
    If `path` is itself a symlink (e.g. stow-managed `~/.config/starship.toml`),
    write through to the link target so the symlink is preserved."""
    target = path.resolve() if path.is_symlink() else path
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=target.name + ".", dir=target.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp, target)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def render(template_name: str, vars: Dict[str, str]) -> str:
    """`{{key}}` substitution. Unknown keys raise KeyError so misnamed
    template tokens fail loudly instead of silently leaving `{{foo}}` in
    the output."""
    text = (TEMPLATES_DIR / template_name).read_text()
    def sub(m: re.Match) -> str:
        key = m.group(1).strip()
        if key not in vars:
            raise KeyError(f"template {template_name}: unknown var '{key}'")
        return vars[key]
    return re.sub(r"\{\{\s*([\w.-]+)\s*\}\}", sub, text)


def run(cmd: List[str], **kwargs: Any) -> subprocess.CompletedProcess:
    """Subprocess wrapper — never raises (callers may inspect returncode)."""
    return subprocess.run(cmd, check=False, capture_output=True, text=True, **kwargs)


def info(msg: str) -> None: print(f"\x1b[1;35m·\x1b[0m {msg}")
def warn(msg: str) -> None: print(f"\x1b[1;33m!\x1b[0m {msg}", file=sys.stderr)
def fail(msg: str) -> None:
    print(f"\x1b[1;31m✗\x1b[0m {msg}", file=sys.stderr)
    sys.exit(1)


# ── Per-target appliers ──────────────────────────────────────────────────────
# Each applier takes the parsed theme dict and a `vars` map (flat color
# names). Failures inside an applier should be logged via warn() but never
# raise — one broken target should not break the rest of the switch.


def apply_quickshell(theme: dict, vars: Dict[str, str]) -> None:
    """Write theme.json to where Quickshell's ThemeLoader watches.
    FileView watchChanges fires, but we also call `qs ipc call theme reload`
    since watchChanges alone is unreliable across atomic renames."""
    atomic_write(ACTIVE_THEME_FILE, json.dumps(theme, indent=2) + "\n")
    run(["qs", "ipc", "call", "theme", "reload"])


def apply_kitty(theme: dict, vars: Dict[str, str]) -> None:
    # kitty colors ship co-located with the theme package (themes/<v>/kitty.conf),
    # so a theme is self-contained and the applier skips gracefully if kitty
    # isn't installed on this machine.
    src = Path(theme["_dir"]) / "kitty.conf"
    dst = HOME / ".config" / "kitty" / "current-theme.conf"
    if not src.exists():
        warn(f"kitty theme file missing: {src}")
        return
    # Background opacity is theme-aware: dark themes keep the glass look, but
    # light themes must be (near-)opaque — at the dark transparency the
    # wallpaper shows through and dark-on-light text is unreadable. kitty.conf
    # no longer hardcodes opacity; it lives here, after the include.
    opacity = "0.9" if theme.get("mode") == "light" else "0.6"
    content = (src.read_text()
               + f"\n# Theme-aware opacity (theme-switch.py): {theme.get('mode','dark')}\n"
               + f"background_opacity {opacity}\n")
    atomic_write(dst, content)
    run(["pkill", "-USR1", "-x", "kitty"])


def apply_mango(theme: dict, vars: Dict[str, str]) -> None:
    """Patch mango/config.conf lines for shadow/border/focus/urgent colors,
    then trigger live reload via mmsg."""
    path = HOME / ".config" / "mango" / "config.conf"
    if not path.exists():
        warn(f"mango config missing: {path}")
        return
    m = theme.get("mango", {})
    text = path.read_text()
    for key, val in (
        ("shadowscolor", m.get("shadowscolor")),
        ("shadows_size", str(m.get("shadows_size", ""))),
        ("bordercolor",  m.get("bordercolor")),
        ("focuscolor",   m.get("focuscolor")),
        ("urgentcolor",  m.get("urgentcolor")),
    ):
        if val:
            text = re.sub(rf"^{key}=.*$", f"{key}={val}", text, flags=re.M)
    atomic_write(path, text)
    run(["mmsg", "-s", "-d", "reload_config"])


def apply_rofi(theme: dict, vars: Dict[str, str]) -> None:
    """Generate ~/.config/rofi/colors.rasi from the rofi-colors template.
    theme.rasi @imports colors.rasi — rofi reads on next launch."""
    out = HOME / ".config" / "rofi" / "colors.rasi"
    atomic_write(out, render("rofi-colors.rasi.tmpl", vars))


def apply_starship(theme: dict, vars: Dict[str, str]) -> None:
    """Overwrite ~/.config/starship.toml with the rendered theme.
    Starship watches its config file — live shells re-read on next prompt."""
    out = HOME / ".config" / "starship.toml"
    atomic_write(out, render("starship.toml.tmpl", vars))


def apply_swaylock(theme: dict, vars: Dict[str, str]) -> None:
    """Render swaylock/config from the template. swaylock colors are hex
    WITHOUT the leading '#', so feed render() a stripped-hex var map. No reload
    needed — swaylock re-reads its config on the next lock."""
    sl_vars = {k: v.lstrip("#") for k, v in theme.get("colors", {}).items()}
    out = HOME / ".config" / "swaylock" / "config"
    atomic_write(out, render("swaylock.config.tmpl", sl_vars))


def apply_hyprlock(theme: dict, vars: Dict[str, str]) -> None:
    """Render hypr/hyprlock.conf from the template. hyprlock colors are hex
    WITHOUT the leading '#' (wrapped in rgb()/rgba() in the template), so feed
    render() a stripped-hex var map — same shape as apply_swaylock. No reload
    needed; hyprlock re-reads its config on the next lock."""
    hl_vars = {k: v.lstrip("#") for k, v in theme.get("colors", {}).items()}
    out = HOME / ".config" / "hypr" / "hyprlock.conf"
    atomic_write(out, render("hyprlock.conf.tmpl", hl_vars))


def apply_fish(theme: dict, vars: Dict[str, str]) -> None:
    """Render fish's color vars from the palette, overwriting the frozen theme
    file fish wrote on its 4.3 migration (which was hardcoded to one flavor and
    never tracked theme switches — e.g. light-on-light text on Latte). fish
    accepts '#'-prefixed hex, so the standard var map is fine. Takes effect in
    new shells; the current one needs `exec fish`."""
    out = HOME / ".config" / "fish" / "conf.d" / "fish_frozen_theme.fish"
    atomic_write(out, render("fish-theme.fish.tmpl", vars))


def apply_gtk(theme: dict, vars: Dict[str, str]) -> None:
    """Update gtk-3.0/4.0 settings.ini AND gsettings (gtk-3 ini is for apps
    that read it directly; gsettings drives GNOME/Adwaita apps live)."""
    gtk = theme.get("gtk", {})
    if not gtk:
        return
    for ver in ("3.0", "4.0"):
        ini = HOME / ".config" / f"gtk-{ver}" / "settings.ini"
        if not ini.exists():
            continue
        text = ini.read_text()
        for key, val in (
            ("gtk-theme-name",         gtk.get("theme")),
            ("gtk-icon-theme-name",    gtk.get("icon")),
            ("gtk-cursor-theme-name",  gtk.get("cursor")),
        ):
            if val:
                text = re.sub(rf"^{key}=.*$", f"{key}={val}", text, flags=re.M)
        atomic_write(ini, text)
    # gsettings — fires the actual GTK reload signal across running apps.
    iface = "org.gnome.desktop.interface"
    for prop, val in (
        ("gtk-theme",     gtk.get("theme")),
        ("icon-theme",    gtk.get("icon")),
        ("cursor-theme",  gtk.get("cursor")),
    ):
        if val:
            run(["gsettings", "set", iface, prop, val])


def apply_vscode(theme: dict, vars: Dict[str, str]) -> None:
    """Patch workbench.colorTheme via jq. VSCode hot-reloads on save."""
    vs = theme.get("vscode")
    if not vs:
        return
    path = HOME / ".config" / "Code" / "User" / "settings.json"
    if not path.exists():
        return
    if shutil.which("jq") is None:
        warn("jq not installed — skipping VSCode")
        return
    expr = f'.["workbench.colorTheme"] = "{vs["theme"]}"'
    if "icon" in vs:
        expr += f' | .["workbench.iconTheme"] = "{vs["icon"]}"'
    # Catppuccin VSCode extension exposes its own accent setting; the accent
    # picker sets it here (names match the palette). Harmless if the active
    # theme isn't Catppuccin — the setting is just ignored.
    if "accent" in vs:
        expr += f' | .["catppuccin.accentColor"] = "{vs["accent"]}"'

    # Regenerate workbench.colorCustomizations from the active palette so the
    # editor/sidebar/etc. backgrounds TRACK the theme. Without this a stale
    # hardcoded block (the old Macchiato pins) freezes every theme's background
    # while only the syntax/text colors change. Drive every key off the palette
    # so it stays exactly shell-matched across all families + light/dark.
    c = theme.get("colors", {})
    cc = {
        "editor.background":               c.get("base"),
        "editorGroupHeader.tabsBackground": c.get("crust"),
        "tab.activeBackground":            c.get("base"),
        "tab.inactiveBackground":          c.get("mantle"),
        "sideBar.background":              c.get("mantle"),
        "activityBar.background":          c.get("crust"),
        "panel.background":                c.get("mantle"),
        "statusBar.background":            c.get("crust"),
        "titleBar.activeBackground":       c.get("crust"),
        "terminal.background":             c.get("base"),
    }
    cc = {k: v for k, v in cc.items() if v}  # drop any missing palette keys
    r = run(["jq", "--argjson", "cc", json.dumps(cc),
             expr + ' | .["workbench.colorCustomizations"] = $cc', str(path)])
    if r.returncode != 0:
        warn(f"jq failed on {path}: {r.stderr.strip()}")
        return
    atomic_write(path, r.stdout)


def apply_obsidian(theme: dict, vars: Dict[str, str]) -> None:
    """Patch every vault's .obsidian/appearance.json: community CSS theme, the
    light/dark base mode (so Catppuccin-style themes flip to their light palette
    on Latte), and the accent color. Obsidian reloads when the file's mtime
    changes.

    Per-vault lock: a vault with a `.obsidian/.archeotech-theme-lock` marker
    keeps its own community theme + accent; only the light/dark base still
    flips with the active palette's mode."""
    ob = theme.get("obsidian")
    if not ob:
        return
    if shutil.which("jq") is None:
        warn("jq not installed — skipping Obsidian")
        return
    css   = ob.get("css_theme", "")
    # "moonstone" = light base, "obsidian" = dark base.
    mode  = "moonstone" if theme.get("mode") == "light" else "obsidian"
    # Default accent = the family's primary accent until the accent picker lands.
    accent = ob.get("accent") or vars.get("mauve", "")
    # Use Obsidian's own vault registry — covers vaults anywhere, not just the
    # one-level-deep guesses the old globs caught.
    candidates: List[Path] = []
    registry = HOME / ".config" / "obsidian" / "obsidian.json"
    if registry.exists():
        try:
            data = json.loads(registry.read_text())
            for v in data.get("vaults", {}).values():
                ap = Path(v["path"]) / ".obsidian" / "appearance.json"
                if "path" in v and ap.exists():
                    candidates.append(ap)
        except Exception as e:
            warn(f"could not read Obsidian vault registry: {e}")
    if not candidates:  # fallback to the old heuristic
        candidates = list((HOME / "Documents").glob("*/.obsidian/appearance.json"))
        candidates += list((HOME / "Notes").glob("*/.obsidian/appearance.json"))
    for path in candidates:
        # Per-vault theme lock: drop a `.archeotech-theme-lock` file next to
        # appearance.json (in the vault's .obsidian/) to keep that vault's
        # community CSS theme + accent — only the light/dark base still flips.
        if (path.parent / ".archeotech-theme-lock").exists():
            expr = f'.theme = "{mode}"'
        else:
            expr = f'.cssTheme = "{css}" | .theme = "{mode}" | .accentColor = "{accent}"'
        r = run(["jq", expr, str(path)])
        if r.returncode != 0:
            warn(f"jq failed on {path}: {r.stderr.strip()}")
            continue
        atomic_write(path, r.stdout)


def apply_zen(theme: dict, vars: Dict[str, str]) -> None:
    """Theme Zen browser chrome from the palette and drive its translucent
    background. Writes chrome/archeotech-colors.css into every profile that
    already uses userChrome.css, and @imports it once. Transparency relies on
    the profile's `zen.widget.linux.transparency` pref + the compositor blur;
    takes effect on the next Zen restart."""
    zen_root = HOME / ".zen"
    if not zen_root.is_dir():
        return
    css = render("zen-colors.css.tmpl", vars)
    for chrome in zen_root.glob("*/chrome"):
        uc = chrome / "userChrome.css"
        if not uc.exists():
            continue  # only profiles that already opted into userChrome
        atomic_write(chrome / "archeotech-colors.css", css)
        head = uc.read_text()
        if "archeotech-colors.css" not in head:
            atomic_write(uc, '@import "archeotech-colors.css";\n' + head)


# ── Registry ─────────────────────────────────────────────────────────────────

Applier = Callable[[dict, Dict[str, str]], None]

REGISTRY: List[tuple[str, Applier]] = [
    ("quickshell", apply_quickshell),
    ("kitty",      apply_kitty),
    ("mango",      apply_mango),
    ("rofi",       apply_rofi),
    ("starship",   apply_starship),
    ("swaylock",   apply_swaylock),
    ("hyprlock",   apply_hyprlock),
    ("fish",       apply_fish),
    ("gtk",        apply_gtk),
    ("vscode",     apply_vscode),
    ("obsidian",   apply_obsidian),
    ("zen",        apply_zen),
]


# ── Accent override ────────────────────────────────────────────────────────

def apply_accent(theme: dict, vars: Dict[str, str], accent: str) -> None:
    """Mutate `theme` and `vars` in place so the chosen accent color drives the
    accent-bearing fields across every target. Called before the registry runs,
    so the appliers just consume the already-overridden values.

    Only meaningful for Catppuccin (the family with per-accent GTK packages +
    14 named palette accents). For other families the accent name won't be in
    the palette and we bail. The QML side reads `theme.accent` (a color name);
    everything else gets the resolved hex."""
    colors = theme.get("colors", {})
    if accent not in colors:
        warn(f"accent '{accent}' not in palette — ignoring")
        return
    hexv = colors[accent]                       # e.g. "#8aadf4"
    bare = hexv.lstrip("#")

    # QML: Appearance reads the top-level `accent` color NAME.
    theme["accent"] = accent

    # mango focus/border glow = the accent (0xRRGGBBff).
    theme.setdefault("mango", {})
    theme["mango"]["focuscolor"] = f"0x{bare}ff"
    theme["mango"]["bordercolor"] = f"0x{bare}ff"

    # rofi selection border = the accent (template reads rofi_border).
    theme.setdefault("rofi", {})["border"] = hexv
    vars["rofi_border"] = hexv

    # GTK: catppuccin ships catppuccin-<flavor>-<accent>-standard+default.
    # Only swap if that theme is actually installed, else keep the variant's
    # default so we never point GTK at a missing theme.
    if theme.get("family") == "catppuccin" and theme.get("flavor"):
        name = f"catppuccin-{theme['flavor']}-{accent}-standard+default"
        if _gtk_theme_installed(name):
            theme.setdefault("gtk", {})["theme"] = name
            theme["gtk"]["cursor"] = f"catppuccin-{theme['flavor']}-{accent}-cursors"
        else:
            warn(f"GTK theme '{name}' not installed — keeping default accent for GTK")

    # VSCode Catppuccin extension: drive its own accent setting (accent names
    # match the palette). apply_vscode reads theme['vscode']['accent'].
    if theme.get("family") == "catppuccin":
        theme.setdefault("vscode", {})["accent"] = accent

    # Obsidian accent = the resolved hex.
    if "obsidian" in theme:
        theme["obsidian"]["accent"] = hexv


def _gtk_theme_installed(name: str) -> bool:
    for base in (HOME / ".themes", Path("/usr/share/themes")):
        if (base / name).is_dir():
            return True
    return False


# ── Driver ───────────────────────────────────────────────────────────────────

def build_vars(theme: dict) -> Dict[str, str]:
    """Flatten the theme into a single name→hex map for template rendering.
    Includes the rofi sub-block so rofi-colors.rasi can reference rofi_bg etc."""
    vars: Dict[str, str] = {"name": theme.get("name", "")}
    for k, v in theme.get("colors", {}).items():
        vars[k] = v
    for k, v in theme.get("rofi", {}).items():
        vars[f"rofi_{k}"] = v
    return vars


def main() -> None:
    if len(sys.argv) < 2:
        fail("usage: theme-switch.py <variant>")
    variant = sys.argv[1]

    src = THEMES_DIR / variant / "theme.json"
    if not src.exists():
        fail(f"unknown theme '{variant}' (no file at {src})")

    # fcntl non-blocking lock prevents stampedes when the user holds a
    # keybind or two pickers race. If we can't get it, exit silently —
    # another switch is already running.
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    lock_fd = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        info("another theme-switch is in progress — skipping")
        return

    with src.open() as f:
        theme = json.load(f)
    # Expose the variant's own dir so appliers can read co-located assets
    # (e.g. kitty.conf) — keeps each theme package self-contained.
    theme["_dir"] = str(src.parent)
    vars = build_vars(theme)

    accent = sys.argv[2] if len(sys.argv) > 2 else ""
    if accent:
        apply_accent(theme, vars, accent)

    info(f"switching to {variant}" + (f" (accent: {accent})" if accent else ""))
    for name, applier in REGISTRY:
        try:
            applier(theme, vars)
        except Exception as e:
            warn(f"{name}: {e}")
        else:
            info(f"  ✓ {name}")

    info(f"done: {variant}")


if __name__ == "__main__":
    main()
