#!/bin/bash
################################################################################
# shot.sh — headless screenshot of the archeotech shell (or one QML component).
#
# Runs a NESTED headless wlroots compositor (mango), launches the shell inside
# it, waits for it to settle, optionally drives a named shell state via `qs ipc`
# (no synthetic input), then grabs a PNG — or a BURST of PNGs — with grim. Lets a
# tool or CI *see* a visual (or motion) change with no physical display attached.
#
#   shot.sh [out.png]                        # full shell (qs -c archeotech)
#   shot.sh --qml Widgets/Bar/Foo.qml [out]  # one component in isolation
#   shot.sh -w 10 out.png                    # longer settle wait (default 8s)
#   shot.sh --state launcher out.png         # open the launcher, then capture
#   shot.sh --state settings:appearance out  # open settings on a named pane
#   shot.sh --notify --burst 6 -i 1 out.png  # fire a toast, capture 6 frames 1s
#                                            #   apart → out-000.png … out-005.png
#
# STATE-DRIVING (--state <name>): before capture, calls the shell's own IPC
# handler to open a panel — launcher | settings[:pane] | dashboard | wallpaper |
# media | layout | notifications | editmode | theme(reload). Runs INSIDE the
# nested session, so it drives the nested shell, never your real one.
#
# BURST (--burst N [-i SECS]): captures N frames spaced SECS apart into
# out-000.png … out-(N-1).png instead of a single file. Combine with --notify to
# confirm a motion state changed (a toast appears in early frames, gone later).
#
# SAFETY: this NEVER kills processes by name. It launches the nested compositor
# in the background, remembers ITS pid, and tears down only that pid. `pkill -x
# mango` / `pkill quickshell` would match your REAL session compositor+shell and
# log you out — so they are deliberately not used here. Likewise every `qs ipc`
# and `notify-send` runs inside the nested WAYLAND_DISPLAY.
#
# Requires: mango, qs (quickshell), grim, wlroots headless backend. 1280x720.
# --notify additionally requires notify-send.
################################################################################
set -u

WAIT=8              # ponytail: fixed settle wait; poll shot for non-blank if flaky
QML=""
OUT=""
STATE=""            # panel to drive open via qs ipc before capture (empty = none)
BURST=1             # frames to capture (1 = single shot); >1 → out-NNN.png series
INTERVAL=1          # seconds between burst frames
NOTIFY=0            # 1 → fire a demo notification to exercise the toast pipeline

while [ $# -gt 0 ]; do
  case "$1" in
    --qml)      QML="$2"; shift 2 ;;
    -w)         WAIT="$2"; shift 2 ;;
    --state)    STATE="$2"; shift 2 ;;
    --burst)    BURST="$2"; shift 2 ;;
    -i|--interval) INTERVAL="$2"; shift 2 ;;
    --notify)   NOTIFY=1; shift ;;
    -*)         echo "unknown flag: $1" >&2; exit 2 ;;
    *)          OUT="$1"; shift ;;
  esac
done
OUT="${OUT:-/tmp/archeotech-shot.png}"
DONE="$OUT.done"        # sentinel the inner script touches when it has finished;
                       # the teardown loop waits on THIS, so burst (many files,
                       # no single "$OUT") is observed as reliably as a single shot.
rm -f "$OUT" "$OUT.tmp" "$DONE"
# Clear any stale burst frames from a previous run of the same prefix.
BASE="${OUT%.png}"
rm -f "$BASE"-[0-9][0-9][0-9].png 2>/dev/null

if [ -n "$QML" ]; then
  LAUNCH="qs -p '$QML'"
else
  LAUNCH="qs -c archeotech"
fi

# Build the state-driving step (runs inside the nested session). --state settings
# accepts a "settings:pane" form that maps onto the openPane(pane) IPC function.
#
# SAFETY: the ipc call selects the instance by the NESTED qs pid (\$QSPID, set in
# the inner script), never by `-c archeotech` config name. The live session runs
# the SAME config and shares this $XDG_RUNTIME_DIR, so a config-name selection
# could drive the user's REAL bar. Pid selection can only ever hit our own shell.
DRIVE=":"   # no-op by default
if [ -n "$STATE" ]; then
  case "$STATE" in
    settings:*) DRIVE="qs ipc --pid \$QSPID call settings openPane \"${STATE#settings:}\"" ;;
    theme)      DRIVE="qs ipc --pid \$QSPID call theme reload" ;;
    nc|notifications) DRIVE="qs ipc --pid \$QSPID call notifications open" ;;
    launcher|settings|dashboard|wallpaper|media|layout|editmode)
                DRIVE="qs ipc --pid \$QSPID call $STATE open" ;;
    *) echo "unknown --state: $STATE" >&2; exit 2 ;;
  esac
fi

# Optional toast driver: a real D-Bus notification the shell's own server catches,
# so a toast appears and later self-dismisses across burst frames — no fake input.
NOTIFY_CMD=":"
# Short expiry (2.5s) so the toast dismisses partway through a typical burst,
# giving frames that show it present AND later gone — the motion AC3 asks for.
[ "$NOTIFY" = 1 ] && NOTIFY_CMD="notify-send -t 2500 \"archeotech shot\" \"burst motion probe\""

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
# grim/qs-ipc/notify-send all target the headless session — never your real one.
# QSPID is the nested shell's pid, used to address ipc at OUR instance only. No
# kills here: when we terminate the nested mango below, this qs child dies too.
STARTUP="bash -c '
  sleep 2
  $LAUNCH > /tmp/archeotech-shot-qs.log 2>&1 &
  QSPID=\$!
  sleep $WAIT
  $DRIVE
  sleep 1
  $NOTIFY_CMD
  $CAPTURE
  touch \"$DONE\"
'"

# A burst needs the whole series to land before teardown; budget for it.
CAP_SECS=$((BURST * (INTERVAL + 1) + 5))

# Isolate the nested session behind its OWN D-Bus when possible: the live shell
# already owns org.freedesktop.Notifications on the real session bus, so without
# this a --notify probe would toast the USER'S bar and the nested server would
# get nothing. A fresh bus keeps notifications (and any other bus traffic) inside
# the headless session. Degrade gracefully if dbus-run-session is unavailable.
if command -v dbus-run-session >/dev/null 2>&1; then
  BUS=(dbus-run-session --)
else
  BUS=()
  [ "$NOTIFY" = 1 ] && echo "warn: no dbus-run-session; --notify may leak to the live session" >&2
fi

# Launch the nested headless compositor in the background; remember ITS pid.
WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDERER=pixman \
  timeout $((WAIT + CAP_SECS + 20)) "${BUS[@]}" mango -s "$STARTUP" >/tmp/archeotech-shot-mango.log 2>&1 &
MANGO_PID=$!

# Wait for the sentinel to land, then tear down ONLY our nested compositor.
for _ in $(seq 1 $((WAIT + CAP_SECS + 15))); do
  [ -e "$DONE" ] && break
  sleep 1
done
kill "$MANGO_PID" 2>/dev/null   # SIGTERM to our timeout→mango only, by pid
wait "$MANGO_PID" 2>/dev/null

# Report what landed. Burst success = at least one frame; single = the one file.
if [ "$BURST" -gt 1 ]; then
  shopt -s nullglob
  frames=("$BASE"-[0-9][0-9][0-9].png)
  shopt -u nullglob
  if [ "${#frames[@]}" -gt 0 ]; then
    echo "shot: ${#frames[@]} frame(s) ${frames[0]} … ${frames[-1]}"
  else
    echo "FAILED — see /tmp/archeotech-shot-{mango,qs}.log" >&2
    exit 1
  fi
elif [ -s "$OUT" ]; then
  echo "shot: $OUT ($(file -b "$OUT"))"
else
  echo "FAILED — see /tmp/archeotech-shot-{mango,qs}.log" >&2
  exit 1
fi
