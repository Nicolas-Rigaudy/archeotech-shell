#!/usr/bin/env python3
"""storage-scan.py: read-only disk scan for the Storage panel.

    storage-scan.py --root                    free space only (instant)
    storage-scan.py [--depth N]               free space, cleanup entries, size tree of ~
    storage-scan.py --tree PATH [--depth N]   size tree of one folder (Explore drill-down)
    storage-scan.py --run '{"entries":[{"id":..,"commands":[..]}]}'
                                              run what the user confirmed (JSON lines)

A scan prints one JSON object and never deletes anything: each cleanup entry carries
the exact shell commands the panel shows and, once the user confirms, runs
(entries with "root": true run behind one pkexec prompt).

Cleanup sources are data, described in docs/STORAGE.md: the shipped
storage-sources.json next to this script, then the user's
${XDG_CONFIG_HOME:-~/.config}/archeotech/storage-sources.json, then any
--sources files. A later source with the same id replaces an earlier one, and
"disabled": true hides it. A source that would remove or trash a personal
folder ($HOME, the XDG user dirs and what is inside them, ~/.config, ~/.ssh,
system folders) is never offered: it is listed under "rejected" instead.

--run plans each confirmed entry again from the sources and runs only the
commands that fresh plan still produces (admin ones first, behind one pkexec
prompt; STORAGE_SCAN_PKEXEC overrides the wrapper for tests). It prints
{"event":"start"|"done",...} lines, then {"event":"result","freed":N,...}.

--timeout S (default 25) bounds the whole scan. A scan that runs out of time
reports what it has with "partial": true.
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import glob
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))
SHIPPED = os.path.join(HERE, "storage-sources.json")
TIERS = ("safe", "review")
ACTIONS = ("remove", "trash", "command", "open")
KEEP = (24, 12, 8)          # children kept per tree level (1, 2, 3+); the rest become one box
FILES_KEPT = 12             # loose files listed in the folder being looked at


# ── environment ──────────────────────────────────────────────────────────────
def home():
    return os.path.realpath(os.path.expanduser("~"))


def user_dirs():
    """XDG user dirs (Desktop, Documents, ...) as {KEY: realpath}, from
    user-dirs.dirs over the usual defaults; a dir set to $HOME is left out."""
    h = home()
    out = {"DESKTOP": "Desktop", "DOCUMENTS": "Documents", "DOWNLOAD": "Downloads",
           "MUSIC": "Music", "PICTURES": "Pictures", "PUBLICSHARE": "Public",
           "TEMPLATES": "Templates", "VIDEOS": "Videos"}
    out = {k: os.path.join(h, v) for k, v in out.items()}
    cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(h, ".config")
    try:
        with open(os.path.join(cfg, "user-dirs.dirs"), encoding="utf-8") as f:
            for line in f:
                m = re.match(r'\s*XDG_(\w+)_DIR="(.*)"\s*$', line)
                if m:
                    out[m.group(1)] = m.group(2).replace("$HOME", h)
    except OSError:
        pass
    return {k: os.path.realpath(v) for k, v in out.items() if os.path.realpath(v) != h}


def setup_env():
    """Fill in the variables source paths may use (this process only).
    An unset or empty XDG base dir means its default, as the spec says."""
    h = home()
    for k, d in (("XDG_CACHE_HOME", ".cache"), ("XDG_DATA_HOME", ".local/share"),
                 ("XDG_CONFIG_HOME", ".config"), ("XDG_STATE_HOME", ".local/state")):
        if not os.environ.get(k):
            os.environ[k] = os.path.join(h, d)
    for k, v in user_dirs().items():
        os.environ.setdefault("XDG_%s_DIR" % k, v)


def expand(p):
    return os.path.expanduser(os.path.expandvars(p))


def tilde(p):
    h = home()
    return "~" + p[len(h):] if p == h or p.startswith(h + "/") else p


def inside(p, d):
    return p == d or p.startswith(d.rstrip("/") + "/")


# ── safety guard ─────────────────────────────────────────────────────────────
SYSTEM_DIRS = ("/", "/bin", "/boot", "/dev", "/efi", "/etc", "/home", "/lib", "/lib64",
               "/mnt", "/opt", "/proc", "/root", "/run", "/sbin", "/srv", "/sys", "/tmp",
               "/usr", "/var", "/var/cache", "/var/lib", "/var/log")
# Settings, keys and programs: nothing in them is offered.
HOME_KEEP_TREE = (".config", ".ssh", ".gnupg", ".password-store", ".pki", ".mozilla", ".local/bin")
# Parents of caches: the folder itself is refused, folders inside may be offered.
HOME_KEEP_EXACT = (".cache", ".local", ".local/share", ".local/state")


def keep_dirs():
    """([folders refused with everything inside], [folders refused themselves])."""
    h, env = home(), os.environ
    tree = [os.path.join(h, k) for k in HOME_KEEP_TREE]
    exact = [os.path.join(h, k) for k in HOME_KEEP_EXACT]
    if env.get("XDG_CONFIG_HOME"):
        tree.append(env["XDG_CONFIG_HOME"])
    for k in ("XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME"):
        if env.get(k):
            exact.append(env[k])
    return [os.path.realpath(d) for d in tree], [os.path.realpath(d) for d in exact]


def personal_reason(path):
    """Why removing or trashing `path` is refused, or None when it is allowed."""
    rp = os.path.realpath(path)
    h = home()
    if rp in SYSTEM_DIRS:
        return "system folder"
    if inside(h, rp):
        return "home folder or one of its parents"
    if (inside(rp, "/home") or inside(rp, "/root")) and not inside(rp, h):
        return "another user's folder"
    tree, exact = keep_dirs()
    for d in tree:
        if inside(rp, d):
            return "%s holds settings, keys or programs" % tilde(d)
    if rp in exact:
        return "%s holds other apps' data" % tilde(rp)
    for d in user_dirs().values():
        if inside(rp, d) or inside(d, rp):
            return "personal folder (%s)" % tilde(d)
    return None


def children_base_reason(base):
    """A children source offers every folder inside its base, so the base must
    be a cache area: $XDG_CACHE_HOME or $XDG_STATE_HOME (or inside them), or a
    folder inside $XDG_DATA_HOME. None when allowed."""
    rp, env = os.path.realpath(base), os.environ
    for k in ("XDG_CACHE_HOME", "XDG_STATE_HOME"):
        if env.get(k) and inside(rp, os.path.realpath(env[k])):
            return None
    data = env.get("XDG_DATA_HOME")
    if data and inside(rp, os.path.realpath(data)) and rp != os.path.realpath(data):
        return None
    return "children only works inside ~/.cache, ~/.local/state or a folder in ~/.local/share"


def guarded(s):
    """Whether the source acts on its paths (so they must pass the guard)."""
    a = s["action"]
    return a in ("remove", "trash") or (a == "command" and ("{path}" in s["command"] or "{paths}" in s["command"]))


# ── sizes ────────────────────────────────────────────────────────────────────
class Clock:
    """The scan's time budget; every subprocess gets what is left of it."""

    def __init__(self, budget):
        self.end = time.monotonic() + budget
        self.partial = False

    def left(self):
        return max(0.5, self.end - time.monotonic())

    def expired(self):
        """Out of time: the caller skips its work and the result is partial."""
        if time.monotonic() >= self.end:
            self.partial = True
            return True
        return False


def du(args, clock):
    """Run `du -xb ARGS`; return ([(bytes, path)], complete). Lines printed
    before a timeout are kept. Unreadable parts make the result incomplete."""
    if clock.expired():
        return [], False
    try:
        p = subprocess.run(["du", "-xb"] + args, capture_output=True, text=True,
                           errors="replace", timeout=clock.left())
        out, complete = p.stdout, p.returncode == 0
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        complete = False
        clock.partial = True
    except OSError:
        return [], False
    lines = []
    for line in out.splitlines():
        b, _, path = line.partition("\t")
        if b.isdigit() and path:
            lines.append((int(b), path))
    return lines, complete


def size_of(path, clock):
    """(bytes or None, approx) of one path."""
    lines, complete = du(["-s", path], clock)
    if not lines:
        return None, True
    return lines[-1][0], not complete


def shell_text(cmd, clock):
    if clock.expired():
        return ""
    try:
        return subprocess.run(["sh", "-c", cmd], capture_output=True, text=True,
                              timeout=min(10, clock.left())).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


# ── free space ───────────────────────────────────────────────────────────────
def root_info(mount="/"):
    """Free space of `mount`; None when it cannot be read."""
    try:
        st = os.statvfs(mount)
    except OSError:
        return None
    size = st.f_blocks * st.f_frsize
    info = {"mount": mount, "fstype": "", "size": size,
            "used": (st.f_blocks - st.f_bfree) * st.f_frsize,
            "free": st.f_bavail * st.f_frsize,
            "btrfs_metadata_free": None, "btrfs_unallocated": None}
    try:
        info["fstype"] = subprocess.run(["findmnt", "-no", "FSTYPE", "-T", mount], capture_output=True,
                                        text=True, timeout=3).stdout.strip().splitlines()[0]
    except (OSError, subprocess.TimeoutExpired, IndexError):
        pass
    if info["fstype"] == "btrfs" and shutil.which("btrfs"):
        try:
            u = subprocess.run(["btrfs", "filesystem", "usage", "-b", mount],
                               capture_output=True, text=True, timeout=5).stdout
            m = re.search(r"Free \(estimated\):\s+(\d+)", u)
            if m:
                info["free"] = min(info["free"], int(m.group(1)))   # lower wins, as disk-alert
            m = re.search(r"Device unallocated:\s+(\d+)", u)
            if m:
                info["btrfs_unallocated"] = int(m.group(1))
            d = subprocess.run(["btrfs", "filesystem", "df", "-b", mount],
                               capture_output=True, text=True, timeout=5).stdout
            m = re.search(r"^Metadata[^:]*:\s*total=(\d+), used=(\d+)", d, re.M)
            if m:
                info["btrfs_metadata_free"] = int(m.group(1)) - int(m.group(2))
        except (OSError, subprocess.TimeoutExpired):
            pass
    info["free_pct"] = int(info["free"] * 100 // size) if size else 0
    info["used_pct"] = 100 - info["free_pct"]
    return info


# ── sources ──────────────────────────────────────────────────────────────────
def has_children(s):
    """A children source sizes each folder inside its path; {} means the defaults."""
    return isinstance(s.get("children"), dict)


def check_source(s):
    """A problem with one source definition, or None."""
    if not isinstance(s, dict) or not isinstance(s.get("id"), str) or not s["id"]:
        return "a source without an id"
    if s.get("disabled"):
        return None
    sid = s["id"]
    if not isinstance(s.get("label"), str) or not s["label"]:
        return "%s: no label" % sid
    if s.get("tier") not in TIERS:
        return "%s: tier must be %s" % (sid, " or ".join(TIERS))
    if s.get("action") not in ACTIONS:
        return "%s: action must be one of %s" % (sid, ", ".join(ACTIONS))
    if s["action"] == "command" and not isinstance(s.get("command"), str):
        return "%s: action command needs a command" % sid
    if not (s.get("path") or s.get("paths") or s["action"] == "command"):
        return "%s: no path" % sid
    if "children" in s and not has_children(s):
        return "%s: children must be an object" % sid
    if has_children(s) and s["action"] not in ("remove", "trash"):
        return "%s: children works with remove or trash only" % sid
    return None


def load_sources(files, errors):
    """Merge source files in order; a later id replaces an earlier one."""
    merged, order = {}, []
    for f in files:
        if not f or not os.path.exists(f):
            continue
        try:
            with open(f, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, ValueError) as e:
            errors.append("%s: %s" % (tilde(f), e))
            continue
        items = data.get("sources") if isinstance(data, dict) else data
        if not isinstance(items, list):
            errors.append("%s: expected {\"sources\": [...]}" % tilde(f))
            continue
        for s in items:
            problem = check_source(s)
            if problem:
                errors.append("%s: %s" % (tilde(f), problem))
                continue
            if s["id"] not in merged:
                order.append(s["id"])
            merged[s["id"]] = dict(s, _user=os.path.realpath(f) != SHIPPED)
    return [merged[i] for i in order if not merged[i].get("disabled")]


def candidates(s):
    """The source's existing paths: variables and ~ expanded, globs matched.
    A path with an unset variable does not apply to this machine."""
    raw = s.get("paths") or ([s["path"]] if s.get("path") else [])
    out = []
    for p in raw:
        p = expand(p)
        if "$" in p:
            continue
        matches = sorted(glob.glob(p)) if s.get("glob") else ([p] if os.path.lexists(p) else [])
        out.extend(m.rstrip("/") or "/" for m in matches)
    return out


def commands_for(s, paths):
    q = [shlex.quote(p) for p in paths]
    a = s["action"]
    if a == "remove":
        return ["rm -rf -- %s" % x for x in q]
    if a == "trash":
        return ["gio trash -- %s" % x for x in q]
    if a == "command":
        cmd = s["command"]
        if "{path}" in cmd:
            return [cmd.replace("{path}", x) for x in q]
        return [cmd.replace("{paths}", " ".join(q))]
    return []                                   # open: the panel opens the folder


def fill(text, path, shell=False):
    """{name}, {path} and {mtime} (YYYY-MM-DD) of a path in a label or detail.
    shell=True (detail_command, which sh runs): name and the real path are quoted."""
    if not text:
        return ""
    try:
        mtime = dt.date.fromtimestamp(os.lstat(path).st_mtime).isoformat() if path else ""
    except OSError:
        mtime = ""
    name = os.path.basename(path or "")
    shown = (path or "") if shell else tilde(path or "")
    if shell:
        name, shown = shlex.quote(name), shlex.quote(shown)
    return text.replace("{name}", name).replace("{path}", shown).replace("{mtime}", mtime)


def plan_entries(sources, clock, rejected):
    """What to size: [(source, paths, known_bytes, entry_id)]. Plain sources go
    first so a children source never lists a folder a specific source owns."""
    claimed, plans = set(), []
    for s in sources:
        if has_children(s) or (s.get("requires") and not shutil.which(s["requires"])):
            continue
        ok = []
        for p in candidates(s):
            why = personal_reason(p) if guarded(s) else None
            rp = os.path.realpath(p)
            if why:
                rejected.append({"id": s["id"], "path": tilde(p), "reason": why})
            elif not any(inside(rp, c) or inside(c, rp) for c in claimed):
                claimed.add(rp)                 # nested in (or holding) a claimed path: counted once
                ok.append(p)
        if not ok and (s.get("path") or s.get("paths")):
            continue                            # nothing of it on this machine
        if s.get("glob") and not s.get("group"):
            plans += [(s, [p], None, "%s:%s" % (s["id"], os.path.basename(p))) for p in ok]
        else:
            plans.append((s, ok, None, s["id"]))
    for s in sources:
        if not has_children(s) or (s.get("requires") and not shutil.which(s["requires"])):
            continue
        ch = s["children"]
        exclude = {os.path.realpath(expand(e)) for e in ch.get("exclude", [])}
        kids = []
        for base in candidates(s):
            why = children_base_reason(base)     # each child still passes personal_reason below
            if why:
                rejected.append({"id": s["id"], "path": tilde(base), "reason": why})
                continue
            lines, _ = du(["--max-depth=1", base], clock)
            for b, p in lines:
                rp = os.path.realpath(p)
                # A folder holding (or held by) another source's path would count it twice.
                if rp == os.path.realpath(base) or rp in exclude or b < int(ch.get("min_bytes", 0)) \
                        or any(inside(c, rp) or inside(rp, c) for c in claimed):
                    continue
                why = personal_reason(p)
                if why:
                    rejected.append({"id": s["id"], "path": tilde(p), "reason": why})
                else:
                    kids.append((b, p))
        kids = sorted(kids, reverse=True)[:int(ch.get("max", 8))]
        claimed.update(os.path.realpath(p) for _, p in kids)
        if not kids:
            continue
        if ch.get("group", True):
            plans.append((s, [p for _, p in kids], sum(b for b, _ in kids), s["id"]))
        else:
            plans += [(s, [p], b, "%s:%s" % (s["id"], os.path.basename(p))) for b, p in kids]
    return plans


def make_entry(plan, clock):
    s, paths, known, eid = plan
    approx = False
    if s.get("size") == "none":
        b = None
    elif known is not None:
        b = known
    else:
        b = 0
        for p in paths:
            pb, pa = size_of(p, clock)
            approx = approx or pa
            b = None if pb is None or b is None else b + pb
    first = paths[0] if paths else ""
    grouped = has_children(s) and s["children"].get("group", True)
    if grouped:
        names = [os.path.basename(p) for p in paths]
        detail = ", ".join(names[:5]) + (" +%d" % (len(names) - 5) if len(names) > 5 else "")
    else:
        detail = fill(s.get("detail", "{path}"), first)
    if s.get("detail_command"):
        detail = shell_text(fill(s["detail_command"], first, shell=True), clock) or detail
    checked = s.get("checked", s["tier"] == "safe" and s["action"] != "open" and bool(b))
    return {
        "id": eid, "source": s["id"], "label": fill(s["label"], first), "detail": detail,
        "cost": fill(s.get("cost", ""), first), "tier": s["tier"], "action": s["action"],
        "root": bool(s.get("root")), "bytes": b, "approx": approx, "upto": bool(s.get("upto")),
        "paths": paths, "commands": commands_for(s, paths), "checked": bool(checked),
        "user": s["_user"],
    }


def build_entries(sources, clock, rejected):
    plans = plan_entries(sources, clock, rejected)
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        entries = list(ex.map(lambda p: make_entry(p, clock), plans))
    return sorted(entries, key=lambda e: (TIERS.index(e["tier"]), -(e["bytes"] or 0)))


# ── size tree ────────────────────────────────────────────────────────────────
def tier_rows(sources):
    """[(realpath, tier)] of the sources' cleanable paths, for colouring the
    tree. A children source's base ends in "/": it colours what is inside."""
    rows = []
    for s in sources:
        if s["action"] == "open" or (s.get("requires") and not shutil.which(s["requires"])):
            continue
        for p in candidates(s):
            if has_children(s):
                if not children_base_reason(p):
                    rows.append((os.path.realpath(p).rstrip("/") + "/", s["tier"]))
            elif not guarded(s) or not personal_reason(p):
                rows.append((os.path.realpath(p), s["tier"]))
    return sorted(rows, key=lambda r: r[0].endswith("/"))   # specific sources win


def tier_of(path, rows, udirs):
    rp = os.path.realpath(path)
    for p, t in rows:
        if rp.startswith(p) if p.endswith("/") else inside(rp, p):
            return t
    for d in udirs:
        if inside(rp, d):
            return "personal"
    return ""


def loose_files(path):
    """Regular files directly in `path`, largest first: [(bytes, name)]."""
    out = []
    try:
        with os.scandir(path) as it:
            for de in it:
                try:
                    if de.is_file(follow_symlinks=False):
                        out.append((de.stat(follow_symlinks=False).st_size, de.name))
                except OSError:
                    pass
    except OSError:
        pass
    return sorted(out, reverse=True)


def build_tree(root, depth, lines, complete, rows):
    """Nested {name, path, bytes, kind, tier?, children?} from `du --max-depth`
    lines. kind: dir, file, more (folders lumped together), files (loose files)."""
    sizes = {p: b for b, p in lines}
    kids = {}
    for p in sizes:
        if p != root:
            kids.setdefault(os.path.dirname(p), []).append(p)
    udirs = list(user_dirs().values())

    def size(p):
        # du prints a folder after its contents: a timed-out walk may lack the parent line.
        return sizes[p] if p in sizes else sum(size(c) for c in kids.get(p, []))

    def node(p, level):
        b = size(p)
        n = {"name": os.path.basename(p) or p, "path": p, "bytes": b, "kind": "dir"}
        t = tier_of(p, rows, udirs)
        if t:
            n["tier"] = t
        if level >= depth:
            return n
        ch = sorted(kids.get(p, []), key=size, reverse=True)
        keep = KEEP[min(level, len(KEEP) - 1)]
        children = [node(c, level + 1) for c in ch[:keep]]
        if ch[keep:]:
            children.append({"name": "%d more folders" % len(ch[keep:]), "path": p, "kind": "more",
                             "bytes": sum(size(c) for c in ch[keep:])})
        loose = b - sum(size(c) for c in ch)
        if level == 0:                          # the folder being looked at: name its files
            files = loose_files(p)
            for fb, name in files[:FILES_KEPT]:
                if 0 < fb <= loose:
                    f = {"name": name, "path": os.path.join(p, name), "bytes": fb, "kind": "file"}
                    if t:
                        f["tier"] = t
                    children.append(f)
                    loose -= fb
            if loose > 0 and (children or len(files) > FILES_KEPT):
                children.append({"name": "%d smaller files" % max(0, len(files) - FILES_KEPT)
                                 if len(files) > FILES_KEPT else "other files",
                                 "path": p, "kind": "files", "bytes": loose})
        elif loose > 0 and children:
            children.append({"name": "files", "path": p, "kind": "files", "bytes": loose})
        if children:
            n["children"] = sorted(children, key=lambda c: c["bytes"], reverse=True)
        return n

    tree = node(root, 0)
    tree["complete"] = complete
    return tree


# ── run (after the user confirmed) ───────────────────────────────────────────
# Offered by the result screen after a big cleanup leaves btrfs no unallocated
# space (same command disk-report.sh suggests). Fixed here, never from a source.
BALANCE = {"id": "@balance", "root": True, "commands": ["btrfs balance start -dusage=50 /"]}
CMD_TIMEOUT = 1800          # one cleanup command (a balance can take minutes)


def run_jobs(sources, wanted, clock, rejected):
    """The panel's confirmed list [{id, commands}] -> ([(id, root, commands)], [(id, why)]).
    Each entry is planned again from the sources (same guard as the scan) and
    only commands the fresh plan still produces run: a hand-made or stale
    request runs nothing."""
    plans = {p[3]: p for p in plan_entries(sources, clock, rejected)}
    jobs, refused = [], []
    for w in wanted:
        eid, asked = w.get("id"), w.get("commands") or []
        if eid == BALANCE["id"]:
            fresh, root = BALANCE["commands"], True
        elif eid in plans:
            s, paths = plans[eid][0], plans[eid][1]
            fresh, root = commands_for(s, paths), bool(s.get("root"))
        else:
            refused.append((eid, "not found any more; rescan"))
            continue
        if not asked or any(c not in fresh for c in asked):
            refused.append((eid, "changed since the scan; rescan"))
            continue
        jobs.append((eid, root, list(asked)))
    return jobs, refused


def _emit(**ev):
    print(json.dumps(ev, separators=(",", ":")), flush=True)


def run_cleanup(jobs, pkexec):
    """Admin jobs first, all in one `pkexec sh -c` (one password prompt, asked
    straight away), then the user's own. Prints one JSON line per event."""
    failed = 0
    root_jobs = [j for j in jobs if j[1]]
    if root_jobs:
        script = ["set +e"]
        for i, (eid, _, cmds) in enumerate(root_jobs):
            script.append("rc=0")
            script += ["( %s ) </dev/null >&2 || rc=$?" % c for c in cmds]
            script.append("echo \"@@rc %d $rc\"" % i)
        for eid, _, _ in root_jobs:
            _emit(event="start", id=eid)
        try:
            p = subprocess.run(pkexec + ["sh", "-c", "\n".join(script)], capture_output=True,
                               text=True, timeout=CMD_TIMEOUT * len(root_jobs))
            out, err, code = p.stdout, p.stderr, p.returncode
        except (OSError, subprocess.TimeoutExpired) as e:
            out, err, code = "", str(e), -1
        rcs = {int(m.group(1)): int(m.group(2)) for m in re.finditer(r"^@@rc (\d+) (\d+)$", out, re.M)}
        last = (err.strip().splitlines() or [""])[-1][:200]
        for i, (eid, _, _) in enumerate(root_jobs):
            failed += rcs.get(i, 1) != 0
            if i in rcs:
                _emit(event="done", id=eid, ok=rcs[i] == 0, error="" if rcs[i] == 0 else last or "exit %d" % rcs[i])
            else:                       # 126/127: the prompt was dismissed or not authorized
                _emit(event="done", id=eid, ok=False,
                      error=("no password prompt: no polkit agent running" if "authentication agent" in err
                             else "password prompt cancelled" if code in (126, 127) else last or "did not run"))
    for eid, _, cmds in [j for j in jobs if not j[1]]:
        _emit(event="start", id=eid)
        ok, last = True, ""
        for c in cmds:
            try:
                p = subprocess.run(["sh", "-c", c], stdin=subprocess.DEVNULL, capture_output=True,
                                   text=True, timeout=CMD_TIMEOUT)
                if p.returncode:
                    ok, last = False, ((p.stderr.strip().splitlines() or [""])[-1][:200]
                                       or "exit %d" % p.returncode)
            except (OSError, subprocess.TimeoutExpired) as e:
                ok, last = False, str(e)[:200]
        failed += not ok
        _emit(event="done", id=eid, ok=ok, error=last)
    return failed


# ── main ─────────────────────────────────────────────────────────────────────
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", action="store_true", help="free space only")
    ap.add_argument("--tree", metavar="PATH", help="size tree of one folder")
    ap.add_argument("--depth", type=int, default=3)
    ap.add_argument("--timeout", type=float, default=25)
    ap.add_argument("--mount", default="/")
    ap.add_argument("--sources", action="append", default=[], help="extra source file (repeatable)")
    ap.add_argument("--no-user-sources", action="store_true")
    ap.add_argument("--run", metavar="JSON", help='run confirmed entries: {"entries":[{"id","commands"}]}')
    a = ap.parse_args(argv)

    setup_env()
    started = time.monotonic()
    if a.run is not None:
        return main_run(a)
    clock = Clock(a.timeout)
    out = {"version": 1, "generated": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
           "root": root_info(a.mount)}
    if out["root"] is None:
        out["error"] = "cannot read free space of %s" % a.mount
        print(json.dumps(out))
        return 1
    if a.root:
        print(json.dumps(out))
        return 0

    errors, rejected = [], []
    user = [] if a.no_user_sources else [
        os.path.join(os.environ["XDG_CONFIG_HOME"], "archeotech", "storage-sources.json")]
    sources = load_sources([SHIPPED] + user + a.sources, errors)
    depth = max(1, a.depth)
    top = os.path.realpath(a.tree) if a.tree else home()   # a real folder name: no ~ or $ expansion
    if not os.path.isdir(top):
        out["error"] = "no such folder: %s" % a.tree
        print(json.dumps(out))
        return 1
    with cf.ThreadPoolExecutor(max_workers=1) as ex:
        walk = ex.submit(du, ["--max-depth=%d" % depth, top], clock)
        if not a.tree:
            out["entries"] = build_entries(sources, clock, rejected)
            out["rejected"] = rejected
        lines, complete = walk.result()
    out["tree"] = build_tree(top, depth, lines, complete, tier_rows(sources))
    out["errors"] = errors
    out["partial"] = clock.partial
    out["elapsed"] = round(time.monotonic() - started, 2)
    print(json.dumps(out, separators=(",", ":")))
    return 0


def main_run(a):
    try:
        wanted = json.loads(a.run)["entries"]
        assert isinstance(wanted, list) and all(isinstance(w, dict) for w in wanted)
    except (ValueError, KeyError, TypeError, AssertionError):
        _emit(event="result", ok=False, error="bad --run request", freed=0)
        return 2
    errors, rejected = [], []
    user = [] if a.no_user_sources else [
        os.path.join(os.environ["XDG_CONFIG_HOME"], "archeotech", "storage-sources.json")]
    sources = load_sources([SHIPPED] + user + a.sources, errors)
    before = root_info(a.mount)
    jobs, refused = run_jobs(sources, wanted, Clock(60), rejected)
    for eid, why in refused:
        _emit(event="done", id=eid, ok=False, error=why)
    pkexec = shlex.split(os.environ.get("STORAGE_SCAN_PKEXEC", "pkexec"))
    failed = run_cleanup(jobs, pkexec) + len(refused)
    after = root_info(a.mount)
    freed = max(0, (after or {}).get("free", 0) - (before or {}).get("free", 0))
    _emit(event="result", ok=failed == 0, before=before, after=after, freed=freed, failed=failed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
