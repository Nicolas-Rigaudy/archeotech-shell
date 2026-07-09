#!/usr/bin/env bash
# theme-switch.sh — Thin bash entrypoint for the Python theme switcher.
# Usage: theme-switch.sh <variant> [variant ...]
# Example: theme-switch.sh archeotech-macchiato
set -euo pipefail
exec python3 "$(dirname "$(realpath "$0")")/theme-switch.py" "$@"
