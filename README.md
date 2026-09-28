# Archeotech

A fully composable, community-extensible [Quickshell](https://quickshell.org) desktop shell for Wayland — targeting **MangoWC** (primary), with Hyprland support. Every panel, widget, and bar element is a self-describing module; themes are pure JSON + assets; layout is drag-and-drop editable and hot-reloads live.

> **Status:** pre-1.0. APIs are stabilising toward a v1.0 release.

## Highlights

- **Module system** — drop a folder into `modules/` to install a widget or panel.
- **Theme system** — family → flavor → accent, hot-reloading across the shell and external apps (kitty, rofi, GTK, and more). Themes are self-contained packages under `themes/`.
- **Visual builder** — an edit mode wires any module to any trigger (bar zone, strip icon, edge hover, keybind); config persists and hot-reloads.
- **One coherent process** — bar, panels, launcher, notifications, OSD, dashboard, settings — all native Quickshell.

## Install

Requires [Quickshell](https://quickshell.org) (0.3.0+) and a wlroots-based Wayland compositor (MangoWC recommended).

```sh
git clone https://github.com/Nicolas-Rigaudy/archeotech-shell.git
cd archeotech-shell
./scripts/install.sh          # or --dry-run first
qs -c archeotech
```

The installer symlinks the repo to `~/.config/quickshell/archeotech`, deploys theme
packages + logo assets to `~/.config/archeotech/`, seeds two default wallpapers (only
if you have none), and puts the shell scripts on your `PATH`. It never touches an
existing wallpaper set.

Your compositor needs a few required rules and the launch/IPC keybinds — see
[`examples/`](examples/) and [`docs/MANGOWC-SETUP.md`](docs/MANGOWC-SETUP.md).

## Docs

- [`docs/MODULE_API.md`](docs/MODULE_API.md) — write a module (widget or panel)
- [`docs/WIDGET_API.md`](docs/WIDGET_API.md) — the widget contract
- [`docs/PANEL_API.md`](docs/PANEL_API.md) — the panel contract
- [`docs/THEME_SPEC.md`](docs/THEME_SPEC.md) — theme package format + applier mechanics

## License

[GPL-3.0](LICENSE) (`GPL-3.0-only`). Add-on theme packs and plugins that live in their own repositories may use their own license.
