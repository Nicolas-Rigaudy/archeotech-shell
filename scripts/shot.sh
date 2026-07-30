#!/bin/bash
################################################################################
# shot.sh — headless screenshot of the archeotech shell (or one QML component).
#
# Runs a NESTED headless wlroots compositor (mango), launches the shell inside
# it, waits for it to settle, then grabs a PNG with grim. Lets a tool or CI
# *see* a visual change with no physical display attached.
#
#   shot.sh [out.png]                       # full shell (qs -c archeotech)
#   shot.sh --qml Widgets/Bar/Foo.qml [out] # one component in isolation
#   shot.sh -w 10 out.png                   # longer settle wait (default 8s)
#
# SAFETY: this NEVER kills processes by name. It launches the nested compositor
# in the background, remembers ITS pid, and tears down only that pid. `pkill -x
# mango` / `pkill quickshell` would match your REAL session compositor+shell and
# log you out — so they are deliberately not used here.
#
# Requires: mango, qs (quickshell), grim, wlroots headless backend. 1280x720.
################################################################################
set -u

WAIT=8              # ponytail: fixed settle wait; poll shot for non-blank if flaky
QML=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --qml) QML="$2"; shift 2 ;;
    -w)    WAIT="$2"; shift 2 ;;
    -*)    echo "unknown flag: $1" >&2; exit 2 ;;
    *)     OUT="$1"; shift ;;
  esac
done
OUT="${OUT:-/tmp/archeotech-shot.png}"
rm -f "$OUT"

if [ -n "$QML" ]; then
  LAUNCH="qs -p '$QML'"
else
  LAUNCH="qs -c archeotech"
fi

# Runs INSIDE the nested compositor, so it inherits the nested WAYLAND_DISPLAY
# and grim grabs the headless output — never your real screen. No kills here:
# when we terminate the nested mango below, this qs child dies with it.
STARTUP="bash -c '
  sleep 2
  $LAUNCH > /tmp/archeotech-shot-qs.log 2>&1 &
  sleep $WAIT
  grim \"$OUT\"
'"

# Launch the nested headless compositor in the background; remember ITS pid.
WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDERER=pixman \
  timeout $((WAIT + 20)) mango -s "$STARTUP" >/tmp/archeotech-shot-mango.log 2>&1 &
MANGO_PID=$!

# Wait for the screenshot to land, then tear down ONLY our nested compositor.
for _ in $(seq 1 $((WAIT + 15))); do
  [ -s "$OUT" ] && break
  sleep 1
done
kill "$MANGO_PID" 2>/dev/null   # SIGTERM to our timeout→mango only, by pid
wait "$MANGO_PID" 2>/dev/null

if [ -s "$OUT" ]; then
  echo "shot: $OUT ($(file -b "$OUT"))"
else
  echo "FAILED — see /tmp/archeotech-shot-{mango,qs}.log" >&2
  exit 1
fi
