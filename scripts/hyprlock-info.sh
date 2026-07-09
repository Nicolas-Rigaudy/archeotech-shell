#!/bin/bash
################################################################################
# HYPRLOCK INFO — small string providers for hyprlock.conf cmd[update:N] labels.
# Kept as a script (not inline in hyprlock.conf) because hyprlang mangles
# $(...) / # inside label commands. Usage: hyprlock-info.sh {greeting|status}
################################################################################

case "$1" in
    greeting)
        h=$(date +%H)
        if   [ "$h" -lt 5 ];  then echo "Good night"
        elif [ "$h" -lt 12 ]; then echo "Good morning"
        elif [ "$h" -lt 18 ]; then echo "Good afternoon"
        else                       echo "Good evening"
        fi
        ;;
    status)
        # One-line status bar: user · layout · battery · uptime.
        # Layout comes from mmsg (MangoWC); omitted gracefully elsewhere.
        lay=$(mmsg -g -k 2>/dev/null | awk 'NR==1{print toupper($3)}')
        bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        up=$(uptime -p 2>/dev/null \
             | sed 's/^up //; s/ days\?,\?/d/g; s/ hours\?,\?/h/g; s/ minutes\?,\?/m/g; s/,//g')
        parts=("$USER")
        [ -n "$lay" ] && parts+=("$lay")
        [ -n "$bat" ] && parts+=("󰁹 ${bat}%")
        [ -n "$up" ]  && parts+=("󰅐 up $up")
        out=""
        for p in "${parts[@]}"; do out="${out:+$out   ·   }$p"; done
        echo "$out"
        ;;
    phrase)
        # A rotating line — re-picked on every call (each lock + each cmd update).
        phrases=(
            "Make it work, then make it right."
            "The best way out is always through."
            "Simplicity is the ultimate sophistication."
            "Done is better than perfect."
            "Focus is saying no."
            "Slow is smooth, smooth is fast."
            "First solve the problem, then write the code."
            "Read the error message."
            "Less, but better."
            "Think in systems, act in steps."
            "Perfection is the enemy of shipped."
            "Measure twice, cut once."
            "Stay curious."
            "Trust the process."
            "Small steps, every day."
            "Leave it better than you found it."
        )
        echo "${phrases[$((RANDOM % ${#phrases[@]}))]}"
        ;;
    *)
        echo ""
        ;;
esac
