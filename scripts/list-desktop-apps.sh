#!/bin/bash
# List installed applications from .desktop files.
# Output: tab-separated fields: name, exec, icon, genericName, terminal

for dir in /usr/share/applications /usr/local/share/applications "$HOME/.local/share/applications"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue
        grep -q '^NoDisplay=true' "$f" && continue
        grep -q '^Type=Application' "$f" || continue
        name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
        exec=$(grep -m1 '^Exec=' "$f" | cut -d= -f2- | sed 's/ *%[uUfFdDnNickvm]//g')
        icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
        generic=$(grep -m1 '^GenericName=' "$f" | cut -d= -f2-)
        terminal=$(grep -m1 '^Terminal=' "$f" | cut -d= -f2-)
        [ -z "$name" ] && continue
        [ -z "$exec" ] && continue
        printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$exec" "$icon" "$generic" "${terminal:-false}"
    done
done | sort -t$'\t' -k1,1 | awk -F'\t' '!seen[$1]++'
