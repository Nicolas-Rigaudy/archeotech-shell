#!/bin/bash
# wlogout-launch.sh — full-span overlay, adaptive layout per monitor.

LAYOUT="$HOME/.config/wlogout/layout"
CSS="$HOME/.config/wlogout/style.css"

BTN_SIZE=160   # target button size (square)
H_MARGIN=200   # fixed horizontal margin each side

# ── Focused monitor ───────────────────────────────────────────────────────────
FOCUSED=$(mmsg -g -o 2>/dev/null | awk '/selmon 1/{print $1; exit}')
[ -z "$FOCUSED" ] && FOCUSED="eDP-1"

# ── Monitor and canvas geometry ───────────────────────────────────────────────
XRANDR=$(xrandr 2>/dev/null)
GEOM=$(echo "$XRANDR" | grep "^${FOCUSED} connected" | grep -oP '\d+x\d+\+\d+\+\d+' | head -1)
MON_W=$(echo "$GEOM" | awk -F'[x+]' '{print $1}')
MON_H=$(echo "$GEOM" | awk -F'[x+]' '{print $2}')
CANVAS_H=$(echo "$XRANDR" | grep -oP '\d+x\d+\+\d+\+\d+' | awk -F'[x+]' \
    '{h=$2+$4; if(h>max) max=h} END{print max}')

[ -z "$MON_W" ]    && MON_W=1920
[ -z "$MON_H" ]    && MON_H=1080
[ -z "$CANVAS_H" ] && CANVAS_H=1080

# ── Portrait monitor: reduce horizontal margins so 5 buttons fit ──────────────
if [ "$MON_W" -lt "$MON_H" ]; then
    H_MARGIN=20
fi
BTNS_PER_ROW=5
POPUP_H=$(( BTN_SIZE + 16 ))

# ── Vertical margins to center popup on focused monitor ───────────────────────
MARGIN_T=$(( (MON_H - POPUP_H) / 2 ))
MARGIN_B=$(( CANVAS_H - MARGIN_T - POPUP_H ))

[ "$MARGIN_T" -lt 0 ] && MARGIN_T=0
[ "$MARGIN_B" -lt 0 ] && MARGIN_B=0

# ── Launch ────────────────────────────────────────────────────────────────────
exec wlogout \
    --layout          "$LAYOUT" \
    --css             "$CSS" \
    --buttons-per-row "$BTNS_PER_ROW" \
    --column-spacing  12 \
    --row-spacing     12 \
    --margin-left     "$H_MARGIN" \
    --margin-right    "$H_MARGIN" \
    --margin-top      "$MARGIN_T" \
    --margin-bottom   "$MARGIN_B"
