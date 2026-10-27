#!/bin/bash
# readme-clips.sh: record the README animations with wf-recorder inside shot.sh's
# isolated session, then convert each clip to a GIF.
#
#   scripts/readme-clips.sh <out-dir> [name ...]   # all clips, or only the named ones
#
# Fixture data only, as in readme-shots.sh. WALLS=<dir> sets the wallpapers
# the picker lists (default: the repo's wallpapers/). Needs wf-recorder, ffmpeg and a
# readable /dev/dri render node (gles2). Writes <name>.mp4 and <name>.gif.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
OUT="$(readlink -f "${1:?usage: readme-clips.sh <out-dir> [name ...]}")"; shift
ONLY=("$@")
mkdir -p "$OUT"
# Wallpapers the picker lists: freely licensed only (default: the repo's own).
WALLS="$(readlink -f "${WALLS:-$ROOT/wallpapers}")"
FIX="$(mktemp -d -t readme-clips.XXXXXX)"
trap 'rm -rf "$FIX"' EXIT

for p in "dotfiles main 3" "homelab main 0" "notes main 5" "website dev 0" "weather-cli main 1"; do
  set -- $p
  git init -q -b "$2" "$FIX/Projects/$1"
  git -C "$FIX/Projects/$1" -c user.name=demo -c user.email=demo@example.com commit -q --allow-empty -m init
  for ((i = 0; i < $3; i++)); do echo "$i" >"$FIX/Projects/$1/f$i"; done
done

# look <theme|-> <pack|->: switch the nested shell's theme and pack live
# (writes the fake HOME's theme.json and config.json, then reloads).
cat >"$FIX/look.py" <<PY
import json, os, sys
theme, pack = sys.argv[1:3]
home = os.path.expanduser("~/.config/archeotech")
cfg = json.load(open(f"{home}/config.json"))
if theme != "-":
    t = json.load(open("$ROOT/themes/" + theme + "/theme.json"))
    t["_dir"] = f"{home}/themes/{theme}"
    json.dump(t, open(f"{home}/theme.json", "w"), indent=2)
    mode = t.get("mode", "dark")
    cfg.setdefault("theme", {})["variant"] = theme
    cs = cfg.setdefault("colorScheme", {})
    cs["mode"] = mode
    if t.get("family"): cs["family"] = t["family"]
    if t.get("flavor"): cs["flavorDark" if mode == "dark" else "flavorLight"] = t["flavor"]
if pack != "-":
    cfg.setdefault("appearance", {})["activePack"] = "" if pack == "base" else pack
json.dump(cfg, open(f"{home}/config.json", "w"), indent=2)
PY
PRELUDE="ipc() { qs ipc --pid \"\$QSPID\" call \"\$@\" >/dev/null; }
look() { python3 '$FIX/look.py' \"\$1\" \"\$2\"; ipc theme reload; }
wlrctl pointer move 5000 5000 2>/dev/null || true
PX=1919; PY=1079
glide() {  # glide X Y: move the pointer there in small steps (wlrctl moves are relative)
  local i nx ny cx=\$PX cy=\$PY
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    nx=\$((PX + (\$1 - PX) * i / 12)); ny=\$((PY + (\$2 - PY) * i / 12))
    wlrctl pointer move \$((nx - cx)) \$((ny - cy)); cx=\$nx; cy=\$ny; sleep 0.02
  done
  PX=\$1; PY=\$2
}
click() { glide \"\$1\" \"\$2\"; sleep 0.3; wlrctl pointer click left; }"

clip() {  # clip <name> <seconds> <in-session steps>
  local name="$1" secs="$2" steps="$3"
  if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " == *" $name "* ]]; then return; fi
  rm -f "$OUT/$name.mp4"
  # -i raises shot.sh's time budget to cover the recording.
  "$HERE/shot.sh" --root "$ROOT" --renderer gles2 -w 8 -i $((secs + 10)) \
    --mango-line "monitor_rule=name:HEADLESS-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1,rr:0" \
    --mango-line blur_layer=1 --mango-line blur_optimized=1 \
    --set 'appearance.glass="glass"' --set "dashboard.scanRoots=[\"$FIX/Projects\"]" \
    --wallpapers "$WALLS" --wallpaper "$ROOT/wallpapers/pexels-eberhardgross-1287145.jpg" \
    --theme archeotech-macchiato --pack base --flat 0 \
    --exec "$PRELUDE
wf-recorder -y -r 30 -c libx264 -p preset=veryfast -p crf=20 -f '$OUT/$name.mp4' >/dev/null 2>&1 &
REC=\$!
sleep 1.5
$steps
kill -INT \$REC; wait \$REC" "$OUT/$name-last.png" >/dev/null || true
  [ -s "$OUT/$name.mp4" ] || { echo "failed: $name" >&2; return; }
  ffmpeg -v error -y -i "$OUT/$name.mp4" -vf "fps=20,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" "$OUT/$name.gif"
  rm -f "$OUT/$name-last.png"
  echo "clip: $OUT/$name.gif ($(du -h "$OUT/$name.gif" | cut -f1))"
}

# One shell, two identities: the dashboard on the base pack, then Grimdark.
clip identity 14 "ipc dashboard open; sleep 3
look - grimdark; sleep 4
look - base; sleep 3"

# One theme switch, every palette, dark and light.
clip themes 16 "ipc settings open; sleep 2.5
for t in dracula nord tokyo-night gruvbox-light archeotech-latte archeotech-macchiato; do look \$t -; sleep 2; done"

# Panels in motion over the glass frame.
clip motion 16 "sleep 1
ipc launcher open; sleep 2.5; ipc launcher close; sleep 1
ipc dashboard open; sleep 2.5; ipc dashboard toggle; sleep 1
ipc wallpaper open; sleep 2.5; ipc wallpaper toggle; sleep 1
ipc media open; sleep 2.5; ipc media toggle; sleep 1"

# Wallpapers from the picker, then the logo overlay following each wallpaper.
clip wallpapers 26 "ipc wallpaper open; sleep 2
for _ in 1 2 3; do click 1208 896; sleep 0.9; click 960 896; sleep 3.2; done
glide 1919 1079; ipc wallpaper toggle; sleep 1
wallpaper-set.sh --toggle-logo arch >/dev/null 2>&1; sleep 3.5
for w in \"\$HOME\"/.config/archeotech/wallpapers/*; do
  case \"\$w\" in *lofoten*|*mandelbrot*) wallpaper-set.sh \"\$w\" >/dev/null 2>&1; sleep 3.5 ;; esac
done"
