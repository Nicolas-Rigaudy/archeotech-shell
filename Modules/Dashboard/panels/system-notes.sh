#!/bin/bash
# system-notes.sh <stat-id> — one System Notes value on stdout (SystemNotes.qml).
# Prints __NA__ when the stat's source does not exist on this machine (the card
# then hides the row instead of showing a fake value) and __ERR__ when the source
# exists but the check failed this time. Each stat runs in its own process, so a
# slow one (updates) never holds back the others.
set -u

case "${1:-}" in
  snapshot)
    command -v snapper >/dev/null 2>&1 || { echo __NA__; exit 0; }
    # CSV, not the box-drawing table: no column-position guessing. Fails (no
    # root config, or the user is not in ALLOW_USERS) → the stat is unavailable.
    snapper --csvout -c root list --columns number,date 2>/dev/null || echo __NA__
    ;;
  uptime)
    awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60);
          if(d>0)printf "%dd %dh\n",d,h; else if(h>0)printf "%dh %dm\n",h,m; else printf "%dm\n",m}' /proc/uptime
    ;;
  updates)
    command -v pacman >/dev/null 2>&1 || { echo __NA__; exit 0; }
    # checkupdates syncs a temp DB over the network, so cache the counts for 30
    # min; a pacman transaction since then (local DB newer) invalidates it.
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/archeotech/updates"
    if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt 1800 ] \
       && ! [ /var/lib/pacman/local -nt "$cache" ]; then
      cat "$cache"; exit 0
    fi
    if command -v checkupdates >/dev/null 2>&1; then
      out=$(checkupdates 2>/dev/null); rc=$?
      # 0 = updates listed, 2 = none, anything else = the check itself failed
      # (offline, lock): report that instead of a false "up to date".
      [ "$rc" = 0 ] || [ "$rc" = 2 ] || { echo __ERR__; exit 0; }
      repo=$(printf '%s' "$out" | grep -c .)
    else
      repo=$(pacman -Qu 2>/dev/null | grep -c .)
    fi
    aur=0
    command -v paru >/dev/null 2>&1 && aur=$(paru -Qua 2>/dev/null | grep -c .)
    echo "$repo $aur"
    # Atomic: a fetch killed mid-write never leaves a truncated cache behind.
    mkdir -p "${cache%/*}" 2>/dev/null \
      && echo "$repo $aur" > "$cache.tmp.$$" 2>/dev/null && mv -f "$cache.tmp.$$" "$cache"
    ;;
  kernel) uname -r ;;
  host)   cat /etc/hostname 2>/dev/null || hostname ;;
  ip)
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}'
    ;;
  vpn)
    command -v nmcli >/dev/null 2>&1 || { echo __NA__; exit 0; }
    nmcli -t -f NAME,TYPE con show --active 2>/dev/null
    ;;
  aws)
    cfg="$HOME/.aws/config"
    [ -f "$cfg" ] || { echo __NA__; exit 0; }
    # The shell's own $AWS_PROFILE is meaningless (set per terminal): read what a
    # NEW login shell gets, else the CLI's own fallback, [default].
    p=''
    command -v fish >/dev/null 2>&1 && p=$(timeout 1 fish -c 'printf %s "$AWS_PROFILE"' 2>/dev/null)
    [ -z "$p" ] && grep -qxF '[default]' "$cfg" && p=default
    if [ -n "$p" ] && [ "$p" != default ] && ! grep -qxF "[profile $p]" "$cfg"; then
      p="$p (not in config)"
    fi
    echo "${p:-none}"
    ;;
  *) echo "usage: system-notes.sh snapshot|uptime|updates|kernel|host|ip|vpn|aws" >&2; exit 2 ;;
esac
