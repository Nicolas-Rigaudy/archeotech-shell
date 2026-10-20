#!/usr/bin/env bash
# zen-opacity-toggle.sh — flip Zen browser between translucent (glass) and
# opaque (best readability for screen-share / presenting).
#
# MangoWC has no runtime opacity command, so this rewrites the per-window
# opacity window rule for app_id:zen in mango/config.conf and live-reloads.
# --follow-symlinks keeps the stow symlink intact (edits the repo file).
# The rule keeps the config's key names: windowrule/appid up to mango 0.17,
# window_rule/app_id from 0.18.
#
# Bound to SUPER+SHIFT+O. Run with no args to toggle, or `opaque`/`glass` to
# force a state (handy for scripted presentation modes).

set -euo pipefail

CONF="$HOME/.config/mango/config.conf"
GLASS_FOCUSED=0.88
GLASS_UNFOCUSED=0.75
RULE_RE='^(window_?rule)=focused_opacity:[0-9.]*,unfocused_opacity:[0-9.]*,(app_?id):zen'

command -v mmsg >/dev/null 2>&1 || { echo "mmsg not found"; exit 1; }
[ -f "$CONF" ] || { echo "mango config not found: $CONF"; exit 1; }

# Current state: opaque if the focused value is exactly 1.0.
if grep -qE '^window_?rule=focused_opacity:1(\.0+)?,.*app_?id:zen' "$CONF"; then
    current="opaque"
else
    current="glass"
fi

# Decide target: explicit arg wins, else toggle.
case "${1:-toggle}" in
    opaque) target="opaque" ;;
    glass)  target="glass" ;;
    *)      [ "$current" = "opaque" ] && target="glass" || target="opaque" ;;
esac

if [ "$target" = "opaque" ]; then
    new="\1=focused_opacity:1.0,unfocused_opacity:1.0,\2:zen"
    label="opaque (presentation)"
else
    new="\1=focused_opacity:${GLASS_FOCUSED},unfocused_opacity:${GLASS_UNFOCUSED},\2:zen"
    label="translucent (glass)"
fi

sed --follow-symlinks -i -E "s|${RULE_RE}.*|${new}|" "$CONF"
mmsg -s -d reload_config

notify-send -a "Zen" "Zen opacity" "Now $label" 2>/dev/null || true
echo "Zen → $label"
