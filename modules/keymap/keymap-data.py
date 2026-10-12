#!/usr/bin/env python3
"""keymap-data.py: data for the Keymap helper module (item_144). Prints JSON.

"How do I type X on this keyboard": for every layout in use it compiles the real
keymap (`xkbcli compile-keymap`), reads each key's four levels (base, Shift,
AltGr, AltGr+Shift) and the locale's Compose table for dead-key sequences, and
lists every character the layout can type beyond plain ASCII, with the exact
combos ("AltGr + E", "AltGr + ` then E").

Keyboards come from the shell's Settings → Input choices
(~/.config/archeotech/config.json, input.keyboardLayouts) plus the compositor's
global xkb layouts (mango `xkb_rules_layout`), so the module shows the layout
each keyboard really types.

Output: {"keyboards": [{id, name, map}], "default": <keyboard id>,
         "maps": {map_id: {label, rows: [[{code, levels}]], chars: [{ch, name, base, combos}]}}}
  levels  four entries (or null): {"ch": shown text, "dead": bool}
  combos  list of sequences; a sequence is a list of chords; a chord a list of keys
"""
import json
import os
import re
import subprocess
import sys
import unicodedata

HOME = os.path.expanduser("~")
LEVEL_MODS = [[], ["Shift"], ["AltGr"], ["AltGr", "Shift"]]

# Physical rows of the main block, by xkb key name. ISO boards (most non-US
# layouts) have an extra key left of Z (<LSGT>) and <BKSL> on the home row.
ROWS_ANSI = [["TLDE"] + ["AE%02d" % i for i in range(1, 13)],
             ["AD%02d" % i for i in range(1, 13)] + ["BKSL"],
             ["AC%02d" % i for i in range(1, 12)],
             ["AB%02d" % i for i in range(1, 11)]]
ROWS_ISO = [ROWS_ANSI[0],
            ["AD%02d" % i for i in range(1, 13)],
            ["AC%02d" % i for i in range(1, 12)] + ["BKSL"],
            ["LSGT"] + ["AB%02d" % i for i in range(1, 11)]]

# Settings → Input values (Services/Hardware/Input.qml `layouts`) → xkb.
INPUT_LAYOUTS = {"fr": ("fr", ""), "us": ("us", ""), "us-intl": ("us", "altgr-intl")}


# ── keysym names → characters ────────────────────────────────────────────────
def load_keysyms(path="/usr/include/X11/keysymdef.h"):
    """XK_<name> → character, from keysymdef.h's "U+XXXX" comments."""
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                m = re.match(r"#define XK_(\w+)\s+0x[0-9a-fA-F]+\s*/\*[ (]*U\+([0-9A-Fa-f]{4,6})", line)
                if m:
                    out[m.group(1)] = chr(int(m.group(2), 16))
    except OSError:
        pass
    return out


def keysym_char(name, table):
    """The character a keysym types, or None (function keys, modifiers)."""
    m = re.fullmatch(r"U([0-9A-Fa-f]{4,6})", name)
    if m:
        return chr(int(m.group(1), 16))
    if name in table:
        return table[name]
    if len(name) == 1 and name.isprintable():
        return name
    return None


# ── keymap ───────────────────────────────────────────────────────────────────
def parse_keymap(text):
    """{key name: [level syms]} from xkb_symbols (group 1), plus the layout's name."""
    sym = text[text.find("xkb_symbols"):]
    name = re.search(r'name\[(?:1|Group1)\]\s*=\s*"([^"]*)"', sym)
    keys = {}
    for m in re.finditer(r"key\s+<(\w+)>\s*\{(.*?)\};", sym, re.S):
        body = m.group(2)
        # `symbols[1]= [ … ]` (multi-line form, may follow `type[1]= …`), else a
        # body that is just `[ … ]`.
        lv = (re.search(r"symbols\[(?:1|Group1)\]\s*=\s*\[([^\]]*)\]", body)
              or re.match(r"\s*\[([^\]]*)\]", body))
        if lv:
            keys[m.group(1)] = [s.strip() for s in lv.group(1).split(",") if s.strip()]
    return keys, (name.group(1) if name else "")


def compile_keymap(layout, variant):
    cmd = ["xkbcli", "compile-keymap", "--layout", layout]
    if variant:
        cmd += ["--variant", variant]
    return subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=10).stdout


# ── Compose ──────────────────────────────────────────────────────────────────
def compose_path():
    """The system Compose table for the current locale (as libxkbcommon picks it).
    A personal ~/.XCompose is not read: sequences it adds or changes are not shown."""
    if os.environ.get("XCOMPOSEFILE") and os.path.isfile(os.environ["XCOMPOSEFILE"]):
        return os.environ["XCOMPOSEFILE"]
    loc = os.environ.get("LC_ALL") or os.environ.get("LC_CTYPE") or os.environ.get("LANG") or "en_US.UTF-8"
    base = "/usr/share/X11/locale"
    try:
        with open(base + "/compose.dir", encoding="utf-8") as f:
            for line in f:
                parts = line.split()
                if len(parts) == 2 and parts[1].rstrip(":") == loc:
                    return base + "/" + parts[0]
    except OSError:
        pass
    return base + "/en_US.UTF-8/Compose"


def parse_compose(text):
    """[(keysym sequence, result)] for sequences that start with a dead key."""
    out = []
    for line in text.splitlines():
        m = re.match(r'\s*((?:<\w+>\s*)+):\s*"((?:[^"\\]|\\.)*)"', line)
        if not m:
            continue
        seq = re.findall(r"<(\w+)>", m.group(1))
        if seq and seq[0].startswith("dead_"):
            out.append((seq, re.sub(r"\\(.)", r"\1", m.group(2))))
    return out


def compose_names(text):
    """keysym name → character from Compose results ('... : "é" eacute'): a fallback
    when keysymdef.h (xorgproto headers) is not installed."""
    out = {}
    for m in re.finditer(r':\s*"([^"\\])"\s+(\w+)', text):
        out.setdefault(m.group(2), m.group(1))
    return out


# ── the index ────────────────────────────────────────────────────────────────
def key_label(syms, table, dead_text):
    """What is printed on a key: its base character (ASCII letters upper-case, as
    on a keycap; é/è/ù stay lower-case, as on an AZERTY), a dead key's accent, or
    "Space"."""
    if not syms:
        return None
    if syms[0] == "space":
        return "Space"
    if syms[0].startswith("dead_"):
        return dead_text.get(syms[0], syms[0][5:])
    ch = keysym_char(syms[0], table)
    if not ch or not ch.strip():
        return None
    return ch.upper() if ch.isascii() and ch.isalpha() else ch


def base_letter(ch):
    """'é' → 'e' (the letter a search for "e" should find it under)."""
    d = unicodedata.normalize("NFD", ch)
    b = d[0].lower() if d and d[0].isascii() and d[0].isalpha() else ""
    return b if b != ch else ""


# US-style boards (no key left of Z). Every xkb keymap defines <LSGT> (pc105
# model), so the layout decides, not the keymap.
ANSI_LAYOUTS = {"us", "th", "kr", "il"}


def build_map(keys, label, compose, table, layout=""):
    iso = "LSGT" in keys and layout not in ANSI_LAYOUTS
    rows_codes = ROWS_ISO if iso else ROWS_ANSI
    dead_text = {seq[0]: res for seq, res in compose if len(seq) == 2 and seq[1] == "space"}

    # Only the main block (+ Space): media/extra keys are not on most boards.
    block = {c for r in rows_codes for c in r} | {"SPCE"}
    keys = {c: v for c, v in keys.items() if c in block}

    # Where each keysym lives: keysym → [chord], cheapest first.
    where = {}
    for code, syms in keys.items():
        lab = key_label(syms, table, dead_text)
        if not lab:
            continue
        for lvl, s in enumerate(syms[:4]):
            where.setdefault(s, []).append(LEVEL_MODS[lvl] + [lab])
    for s in where:
        where[s].sort(key=len)      # stable: equal lengths keep level order (Shift before AltGr)

    rows = []
    for codes in rows_codes:
        row = []
        for code in codes:
            if code not in keys:
                continue
            levels = []
            for s in (keys[code] + [None] * 4)[:4]:
                if s is None or s == "NoSymbol":
                    levels.append(None)
                elif s.startswith("dead_"):
                    levels.append({"ch": dead_text.get(s, s[5:]), "dead": True})
                else:
                    ch = keysym_char(s, table)
                    levels.append({"ch": ch, "dead": False} if ch and ch.isprintable() else None)
            row.append({"code": code, "levels": levels})
        rows.append(row)

    chars = {}

    def add(ch, combo):
        if not ch or not ch.isprintable() or ch.isspace():
            return
        chars.setdefault(ch, [])
        if combo not in chars[ch]:
            chars[ch].append(combo)

    # Direct: a level-3/4 (AltGr) symbol, or any non-ASCII symbol on base/Shift.
    # An AltGr level that repeats what some key types without AltGr (us
    # altgr-intl's AltGr+Shift+F = F) is not a way worth listing.
    plain = {keysym_char(s, table) for syms in keys.values() for s in syms[:2]} - {None}
    for code, syms in keys.items():
        lab = key_label(syms, table, dead_text)
        if not lab:
            continue
        for lvl, s in enumerate(syms[:4]):
            if s.startswith("dead_"):
                continue
            ch = keysym_char(s, table)
            if ch and (lvl >= 2 or not ch.isascii()) and not (lvl >= 2 and ch in plain):
                add(ch, [LEVEL_MODS[lvl] + [lab]])
    # Dead key, then a key: the Compose sequences this layout can actually type.
    for seq, res in compose:
        if len(seq) != 2 or seq[0] not in where or seq[1] not in where:
            continue
        add(res, [where[seq[0]][0], where[seq[1]][0]])

    cost = lambda combo: (len(combo), sum(len(c) for c in combo))
    out = []
    for ch, combos in chars.items():
        combos.sort(key=cost)
        try:
            name = unicodedata.name(ch).title() if len(ch) == 1 else ""
        except ValueError:
            name = ""
        out.append({"ch": ch, "name": name, "base": base_letter(ch), "combos": combos[:2]})
    # Grouped by letter (symbols last), lower case first, the easiest to type first.
    out.sort(key=lambda c: (c["base"] or "~", c["ch"].lower() != c["ch"], cost(c["combos"][0]), c["ch"]))
    return {"label": label, "rows": rows, "chars": out}


# ── which keyboards ──────────────────────────────────────────────────────────
def global_layouts(mango_conf):
    lay = var = ""
    for line in mango_conf.splitlines():
        m = re.match(r"\s*xkb_rules_(layout|variant)\s*=\s*(.*?)\s*$", line)
        if m:
            if m.group(1) == "layout":
                lay = m.group(2)
            else:
                var = m.group(2)
    lays = [l.strip() for l in lay.split(",") if l.strip()] or ["us"]
    vars_ = [v.strip() for v in var.split(",")] + [""] * len(lays)
    return list(zip(lays, vars_[:len(lays)]))


def hyprland_layouts():
    """Hyprland's input:kb_layout / kb_variant (per-keyboard layouts are a mango
    feature of Settings → Input; on Hyprland every keyboard types these)."""
    def opt(name):
        try:
            r = subprocess.run(["hyprctl", "getoption", name, "-j"], capture_output=True, text=True, timeout=3)
            return json.loads(r.stdout).get("str", "")
        except (OSError, ValueError, subprocess.SubprocessError):
            return ""
    return "xkb_rules_layout=%s\nxkb_rules_variant=%s\n" % (opt("input:kb_layout"), opt("input:kb_variant"))


def keyboards(shell_conf, mango_conf):
    inp = (shell_conf or {}).get("input", {}) or {}
    chosen = inp.get("keyboardLayouts", {}) or {}
    nodes = inp.get("keyboardNodes", {}) or {}
    hidden = set(inp.get("hiddenKeyboards", []) or [])
    out = []
    for key, value in chosen.items():
        vp = ":".join(key.split(":")[:2])
        if vp in hidden or value in ("", "default") or any(k["id"] == vp for k in out):
            continue
        full = (nodes.get(vp) or [key])[0]
        name = full.split(":", 2)[2] if full.count(":") >= 2 else full
        if name.startswith("AT Translated Set"):        # the laptop's own keyboard (i8042)
            name = "Built-in keyboard"
        lay, var = INPUT_LAYOUTS.get(value, (value, ""))
        out.append({"id": vp, "name": name, "layout": lay, "variant": var})
    mapid = lambda lay, var: lay + ("(%s)" % var if var else "")
    for k in out:
        k["map"] = mapid(k["layout"], k["variant"])
    # The global layouts (keyboards left on Default type these), minus ones a
    # listed keyboard already shows.
    for i, (lay, var) in enumerate(global_layouts(mango_conf)):
        if not any(k["map"] == mapid(lay, var) for k in out):
            out.append({"id": "system:%d" % i, "name": "System layout (%s)" % mapid(lay, var),
                        "layout": lay, "variant": var, "map": mapid(lay, var)})
    return out


def read(path, default=""):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return default


def main():
    try:
        shell_conf = json.loads(read(HOME + "/.config/archeotech/config.json", "{}"))
    except ValueError:
        shell_conf = {}
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        kbs = keyboards({}, hyprland_layouts())
    else:
        kbs = keyboards(shell_conf, read(HOME + "/.config/mango/config.conf"))
    table = load_keysyms()
    compose_text = read(compose_path())
    compose = parse_compose(compose_text)
    for name, ch in compose_names(compose_text).items():   # names the header lacks
        table.setdefault(name, ch)
    maps, errors = {}, []
    for k in kbs:
        if k["map"] in maps:
            continue
        try:
            keys, label = parse_keymap(compile_keymap(k["layout"], k["variant"]))
            maps[k["map"]] = build_map(keys, label or k["map"], compose, table, k["layout"])
        except (OSError, subprocess.SubprocessError) as e:
            errors.append("%s: %s" % (k["map"], e))
    kbs = [k for k in kbs if k["map"] in maps]
    # Default: the keyboard with the most to look up (a variant), else the first.
    default = next((k["id"] for k in kbs if k["variant"]), kbs[0]["id"] if kbs else "")
    json.dump({"keyboards": kbs, "default": default, "maps": maps, "errors": errors},
              sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
