#!/bin/bash
################################################################################
# shot.sh — headless screenshot of the archeotech shell (or one QML component).
#
# Runs a NESTED headless wlroots compositor (mango), launches the shell inside
# it, waits for it to settle, optionally drives a named shell state via `qs ipc`
# (no synthetic input), then grabs a PNG — or a BURST of PNGs — with grim. Lets a
# tool or CI *see* a visual (or motion) change with no physical display attached.
#
#   shot.sh [out.png]                        # full shell from this checkout
#   shot.sh --root ../wt/feature out.png     # render another checkout/worktree
#   shot.sh --qml Widgets/Bar/Foo.qml [out]  # one component in isolation
#   shot.sh -w 10 out.png                    # longer settle wait (default 8s)
#   shot.sh --state launcher out.png         # open the launcher, then capture
#   shot.sh --state settings:appearance out  # open settings on a named pane
#   shot.sh --state setting:clock.format out # open settings on one setting (search key)
#   shot.sh --theme archeotech-latte --pack grimdark --flat 1 out.png
#   shot.sh --shell-config fixtures/bar.json out.png  # render a fixed layout
#   shot.sh --set notifications.maxToasts=2 --notify-count 4 out.png
#   shot.sh --fresh out.png                  # first boot: no user config or state at all
#   shot.sh --notify --burst 6 -i 1 out.png  # fire a toast, capture 6 frames 1s
#                                            #   apart → out-000.png … out-005.png
#   shot.sh --outputs 2 out.png              # two headless outputs side by side
#   shot.sh --mango-line 'devicerule=type:keyboard,repeat_rate:40' out.png
#                                            # append a line to the nested mango config
#                                            #   (repeatable; still passes the command guard)
#   shot.sh --mango-include f.conf out.png   # copy f.conf to the fake ~/.config/mango/ and
#                                            #   source it like the real config does
#                                            #   (source-optional=~/.config/mango/f.conf;
#                                            #   contents guarded too)
#   shot.sh --mango-config f.conf out.png    # start from f.conf instead of the real
#                                            #   ~/.config/mango/config.conf (same filter
#                                            #   and guard), e.g. a config migrated to a
#                                            #   newer mango than the running one
#   shot.sh --exec 'notify-send a; mmsg -d focusmon,right' out.png
#                                            # run a command in the nested session
#                                            #   before capture (after --notify*)
#   shot.sh --renderer gles2 out.png         # render on the GPU (scenefx blur, shadows
#                                            #   and corner effects draw; pixman, the
#                                            #   default, skips them). Needs a readable
#                                            #   /dev/dri render node; goldens stay pixman
#
# STATE-DRIVING (--state <name>): before capture, calls the shell's own IPC
# handler to open a panel — launcher | settings[:pane] | setting:<key> | dashboard | wallpaper |
# media | layout | keybinds | notifications | editmode | theme(reload) |
# panel:<id> (any panel by id, e.g. panel:plugin:notes) | popup:<wifi|bt|calendar|hover|strip>
# (a hover/click popup, no pointer needed).
#
# LOOK (--theme/--pack/--flat): --theme takes a variant dir under <root>/themes
# (dark/light mode comes from that theme.json); --pack takes a pack id or "base";
# --flat 0|1 toggles flat mode. Unset flags keep the user's current choice.
#
# BURST (--burst N [-i SECS]): captures N frames spaced SECS apart into
# out-000.png … out-(N-1).png instead of a single file. Combine with --notify to
# confirm a motion state changed (a toast appears in early frames, gone later).
#
# ISOLATION: every run gets its own temp dir holding
#   • a fake HOME seeded with COPIES of the user's archeotech config/state/cache,
#     so the nested shell can read and write freely without touching the real ones;
#   • a private XDG_RUNTIME_DIR, so the nested Wayland, qs-ipc, awww and PipeWire
#     sockets can never meet the live session's (no audio: the live PipeWire is
#     deliberately unreachable);
#   • its own D-Bus session (dbus-run-session) and a generated minimal mango
#     config passed with -c, so the user's autostart never runs;
#   • a clean environment (env -i + allowlist), so live-session variables such as
#     WAYLAND_DISPLAY or HYPRLAND_INSTANCE_SIGNATURE cannot leak in.
# The shell is launched with `qs -p <root>/shell.qml`, never `qs -c archeotech`,
# so any checkout renders — including git worktrees.
#
# SAFETY: this NEVER kills processes by name. The nested session runs in its own
# process group, torn down by PGID; anything left behind is found by its unique
# private XDG_RUNTIME_DIR and killed by pid. `pkill -x mango` / `pkill quickshell`
# would match your REAL session compositor+shell and log you out.
#
# Requires: mango, qs (quickshell), grim, setsid, wlroots headless backend.
# 1280x720. --notify needs notify-send; wallpaper needs awww (optional).
################################################################################
set -u

WAIT=8              # ponytail: fixed settle wait; poll shot for non-blank if flaky
QML=""
OUT=""
STATE=""            # panel to drive open via qs ipc before capture (empty = none)
BURST=1             # frames to capture (1 = single shot); >1 → out-NNN.png series
INTERVAL=1          # seconds between burst frames
NOTIFY=0            # 1 → fire a demo notification to exercise the toast pipeline
ROOT=""             # checkout to render (default: the repo this script lives in)
THEME=""            # theme variant dir under <root>/themes (empty = user's current)
PACK="-"            # pack id, "base" for none, "-" = user's current
FLAT="-"            # 0|1, "-" = user's current
WALLPAPER=""        # image path (default: what the live awww shows, if anything)
SHELL_CONFIG=""     # shell-config.json to render with (default: the user's copy)
MANGO_LINES=()      # extra lines appended to the nested mango config (--mango-line)
MANGO_INCLUDES=()   # files sourced by the nested mango config (--mango-include)
SETS=()             # config.json overrides, key.path=json-value (repeatable --set)
NOTIFY_COUNT=0      # >0 → fire N notifications with no expiry (the shell's own timeout applies)
KEEP=0              # 1 → keep the run dir (logs, fake HOME) even on success
FRESH=0             # 1 → copy none of the user's config/state/cache (a stranger's first boot)
OUTPUTS=1           # headless outputs (multi-monitor cases); grim captures them all
EXEC=""             # shell command run inside the nested session before capture
RENDERER=pixman     # wlroots renderer: pixman (default, goldens) | gles2 (GPU, scenefx effects)
MANGO_LIBS=""        # dir of locally built libs (e.g. a patched scenefx) for the nested session
MANGO_CONFIG=""      # base mango config instead of the real one (--mango-config)

while [ $# -gt 0 ]; do
  case "$1" in
    --qml)      QML="$2"; shift 2 ;;
    -w)         WAIT="$2"; shift 2 ;;
    --state)    STATE="$2"; shift 2 ;;
    --burst)    BURST="$2"; shift 2 ;;
    -i|--interval) INTERVAL="$2"; shift 2 ;;
    --notify)   NOTIFY=1; shift ;;
    --root)     ROOT="$2"; shift 2 ;;
    --theme)    THEME="$2"; shift 2 ;;
    --pack)     PACK="$2"; shift 2 ;;
    --flat)     FLAT="$2"; shift 2 ;;
    --wallpaper) WALLPAPER="$2"; shift 2 ;;
    --shell-config) SHELL_CONFIG="$(readlink -f "$2")"; shift 2 ;;
    --set)      SETS+=("$2"); shift 2 ;;
    --mango-line) MANGO_LINES+=("$2"); shift 2 ;;
    --mango-include) MANGO_INCLUDES+=("$2"); shift 2 ;;
    --mango-config) MANGO_CONFIG="$(readlink -f "$2")"; shift 2 ;;
    --notify-count) NOTIFY_COUNT="$2"; shift 2 ;;
    --keep)     KEEP=1; shift ;;
    --fresh)    FRESH=1; shift ;;
    --outputs)  OUTPUTS="$2"; shift 2 ;;
    --exec)     EXEC="$2"; shift 2 ;;
    --renderer) RENDERER="$2"; shift 2 ;;
    --mango-libs) MANGO_LIBS="$(readlink -f "$2")"; shift 2 ;;
    -*)         echo "unknown flag: $1" >&2; exit 2 ;;
    *)          OUT="$1"; shift ;;
  esac
done

case "$RENDERER" in pixman|gles2) ;; *) echo "bad --renderer: $RENDERER (pixman|gles2)" >&2; exit 2 ;; esac
if [ -n "$MANGO_LIBS" ] && [ ! -d "$MANGO_LIBS" ]; then echo "bad --mango-libs: not a directory" >&2; exit 2; fi
if [ -n "$MANGO_CONFIG" ] && [ ! -f "$MANGO_CONFIG" ]; then echo "bad --mango-config: no such file" >&2; exit 2; fi

ROOT="$(cd "${ROOT:-$(dirname "$(readlink -f "$0")")/..}" && pwd)" || { echo "bad --root" >&2; exit 2; }
[ -f "$ROOT/shell.qml" ] || { echo "no shell.qml in $ROOT" >&2; exit 2; }

OUT="${OUT:-/tmp/archeotech-shot.png}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
BASE="${OUT%.png}"
rm -f "$OUT" "$OUT.tmp" "$BASE"-[0-9][0-9][0-9].png 2>/dev/null

if [ -n "$QML" ]; then
  [ -f "$QML" ] || QML="$ROOT/$QML"
  [ -f "$QML" ] || { echo "no such component: $QML" >&2; exit 2; }
  QML="$(readlink -f "$QML")"
  LAUNCH="qs -p '$QML'"
else
  LAUNCH="qs -p '$ROOT/shell.qml'"
fi

# ── Run dir + fake HOME ──────────────────────────────────────────────────────
# The real home comes from passwd, not $HOME: sandboxed callers may have a
# different $HOME, and the copies must come from the user's actual config.
USER_NAME="$(id -un)"
REAL_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
RUN="$(mktemp -d "${TMPDIR:-/tmp}/archeotech-shot.XXXXXX")"
FH="$RUN/home/$USER_NAME"            # basename = user name, so greetings match
RT="$RUN/runtime"
LOG="$RUN/log"
DONE="$RUN/done"
mkdir -p "$FH/.config/archeotech" "$FH/.local/share/archeotech" "$FH/.cache" "$RT" "$LOG"
chmod 700 "$RT"

RA="$REAL_HOME/.config/archeotech"
if [ "$FRESH" = 0 ]; then
  for f in config.json shell-config.json theme.json; do
    [ -f "$RA/$f" ] && cp "$RA/$f" "$FH/.config/archeotech/$f"
  done
fi
if [ -n "$SHELL_CONFIG" ]; then
  [ -f "$SHELL_CONFIG" ] || { echo "no such --shell-config: $SHELL_CONFIG" >&2; rm -rf "$RUN"; exit 2; }
  cp "$SHELL_CONFIG" "$FH/.config/archeotech/shell-config.json"
fi
# Read-only resources: symlinks are fine, nothing writes into them.
ln -s "$ROOT/themes"         "$FH/.config/archeotech/themes"
ln -s "$ROOT/scripts/assets" "$FH/.config/archeotech/assets"
[ -e "$RA/wallpapers" ] && ln -s "$(readlink -f "$RA/wallpapers")" "$FH/.config/archeotech/wallpapers"
if [ "$FRESH" = 0 ]; then
  [ -d "$REAL_HOME/.local/share/archeotech" ] && cp -a "$REAL_HOME/.local/share/archeotech/." "$FH/.local/share/archeotech/"
  [ -d "$REAL_HOME/.cache/archeotech" ] && cp -a "$REAL_HOME/.cache/archeotech" "$FH/.cache/"
  # A COPY of the owner's mango config, as data for the shell (the shortcuts
  # sheet parses its binds). The nested mango never reads it: it runs on the
  # generated $RUN/mango.conf (-c), which sources only --mango-include files.
  if [ -f "$REAL_HOME/.config/mango/config.conf" ]; then
    mkdir -p "$FH/.config/mango"
    cp "$REAL_HOME/.config/mango/config.conf" "$FH/.config/mango/config.conf"
  fi
fi
# ~/.local/bin is an ALLOWLIST, not a symlink to the real dir: some user scripts
# act on the live session by process name (theme-switch sends SIGUSR1 to every
# kitty; mango-reload/shell-reload pkill quickshell). Only scripts that are safe
# inside the nested session are linked; the rest become stubs that log their
# arguments to log/stubs.log (tests can count calls there).
mkdir -p "$FH/.local/bin"
for s in wallpaper-set.sh wallpaper-picker.sh list-desktop-apps.sh wifi-scan.sh; do
  [ -e "$REAL_HOME/.local/bin/$s" ] && ln -s "$(readlink -f "$REAL_HOME/.local/bin/$s")" "$FH/.local/bin/$s"
done
for s in theme-switch.sh theme-switch.py hyprlock-launch.sh wlogout-launch.sh swaylock-launch.sh \
         mango-reload.sh shell-reload.sh gaming-mode.sh monitor-apply.sh zen-opacity-toggle.sh; do
  printf '#!/bin/sh\necho "$(date +%%T) %s $*" >> "%s/stubs.log"\n' "$s" "$LOG" > "$FH/.local/bin/$s"
  chmod +x "$FH/.local/bin/$s"
done
for d in .local/share/fonts .local/share/icons .config/fontconfig Projects; do
  [ -e "$REAL_HOME/$d" ] && { mkdir -p "$(dirname "$FH/$d")"; ln -s "$REAL_HOME/$d" "$FH/$d"; }
done

# ── Look overrides (theme / pack / flat) ─────────────────────────────────────
if [ -n "$THEME" ] || [ "$PACK" != "-" ] || [ "$FLAT" != "-" ]; then
  python3 - "$ROOT" "$FH" "$THEME" "$PACK" "$FLAT" <<'PY' || { echo "bad --theme/--pack/--flat" >&2; exit 2; }
import json, os, sys
root, fh, theme, pack, flat = sys.argv[1:]
cfg_path = f"{fh}/.config/archeotech/config.json"
cfg = json.load(open(cfg_path)) if os.path.exists(cfg_path) else {}
if theme:
    t = json.load(open(f"{root}/themes/{theme}/theme.json"))
    t["_dir"] = f"{fh}/.config/archeotech/themes/{theme}"
    json.dump(t, open(f"{fh}/.config/archeotech/theme.json", "w"), indent=2)
    mode = t.get("mode", "dark")
    cfg.setdefault("theme", {})["variant"] = theme
    cs = cfg.setdefault("colorScheme", {})
    cs["mode"] = mode
    if t.get("family"): cs["family"] = t["family"]
    if t.get("flavor"): cs["flavorDark" if mode == "dark" else "flavorLight"] = t["flavor"]
ap = cfg.setdefault("appearance", {})
if pack != "-": ap["activePack"] = "" if pack == "base" else pack
if flat != "-": ap["flatMode"] = flat == "1"
json.dump(cfg, open(cfg_path, "w"), indent=2)
PY
fi

# ── Arbitrary config.json overrides (--set a.b.c=<json or string>) ──────────
if [ "${#SETS[@]}" -gt 0 ]; then
  python3 - "$FH/.config/archeotech/config.json" "${SETS[@]}" <<'PY' || { echo "bad --set" >&2; exit 2; }
import json, os, sys
path, sets = sys.argv[1], sys.argv[2:]
cfg = json.load(open(path)) if os.path.exists(path) else {}
for kv in sets:
    key, _, raw = kv.partition("=")
    try: val = json.loads(raw)
    except ValueError: val = raw
    node = cfg
    parts = key.split(".")
    for p in parts[:-1]: node = node.setdefault(p, {})
    node[parts[-1]] = val
json.dump(cfg, open(path, "w"), indent=2)
PY
fi

# ── Minimal nested mango config: wallpaper only, never the user's autostart ──
if [ -z "$WALLPAPER" ] && command -v awww >/dev/null 2>&1; then
  WALLPAPER="$(timeout 2 awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -1)"
fi
# Start from the owner's REAL mango config so renders look like the real session
# (borders, gaps, radius, shadows, blur, layout, window/layer rules), minus every
# line that could reach outside the nested session: autostart (exec/exec-once),
# key/mouse/gesture binds (they call the owner's scripts) and monitor rules for the
# physical outputs. --fresh renders a stranger's first boot, so it keeps mango's
# defaults.
: > "$RUN/mango.conf"
# Our own lines go FIRST: the wallpaper autostart, then (with --theme) that theme's
# window colours. The owner's config follows, minus the keys set here.
# The wallpaper starts from STARTUP below (inside the session), not exec-once:
# with the owner's full config loaded, mango's exec-once did not fire here.
WP_CMD=":"
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ] && command -v awww-daemon >/dev/null 2>&1; then
  printf '%s' "$WALLPAPER" > "$RUN/wallpaper.path"   # read back in-session: no quoting of the path
  WP_CMD="(awww-daemon >$LOG/awww.log 2>&1 &) ; sleep 1; awww img \"\$(cat $RUN/wallpaper.path)\" >>$LOG/awww.log 2>&1"
fi
OVERRIDE="exec|exec-once|exec_once|source_optional|bind|binds|gesturebind|mousebind|axisbind|switchbind|touchbind|keymode|monitorrule|monitor_rule|env|source|source-optional|spawn_on_empty"
# mango 0.18 renamed the colour keys (bordercolor -> border_color, ...) and draws
# an error overlay over the output for an unknown key, so the theme's colours
# (stored under the 0.17 names) are written under the nested mango's names.
MANGO_VER="$(mango -v 2>&1 | sed -n 's/^mango \([0-9]*\.[0-9]*\).*/\1/p' | head -1)"
if [ -n "$THEME" ] && [ -f "$ROOT/themes/$THEME/theme.json" ]; then
  python3 - "$ROOT/themes/$THEME/theme.json" "${MANGO_VER:-0.0}" >> "$RUN/mango.conf" <<'PY'
import json, sys
m = json.load(open(sys.argv[1])).get("mango", {})
new = tuple(int(x) for x in sys.argv[2].split(".")) >= (0, 18)
for k in ("bordercolor", "focuscolor", "urgentcolor", "shadowscolor"):
    if k in m: print(f"{k[:-5] + '_color' if new else k}={m[k]}")
PY
  OVERRIDE="$OVERRIDE|bordercolor|focuscolor|urgentcolor|shadowscolor|border_color|focus_color|urgent_color|shadows_color"
fi
MANGO_BASE="${MANGO_CONFIG:-$REAL_HOME/.config/mango/config.conf}"
if [ "$FRESH" != 1 ] && [ -f "$MANGO_BASE" ]; then
  grep -v -E '^[[:space:]]*(#|$)' "$MANGO_BASE" \
    | grep -v -i -E "^[[:space:]]*($OVERRIDE)[[:space:]]*=" >> "$RUN/mango.conf"
fi
for l in "${MANGO_LINES[@]}"; do printf '%s\n' "$l" >> "$RUN/mango.conf"; done
# --mango-include: the file goes into the FAKE home and is sourced through `~`,
# exactly like the owner's `source-optional=~/.config/mango/archeotech-input.conf`
# (mango 0.17.5 resolves a bare relative name against its working directory, not
# the config dir; only `./` and `~` are config-dir / home relative).
INCLUDE_LINES=()
for f in "${MANGO_INCLUDES[@]}"; do
  [ -f "$f" ] || { echo "shot.sh: no such --mango-include file: $f" >&2; rm -rf "$RUN"; exit 2; }
  b=$(basename "$f")
  mkdir -p "$FH/.config/mango"
  cp "$f" "$FH/.config/mango/$b"
  printf 'source-optional=~/.config/mango/%s\n' "$b" >> "$RUN/mango.conf"
  INCLUDE_LINES+=("source-optional=~/.config/mango/$b")
done
# Guard: refuse to start if anything command-like survived the filter (a mango
# keyword added after this list was written, or a spawn action inside a rule).
# Exempt: only the exact source-optional lines added for --mango-include; the
# included files themselves are scanned too.
GUARDED=$(cat "$RUN/mango.conf")
for l in "${INCLUDE_LINES[@]}"; do GUARDED=$(printf '%s\n' "$GUARDED" | grep -vxF "$l"); done
for f in "${MANGO_INCLUDES[@]}"; do GUARDED=$(printf '%s\n%s\n' "$GUARDED" "$(cat "$f")"); done
if printf '%s\n' "$GUARDED" | grep -n -i -E '^[[:space:]]*[a-z_-]*(exec|bind|source|spawn|env)[a-z_-]*[[:space:]]*=|spawn'; then
  echo "shot.sh: inherited mango config still has a command-like line (above); not starting" >&2
  rm -rf "$RUN"; exit 3
fi

DRIVE=":"   # no-op by default
if [ -n "$STATE" ]; then
  case "$STATE" in
    settings:*) DRIVE="qs ipc --pid \$QSPID call settings openPane \"${STATE#settings:}\"" ;;
    setting:*)  DRIVE="qs ipc --pid \$QSPID call settings focus \"${STATE#setting:}\"" ;;
    panel:*)    DRIVE="qs ipc --pid \$QSPID call panel open \"${STATE#panel:}\"" ;;
    popup:*)    DRIVE="qs ipc --pid \$QSPID call popup open \"${STATE#popup:}\"" ;;
    theme)      DRIVE="qs ipc --pid \$QSPID call theme reload" ;;
    nc|notifications) DRIVE="qs ipc --pid \$QSPID call notifications open" ;;
    launcher|settings|dashboard|wallpaper|media|layout|keybinds|editmode)
                DRIVE="qs ipc --pid \$QSPID call $STATE open" ;;
    *) echo "unknown --state: $STATE" >&2; rm -rf "$RUN"; exit 2 ;;
  esac
fi

# Optional toast driver: a real D-Bus notification the shell's own server catches,
# so a toast appears and later self-dismisses across burst frames — no fake input.
# Short expiry (2.5s) so the toast dismisses partway through a typical burst.
NOTIFY_CMD=":"
[ "$NOTIFY" = 1 ] && NOTIFY_CMD="notify-send -t 2500 \"archeotech shot\" \"burst motion probe\""
if [ "$NOTIFY_COUNT" -gt 0 ]; then
  NOTIFY_CMD="for n in \$(seq 1 $NOTIFY_COUNT); do notify-send \"archeotech shot \$n\" \"probe \$n of $NOTIFY_COUNT\"; sleep 0.2; done"
fi

# Optional in-session command (--exec): written to a file so its quoting never
# meets the startup string below; it runs with the nested WAYLAND_DISPLAY, so
# mmsg / notify-send inside it reach only the headless session. $QSPID is the
# nested shell's pid, so it can drive state: qs ipc --pid "$QSPID" call ...
EXEC_CMD=":"
if [ -n "$EXEC" ]; then
  printf '%s\n' "$EXEC" > "$RUN/exec.sh"
  EXEC_CMD="QSPID=\$QSPID bash \"$RUN/exec.sh\" >> \"$LOG/exec.log\" 2>&1"
fi

# Capture step: single grim (atomic tmp→final) or a burst series out-NNN.png.
if [ "$BURST" -gt 1 ]; then
  CAPTURE="
  for i in \$(seq 0 $((BURST - 1))); do
    f=\"\$(printf '%s-%03d.png' \"$BASE\" \"\$i\")\"
    grim \"\$f.tmp\" && sync && mv -f \"\$f.tmp\" \"\$f\"
    sleep $INTERVAL
  done"
else
  CAPTURE="grim \"$OUT.tmp\" && sync && mv -f \"$OUT.tmp\" \"$OUT\""
fi

# Runs INSIDE the nested compositor, so it inherits the nested WAYLAND_DISPLAY and
# grim/qs-ipc/notify-send all target the headless session.
STARTUP="bash -c '
  $WP_CMD
  sleep 2
  $LAUNCH > $LOG/qs.log 2>&1 &
  QSPID=\$!
  sleep $WAIT
  $DRIVE
  sleep 1
  $NOTIFY_CMD
  $EXEC_CMD
  $CAPTURE
  touch \"$DONE\"
'"

# A burst needs the whole series to land before teardown; budget for it.
CAP_SECS=$((BURST * (INTERVAL + 1) + 5))

# Isolate the nested session behind its OWN D-Bus: the live shell already owns
# org.freedesktop.Notifications on the real session bus.
if command -v dbus-run-session >/dev/null 2>&1; then
  BUS=(dbus-run-session --)
else
  BUS=()
  [ "$NOTIFY" = 1 ] && echo "warn: no dbus-run-session; --notify may reach the live session bus" >&2
fi

# PATH without the user's own bin dirs, so nothing bypasses the stubs above.
SAFE_PATH="$FH/.local/bin:$(printf '%s' "$PATH" | tr ':' '\n' | grep -vE "^$REAL_HOME/|^$HOME/|^\$" | paste -sd:)"

# Clean environment: only what the nested session needs, pointed at the fake HOME.
ENVV=(env -i
  PATH="$SAFE_PATH" HOME="$FH" USER="$USER_NAME" LOGNAME="$USER_NAME" SHELL=/bin/bash
  LANG="${LANG:-C.UTF-8}" TERM="${TERM:-xterm-256color}"
  XDG_RUNTIME_DIR="$RT" XDG_CONFIG_HOME="$FH/.config" XDG_DATA_HOME="$FH/.local/share"
  XDG_CACHE_HOME="$FH/.cache" XDG_STATE_HOME="$FH/.local/state"
  XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS="$OUTPUTS" WLR_RENDERER="$RENDERER" WLR_LIBINPUT_NO_DEVICES=1
  QT_WAYLAND_DECORATION=none)
# --mango-libs: the nested session loads these libs first (a patched scenefx).
[ -n "$MANGO_LIBS" ] && ENVV+=(LD_LIBRARY_PATH="$MANGO_LIBS")

# Launch the nested headless compositor in its own session/process group.
setsid "${ENVV[@]}" timeout $((WAIT + CAP_SECS + 20)) "${BUS[@]}" \
  mango -c "$RUN/mango.conf" -s "$STARTUP" >"$LOG/mango.log" 2>&1 &
PGID=$!

# Wait for the sentinel to land, then tear down ONLY our nested session.
for _ in $(seq 1 $((WAIT + CAP_SECS + 15))); do
  [ -e "$DONE" ] && break
  sleep 1
done
kill -TERM -- "-$PGID" 2>/dev/null
wait "$PGID" 2>/dev/null

# Anything that escaped the group (a daemon that re-parented) still carries our
# unique private runtime dir in its environment: find it by that, kill by pid.
LEFT=()
for p in /proc/[0-9]*; do
  if grep -qzxF "XDG_RUNTIME_DIR=$RT" "$p/environ" 2>/dev/null; then
    LEFT+=("${p#/proc/}")
  fi
done
if [ "${#LEFT[@]}" -gt 0 ]; then
  kill "${LEFT[@]}" 2>/dev/null
  echo "note: reaped ${#LEFT[@]} leftover nested process(es): ${LEFT[*]}" >&2
fi

# Report what landed. Burst success = at least one frame; single = the one file.
ok=0
if [ "$BURST" -gt 1 ]; then
  shopt -s nullglob
  frames=("$BASE"-[0-9][0-9][0-9].png)
  shopt -u nullglob
  if [ "${#frames[@]}" -gt 0 ]; then
    echo "shot: ${#frames[@]} frame(s) ${frames[0]} … ${frames[-1]}"; ok=1
  fi
elif [ -s "$OUT" ]; then
  echo "shot: $OUT ($(file -b "$OUT"))"; ok=1
fi

if [ "$ok" = 1 ] && [ "$KEEP" = 0 ]; then
  rm -rf "$RUN"
else
  [ "$ok" = 1 ] || echo "FAILED — logs kept in $LOG" >&2
  [ "$KEEP" = 1 ] && echo "run dir kept: $RUN"
fi
[ "$ok" = 1 ]
