#!/usr/bin/env bash
################################################################################
# install.sh — Deploy the Archeotech shell.
#
# The repo root IS a Quickshell config. This script wires it into place so you
# can run it with `qs -c archeotech`:
#   • symlink the repo         → ~/.config/quickshell/archeotech
#   • symlink theme packages   → ~/.config/archeotech/themes
#   • symlink logo assets      → ~/.config/archeotech/assets
#   • seed default wallpapers  → ~/.config/archeotech/wallpapers  (only if absent)
#   • symlink shell scripts    → ~/.local/bin
#
# It never overwrites an existing wallpapers dir, and re-running is safe.
#
# Usage:  ./scripts/install.sh [--dry-run]
################################################################################
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${BLUE}•${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1 && warn "DRY RUN — no changes made"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_DIR="$CONFIG/quickshell"
ARCH_DIR="$CONFIG/archeotech"
BIN_DIR="$HOME/.local/bin"

link() {  # link <target> <linkname>
    local target="$1" name="$2"
    if [[ $DRY -eq 1 ]]; then info "would link $name → $target"; return; fi
    mkdir -p "$(dirname "$name")"
    ln -sfn "$target" "$name"
    ok "$name → $target"
}

echo -e "${BLUE}Archeotech shell — install${NC}"

# ── Shell config ──────────────────────────────────────────────────────────────
if [[ -L "$QS_DIR" ]]; then
    err "$QS_DIR is a symlink; expected a directory. Resolve manually and re-run."
    exit 1
fi
link "$REPO_DIR" "$QS_DIR/archeotech"

# ── Theme packages + logo assets ────────────────────────────────────────────
[[ $DRY -eq 0 ]] && mkdir -p "$ARCH_DIR"
link "$REPO_DIR/themes"        "$ARCH_DIR/themes"
link "$REPO_DIR/scripts/assets" "$ARCH_DIR/assets"

# ── Wallpapers — seed defaults only if the user has none ──────────────────────
if [[ -e "$ARCH_DIR/wallpapers" ]]; then
    info "wallpapers dir exists — leaving your set untouched"
else
    link "$REPO_DIR/wallpapers" "$ARCH_DIR/wallpapers"
fi

# ── Shell scripts on PATH ─────────────────────────────────────────────────────
LOCAL_SCRIPTS=(
    theme-switch.sh wallpaper-set.sh
    hyprlock-launch.sh hyprlock-info.sh wlogout-launch.sh
    bt-agent.py battery-alert.sh wifi-scan.sh list-desktop-apps.sh
    zen-opacity-toggle.sh
)
for s in "${LOCAL_SCRIPTS[@]}"; do
    link "$REPO_DIR/scripts/$s" "$BIN_DIR/$s"
done

echo
ok "Done."
echo
echo "Next steps:"
echo "  1. Add the required compositor rules + keybinds — see examples/ and"
echo "     docs/MANGOWC-SETUP.md (blur_layer=0, the shell layer rules, and"
echo "     'qs -c archeotech' launch + IPC binds)."
echo "  2. Launch:  qs -c archeotech"
echo "  3. Ensure ~/.local/bin is on your PATH."
