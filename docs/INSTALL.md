# Installing Archeotech

## Requirements

- **[Quickshell](https://quickshell.org)** 0.3.0+
- A **wlroots-based Wayland compositor** — **MangoWC** is the primary target; Hyprland works.
- **Fonts:** a Nerd Font (for glyphs) and a sans family; the theme system also drives kitty colors if kitty is installed.
- **Common tools** used by shell features (install what you use): `wl-clipboard`, `brightnessctl`, `wpctl`/`pipewire`, `NetworkManager`, `bluez` + `bluez-utils`, `wlr-randr`, `awww`/`swww` (wallpaper), `hyprlock` (lock), `wlogout` (power menu), `rsvg-convert` + `imagemagick` (wallpaper/logo compositing).

## 1. Install the shell

```sh
git clone https://github.com/Nicolas-Rigaudy/archeotech-shell.git ~/Projects/archeotech-shell
cd ~/Projects/archeotech-shell
./scripts/install.sh --dry-run   # preview
./scripts/install.sh
```

The installer:
- symlinks the repo → `~/.config/quickshell/archeotech`
- symlinks theme packages → `~/.config/archeotech/themes` and logo assets → `~/.config/archeotech/assets`
- seeds two default wallpapers → `~/.config/archeotech/wallpapers` **only if you have none** (drop your own images in that folder anytime)
- symlinks shell scripts → `~/.local/bin`

Make sure `~/.local/bin` is on your `PATH`.

## 2. Wire up your compositor

Copy the required rules and keybinds from [`examples/`](../examples/):
- MangoWC → [`examples/mangowc.conf.example`](../examples/mangowc.conf.example)
- Hyprland → [`examples/hyprland.conf.example`](../examples/hyprland.conf.example)

The load-bearing bits: `blur_layer=0`, a **single** `quickshell -c archeotech` launcher, and the `qs -c archeotech ipc call …` panel keybinds. See [`MANGOWC-SETUP.md`](MANGOWC-SETUP.md) for a fuller MangoWC walkthrough.

## 3. Launch

```sh
qs -c archeotech
```

(Your compositor's `exec-once` will start it automatically once you've added the launch line.)

## Theming

Switch themes from **Settings → Appearance**, or from the CLI:

```sh
theme-switch.sh archeotech-macchiato
```

Themes are self-contained packages under `themes/<variant>/` (a `theme.json` palette + a `kitty.conf`). The switcher applies colors across the shell and any installed external apps (kitty, rofi, GTK, …); appliers skip gracefully when a target app isn't installed. See [`THEME_SPEC.md`](THEME_SPEC.md).

## Uninstall

Remove the symlinks the installer created:

```sh
rm ~/.config/quickshell/archeotech
rm ~/.config/archeotech/themes ~/.config/archeotech/assets
# (leave ~/.config/archeotech/wallpapers if it's your own images)
# remove the shell scripts from ~/.local/bin as desired
```
