#!/bin/bash
# readme-shots.sh: render the README screenshots with shot.sh (isolated, GPU blur).
#
#   scripts/readme-shots.sh <out-dir> [name ...]   # all shots, or only the named ones
#
# Fixture data only: the dashboard scans a temp dir of demo git repos and
# the wallpaper is one of the repo's own. Needs a readable /dev/dri
# render node (gles2). Compress the results before committing:
#   magick in.png -colors 128 PNG8:docs/img/<name>.png
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
OUT="$(readlink -f "${1:?usage: readme-shots.sh <out-dir> [name ...]}")"; shift
ONLY=("$@")
mkdir -p "$OUT"
FIX="$(mktemp -d -t readme-shots.XXXXXX)"
trap 'rm -rf "$FIX"' EXIT

# Demo projects for the dashboard: name, branch, uncommitted files.
for p in "dotfiles main 3" "homelab main 0" "notes main 5" "website dev 0" "weather-cli main 1"; do
  set -- $p
  git init -q -b "$2" "$FIX/Projects/$1"
  git -C "$FIX/Projects/$1" -c user.name=demo -c user.email=demo@example.com commit -q --allow-empty -m init
  for ((i = 0; i < $3; i++)); do echo "$i" >"$FIX/Projects/$1/f$i"; done
done

WALL="$(readlink -f "${WALL:-$ROOT/wallpapers/pexels-eberhardgross-1287145.jpg}")"
# Wallpapers the picker lists: freely licensed only (default: the repo's own).
WALLS="$(readlink -f "${WALLS:-$ROOT/wallpapers}")"

shot() {  # shot <name> <shot.sh args...>
  local name="$1"; shift
  if [ ${#ONLY[@]} -gt 0 ] && [[ ! " ${ONLY[*]} " == *" $name "* ]]; then return; fi
  "$HERE/shot.sh" --root "$ROOT" --renderer gles2 -w 8 \
    --mango-line "monitor_rule=name:HEADLESS-1,width:1920,height:1080,refresh:60,x:0,y:0,scale:1,rr:0" \
    --mango-line blur_layer=1 --mango-line blur_optimized=1 \
    --set 'appearance.glass="glass"' --set "dashboard.scanRoots=[\"$FIX/Projects\"]" \
    --set 'dashboard.notes=["snapshot","uptime","updates","kernel","host"]' \
    --wallpapers "$WALLS" --wallpaper "$WALL" --theme archeotech-macchiato --pack base --flat 0 \
    "$@" "$OUT/$name.png" | grep '^shot:' || echo "failed: $name" >&2
}

shot dashboard      --state dashboard -w 20   # long enough for the update count to load
shot launcher       --state launcher
shot settings       --state settings:appearance
shot settings-light --state settings:appearance --theme archeotech-latte
shot editmode       --state editmode --fresh
shot keyboard       --state keybinds
shot wallpaper      --state wallpaper
for t in dracula gruvbox-light nord tokyo-night archeotech-latte; do
  shot "theme-$t"   --state dashboard --theme "$t"
done
