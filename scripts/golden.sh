#!/bin/bash
################################################################################
# golden.sh — visual regression: render a fixed scenario matrix with shot.sh and
# diff each frame against its committed golden in tests/golden/.
#
#   scripts/golden.sh                     # render + compare every scenario
#   scripts/golden.sh --only 'launcher-*' # a subset (shell glob on the name)
#   scripts/golden.sh --update            # (re)write goldens from this tree
#   scripts/golden.sh --root ../wt/x      # test another checkout / worktree
#   scripts/golden.sh --jobs 3            # parallel renders (default 2)
#
# Inputs are frozen so a render is repeatable: --fresh (default shell config, no
# user state), the committed fixture wallpaper, and fixed theme/pack/flat per
# scenario. What still varies between runs (clock, battery %, CPU stats, the
# installed-apps list, rotating tips) is masked per scenario in
# tests/golden/masks.txt; masked pixels are painted black in BOTH images before
# comparing. A scenario fails when more than THRESHOLD pixels differ beyond FUZZ
# per channel; its diff image lands in the run dir.
#
# Goldens are machine-bound for now (fonts, icon theme, installed apps render
# from this machine), so regenerate them here with --update after an intended
# visual change and commit them with that change.
#
# The token contrast report (scripts/contrast-check.py) runs at the end; it is
# informational until the design-system contrast floor lands.
################################################################################
set -u

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT=""
ONLY="*"
UPDATE=0
JOBS=2
FUZZ="${FUZZ:-3%}"
THRESHOLD="${THRESHOLD:-40}"   # masked runs measure 0 px; a 3-word text change is 150-320

while [ $# -gt 0 ]; do
  case "$1" in
    --root)   ROOT="$2"; shift 2 ;;
    --only)   ONLY="$2"; shift 2 ;;
    --update) UPDATE=1; shift ;;
    --jobs)   JOBS="$2"; shift 2 ;;
    -h|--help) sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
ROOT="$(cd "${ROOT:-$HERE/..}" && pwd)" || { echo "bad --root" >&2; exit 2; }
GOLD="$HERE/../tests/golden"            # goldens always come from THIS checkout
WALL="$GOLD/fixture-wallpaper.png"
MASKS="$GOLD/masks.txt"
[ -f "$WALL" ] || { echo "missing $WALL" >&2; exit 2; }
command -v magick >/dev/null || { echo "needs ImageMagick (magick)" >&2; exit 2; }

# name | --state | theme dir | flat | pack
SCENARIOS=(
  "bar-dark||archeotech-macchiato|0|base"
  "bar-light||archeotech-latte|0|base"
  "bar-flat||archeotech-macchiato|1|base"
)
for st in dashboard launcher media wallpaper settings:appearance notifications editmode; do
  n="${st%%:*}"
  SCENARIOS+=("$n-dark|$st|archeotech-macchiato|0|base"
              "$n-light|$st|archeotech-latte|0|base"
              "$n-flat|$st|archeotech-macchiato|1|base")
done
SCENARIOS+=("dashboard-grimdark|dashboard|archeotech-macchiato|0|grimdark")

RUN="$(mktemp -d "${TMPDIR:-/tmp}/archeotech-golden.XXXXXX")"
mkdir -p "$RUN/out" "$RUN/diff"

render() {  # $1 = scenario spec → $RUN/out/<name>.png
  IFS='|' read -r name state theme flat pack <<<"$1"
  local args=(--root "$ROOT" --fresh --wallpaper "$WALL" --theme "$theme" --flat "$flat" --pack "$pack")
  [ -n "$state" ] && args+=(--state "$state")
  "$HERE/shot.sh" "${args[@]}" "$RUN/out/$name.png" >"$RUN/out/$name.log" 2>&1 \
    || echo "render failed: $name (see $RUN/out/$name.log)" >&2
}

# Paint this scenario's masked rectangles black: $1 in, $2 out, $3 name.
masked() {
  local draw=()
  if [ -f "$MASKS" ]; then
    while read -r glob p0 p1 _; do          # "<name-glob> x0,y0 x1,y1"
      [ -n "$glob" ] && [ -n "$p1" ] || continue
      # shellcheck disable=SC2254  # glob match on purpose
      case "$3" in $glob) draw+=(-draw "rectangle $p0 $p1") ;; esac
    done < <(sed 's/#.*//' "$MASKS")
  fi
  magick "$1" -fill black "${draw[@]}" "$2"
}

selected=()
for s in "${SCENARIOS[@]}"; do
  # shellcheck disable=SC2254
  case "${s%%|*}" in $ONLY) selected+=("$s") ;; esac
done
[ ${#selected[@]} -gt 0 ] || { echo "no scenario matches: $ONLY" >&2; exit 2; }

echo "golden: rendering ${#selected[@]} scenario(s) from $ROOT ($JOBS at a time)"
running=0
for s in "${selected[@]}"; do
  render "$s" &
  running=$((running + 1))
  if [ "$running" -ge "$JOBS" ]; then wait -n; running=$((running - 1)); fi
done
wait

fail=0
for s in "${selected[@]}"; do
  name="${s%%|*}"
  out="$RUN/out/$name.png"
  if [ ! -s "$out" ]; then echo "FAIL  $name  (no render)"; fail=1; continue; fi
  if [ "$UPDATE" = 1 ]; then
    cp "$out" "$GOLD/$name.png"; echo "wrote $name"; continue
  fi
  if [ ! -f "$GOLD/$name.png" ]; then echo "NEW   $name  (no golden; run --update)"; fail=1; continue; fi
  masked "$GOLD/$name.png" "$RUN/diff/$name.gold.png" "$name"
  masked "$out" "$RUN/diff/$name.new.png" "$name"
  # compare prints the AE metric on stderr and exits 0 (same) / 1 (differ) /
  # 2 (error). An error must never read as "0 px": check the status first, and
  # accept only a plain number as the metric.
  cmp_out=$(magick compare -metric AE -fuzz "$FUZZ" "$RUN/diff/$name.gold.png" "$RUN/diff/$name.new.png" \
              "$RUN/diff/$name.diff.png" 2>&1 >/dev/null); cmp_rc=$?
  px=$(printf '%s' "$cmp_out" | head -1 | awk '{print $1}')
  if [ "$cmp_rc" -gt 1 ] || ! [[ "$px" =~ ^[0-9]+(\.[0-9]+)?(e\+?[0-9]+)?$ ]]; then
    echo "ERROR $name  (magick compare failed, rc=$cmp_rc: ${cmp_out%%$'\n'*})"; fail=1; continue
  fi
  px=$(awk -v v="$px" 'BEGIN { printf "%d", v }')
  if [ "$px" -gt "$THRESHOLD" ]; then
    echo "FAIL  $name  ($px px differ > $THRESHOLD; diff: $RUN/diff/$name.diff.png)"; fail=1
  else
    echo "ok    $name  ($px px)"
    rm -f "$RUN/diff/$name".*
  fi
done

echo
python3 "$HERE/contrast-check.py" --themes "$ROOT/themes" || true

if [ "$fail" = 0 ] && [ "$UPDATE" = 0 ]; then rm -rf "$RUN"; else echo "run dir: $RUN"; fi
exit $fail
