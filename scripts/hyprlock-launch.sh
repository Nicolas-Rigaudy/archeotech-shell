#!/bin/bash
################################################################################
# HYPRLOCK LAUNCH SCRIPT
# Locks the screen with hyprlock. The wallpaper comes from hyprlock.conf's
# background path (~/.cache/wallpaper/current, a symlink maintained by
# wallpaper-set.sh), so no --image flag is needed.
#
# Replaced swaylock-launch.sh (2026-07-08): hyprlock is a separately-maintained
# codebase that fixes the sway-lineage resume segfault and restores blur.
################################################################################

# Don't stack lockers — a second hyprlock on an already-locked session is a
# no-op at best, confusing at worst.
if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Trigger label passed by the caller (swayidle passes "idle-timeout" /
# "before-sleep"; the Super+L keybind passes nothing → "keybind").
TRIGGER="${1:-keybind}"

# ── Trigger diagnostics ───────────────────────────────────────────────────────
# Records who/why on every lock so a "random" lock is diagnosable from one
# occurrence. Read with: cat ~/.cache/hyprlock-trigger.log
# (Ported from swaylock-launch.sh; kept through the hyprlock resume/dock
# verification window. Backgrounded (&) so it never delays the lock.)
{
    echo "── $(date '+%Y-%m-%d %H:%M:%S') ──"
    echo "trigger: $TRIGGER"
    echo "caller chain (pid/ppid/cmd, walking up from this script):"
    pid=$PPID
    for _ in 1 2 3 4 5; do
        [[ "$pid" -le 1 ]] && break
        read -r ppid comm < <(ps -o ppid=,comm= -p "$pid" 2>/dev/null)
        printf '  %s\t%s\n' "$pid" "$comm"
        pid=$ppid
    done
    bat="/sys/class/power_supply/BAT0"
    echo "battery: $(cat "$bat/status" 2>/dev/null) $(cat "$bat/capacity" 2>/dev/null)%"
    for lid in /proc/acpi/button/lid/*/state; do
        [[ -r "$lid" ]] && echo "lid: $(cat "$lid")"
    done
    susp=$(journalctl -b --since "-2 min" 2>/dev/null \
        | grep -iE "PrepareForSleep|Suspending system|Reached target.*[Ss]leep" | tail -1)
    echo "recent-suspend: ${susp:-none}"
} >> "$HOME/.cache/hyprlock-trigger.log" 2>&1 &

exec hyprlock
