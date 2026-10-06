#!/usr/bin/env python3
"""display-profile.py — saved display layouts that follow the monitors (item_135).

A profile is the full layout of one SET of monitors (mode, position, rotation,
scale, on/off per output), stored in ~/.config/archeotech/displays.json.
Monitors are recognised by identity (make + model + serial from the EDID; the
connector name stands in when a monitor reports no serial, e.g. a laptop
panel), not by connector, so a home screen on HDMI-A-1 is never mistaken for
the work one and two identical models are told apart by serial.

A profile matches when its monitor set equals the connected set. Saving a
profile for a set that already has one replaces it, so matching is never
ambiguous. Used by Settings → Display (save / apply / delete / auto toggle)
and by the hotplug daemon (`apply`), so it works with or without the shell.

  display-profile.py status [--json]   profiles, the one matching now, autoApply
  display-profile.py apply [NAME]      apply NAME, or the matching profile
  display-profile.py save NAME         save the current layout as NAME
  display-profile.py delete NAME
  display-profile.py set-auto on|off   apply automatically on dock/undock

`apply` without NAME exits 0 when it applied a profile (or it was already in
place), 3 when profiles exist but none matches these monitors, 4 when auto-apply
is off, 5 when there are no profiles at all, 6 when a profile matched but could
not be applied, and 2 on bad usage. Only 5 should make a caller fall back to its
own layout: every other outcome must leave the screens alone.
"""
import fcntl
import json
import os
import tempfile
import pathlib
import subprocess
import sys

CONFIG = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "archeotech"
STORE = CONFIG / "displays.json"
LOCK = CONFIG / "displays.lock"
# Placeholder serials some EDIDs report: treated as "no serial".
JUNK_SERIALS = {"", "0", "00000000", "unknown", "none", "0x00000000"}


# ── Pure logic (tested in tests/py/test_display_profile.py) ───────────────────

def identity(o):
    """Stable identity of a monitor: make|model|serial, or make|model|@connector."""
    make, model, serial = (o.get("make") or ""), (o.get("model") or ""), (o.get("serial") or "")
    if serial.strip().lower() in JUNK_SERIALS:
        serial = ""
    return f"{make}|{model}|{serial}" if serial else f"{make}|{model}|@{o.get('name', '')}"


def current_mode(o):
    modes = o.get("modes") or []
    cur = next((m for m in modes if m.get("current")), None)
    cur = cur or next((m for m in modes if m.get("preferred")), None) or (modes[0] if modes else None)
    return {"width": cur["width"], "height": cur["height"], "refresh": cur.get("refresh", 0)} if cur else None


def snapshot(outputs):
    """wlr-randr --json outputs → the profile's output entries."""
    entries = []
    for o in outputs:
        pos = o.get("position") or {}
        entries.append({
            "id": identity(o),
            "make": o.get("make") or "", "model": o.get("model") or "",
            "serial": o.get("serial") or "", "name": o.get("name"),
            "enabled": bool(o.get("enabled")),
            "mode": current_mode(o),
            "x": pos.get("x", 0), "y": pos.get("y", 0),
            "transform": o.get("transform") or "normal",
            "scale": o.get("scale") or 1,
        })
    return entries


def match(profiles, outputs):
    """The profile whose monitor set equals the connected set, or None."""
    now = {identity(o) for o in outputs}
    for p in profiles:
        if {e["id"] for e in p.get("outputs", [])} == now:
            return p
    return None


def _offers(modes, m):
    return any(x.get("width") == m["width"] and x.get("height") == m["height"]
               and abs((x.get("refresh") or 0) - (m.get("refresh") or 0)) < 0.5 for x in modes)


def argv(profile, outputs):
    """wlr-randr argv applying `profile` to the connected outputs (by identity →
    today's connector name). None if a profile monitor is not connected or the
    profile would turn every output off (see why_not)."""
    by_id = {identity(o): o["name"] for o in outputs}
    modes_of = {identity(o): o.get("modes") or [] for o in outputs}
    a = ["wlr-randr"]
    any_on = False
    for e in profile.get("outputs", []):
        name = by_id.get(e["id"])
        if name is None:
            return None
        a += ["--output", name]
        if not e.get("enabled"):
            a.append("--off")
            continue
        any_on = True
        a.append("--on")
        # Only request a mode the monitor offers right now; otherwise let the
        # compositor pick its native one (a disabled output may list no modes,
        # and wlr-randr rejects the WHOLE call on an unknown mode).
        m = e.get("mode")
        if m and m.get("width") and _offers(modes_of.get(e["id"], []), m):
            r = m.get("refresh") or 0
            a += ["--mode", f"{m['width']}x{m['height']}" + (f"@{r:.3f}Hz" if r > 0 else "")]
        a += ["--pos", f"{int(e.get('x', 0))},{int(e.get('y', 0))}",
              "--transform", e.get("transform", "normal"), "--scale", str(e.get("scale", 1))]
    return a if any_on else None


def why_not(profile, outputs):
    """Why argv() refused this profile, for the error message."""
    have = {identity(o) for o in outputs}
    if any(e["id"] not in have for e in profile.get("outputs", [])):
        return "needs monitors that are not connected"
    return "would turn every screen off"


def save(store, name, outputs):
    """Store the current layout as `name`; it replaces any profile with the same
    name OR the same monitor set (one profile per set keeps matching unambiguous)."""
    entries = snapshot(outputs)
    ids = {e["id"] for e in entries}
    kept = [p for p in store.get("profiles", [])
            if p.get("name") != name and {e["id"] for e in p.get("outputs", [])} != ids]
    store = dict(store)
    store["profiles"] = kept + [{"name": name, "outputs": entries}]
    return store


# ── IO ────────────────────────────────────────────────────────────────────────

def load():
    """The store; a corrupt file is kept aside as displays.json.bad (a later save
    must not silently wipe the profiles) and read as empty."""
    try:
        text = STORE.read_text()
    except OSError:
        return {}
    try:
        d = json.loads(text)
        if not isinstance(d, dict):
            raise ValueError("not an object")
    except ValueError:
        STORE.with_suffix(".json.bad").write_text(text)
        return {}
    d["profiles"] = [p for p in d.get("profiles", [])
                     if isinstance(p, dict) and p.get("name") and isinstance(p.get("outputs"), list)]
    return d


def write(store):
    """Atomic replace through a unique temp file (concurrent writers never share it)."""
    CONFIG.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="displays.", suffix=".tmp", dir=CONFIG)
    with os.fdopen(fd, "w") as f:
        f.write(json.dumps(store, indent=2) + "\n")
    os.replace(tmp, STORE)


def locked():
    """Exclusive lock around load-modify-write so a save never races a delete."""
    CONFIG.mkdir(parents=True, exist_ok=True)
    fh = open(LOCK, "w")
    fcntl.flock(fh, fcntl.LOCK_EX)
    return fh


def outputs_now():
    r = subprocess.run(["wlr-randr", "--json"], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"display-profile: wlr-randr failed: {r.stderr.strip()}")
    return json.loads(r.stdout)


def mismatches(profile, outputs):
    """Enabled profile outputs whose live position differs from the profile."""
    live = {identity(o): o for o in outputs}
    bad = []
    for e in profile.get("outputs", []):
        o = live.get(e["id"])
        if o is None or not e.get("enabled"):
            continue
        pos = o.get("position") or {}
        if (pos.get("x"), pos.get("y")) != (int(e.get("x", 0)), int(e.get("y", 0))):
            bad.append(o["name"])
    return bad


def in_place(profile, outputs):
    """True when the screens already show this profile (on/off, position,
    rotation, scale): applying would change nothing, so stay silent."""
    live = {identity(o): o for o in outputs}
    for e in profile.get("outputs", []):
        o = live.get(e["id"])
        if o is None or bool(o.get("enabled")) != bool(e.get("enabled")):
            return False
        if not e.get("enabled"):
            continue
        pos = o.get("position") or {}
        if ((pos.get("x"), pos.get("y")) != (int(e.get("x", 0)), int(e.get("y", 0)))
                or (o.get("transform") or "normal") != e.get("transform", "normal")
                or abs((o.get("scale") or 1) - (e.get("scale") or 1)) > 1e-3):
            return False
    return True


def run_layout(profile, outs):
    """Apply, then verify: mango places an output it has just RE-ENABLED to the
    right of the others and ignores the requested position, so when the
    read-back differs, apply once more (the output exists now, the position sticks)."""
    for attempt in range(2):
        live = outs if attempt == 0 else outputs_now()
        a = argv(profile, live)
        if a is None:
            raise ApplyError(f"{profile['name']!r} {why_not(profile, live)}")
        r = subprocess.run(a, capture_output=True, text=True)
        if r.returncode != 0:
            raise ApplyError(f"wlr-randr rejected {profile['name']!r}: {r.stderr.strip()}")
        if not mismatches(profile, outputs_now()):
            return
    raise ApplyError(f"{profile['name']!r} applied, but positions differ: "
                     f"{', '.join(mismatches(profile, outputs_now()))}")


class ApplyError(Exception):
    pass


def toast(summary, body=""):
    """Best effort: a missing notify-send, no bus or a hung daemon must never
    change the exit code or stall the hotplug daemon."""
    try:
        subprocess.run(["notify-send", "-a", "Displays", "-i", "video-display", summary, body],
                       capture_output=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        pass


def toast_once(key, summary, body=""):
    """Toast once per monitor set per session (not on every mango reload)."""
    stamp = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "display-profile.last-unknown"
    try:
        if stamp.read_text() == key:
            return
    except OSError:
        pass
    try:
        stamp.write_text(key)
    except OSError:
        pass
    toast(summary, body)


def main(args):
    store = load()
    profiles = store.get("profiles", [])
    cmd = args[0] if args else "status"

    if cmd == "status":
        outs = outputs_now()
        cur = match(profiles, outs)
        info = {"profiles": [{"name": p["name"],
                              "monitors": [e.get("name") for e in p.get("outputs", []) if e.get("enabled")]}
                             for p in profiles],
                "active": cur["name"] if cur else None,
                "autoApply": store.get("autoApply", True)}
        print(json.dumps(info) if "--json" in args else
              "\n".join([f"{'*' if p['name'] == info['active'] else ' '} {p['name']}: {', '.join(p['monitors'])}"
                         for p in info["profiles"]] + [f"auto-apply: {'on' if info['autoApply'] else 'off'}"]))
        return 0

    if cmd == "apply":
        outs = outputs_now()
        if len(args) > 1:
            p = next((p for p in profiles if p["name"] == args[1]), None)
            if p is None:
                print(f"display-profile: no profile named {args[1]!r}", file=sys.stderr)
                return 2
        else:
            if not profiles:
                return 5
            if not store.get("autoApply", True):
                return 4
            p = match(profiles, outs)
            if p is None:
                toast_once(",".join(sorted(identity(o) for o in outs)), "New display setup",
                           "Arrange it in Settings → Display and save it as a profile.")
                return 3
        if in_place(p, outs):
            return 0     # already showing it (e.g. a mango reload): no change, no toast
        try:
            run_layout(p, outs)
        except ApplyError as e:
            print(f"display-profile: {e}", file=sys.stderr)
            toast("Display profile not applied", str(e))
            return 6
        toast(f"Display profile: {p['name']}")
        return 0

    if cmd in ("save", "delete", "set-auto") and len(args) > 1:
        with locked():
            store = load()    # re-read under the lock
            if cmd == "save":
                store = save(store, args[1], outputs_now())
            elif cmd == "delete":
                store["profiles"] = [p for p in store.get("profiles", []) if p["name"] != args[1]]
            elif args[1] in ("on", "off"):
                store["autoApply"] = args[1] == "on"
            else:
                print("usage: display-profile.py set-auto on|off", file=sys.stderr)
                return 2
            write(store)
        return 0

    print("usage: display-profile.py status [--json] | apply [NAME] | save NAME | delete NAME | set-auto on|off",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
