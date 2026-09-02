# Installing Archeotech

## Requirements

**Required** (the shell won't run without these):

- **[Quickshell](https://quickshell.org)** 0.3.0+
- A **wlroots-based Wayland compositor** — **MangoWC** is the primary target; Hyprland works.
- A **Nerd Font** (for glyphs) and a sans family, plus an icon theme (Papirus recommended).

**Optional** (individual widgets/features light up when present; the shell
degrades gracefully otherwise): `wl-clipboard`, `brightnessctl`,
`wpctl`/`pipewire` (volume OSD), `NetworkManager` (network widget),
`bluez` + `bluez-utils` (bluetooth widget), `wlr-randr`, `swww`/`awww`
(wallpaper), `hyprlock` (lock), `wlogout` (power menu),
`rsvg-convert` + `imagemagick` (wallpaper/logo compositing), `kitty`
(themed terminal colors).

### Install dependencies (Arch)

Package names below are for Arch + an AUR helper (`paru`); on other distros find
the equivalents.

```sh
# Required
paru -S quickshell-git mangowc-git \
        ttf-firacode-nerd noto-fonts papirus-icon-theme

# Optional (recommended for the full experience)
paru -S wl-clipboard brightnessctl pipewire wireplumber \
        networkmanager bluez bluez-utils wlr-randr swww \
        hyprlock wlogout imagemagick librsvg kitty
```

> Using the companion [`archeotech-dotfiles`](https://github.com/Nicolas-Rigaudy/archeotech-dotfiles)?
> Its `scripts/install-packages.sh` installs all of the above (and the rest of the
> desktop) with a required/optional split — see that repo's `docs/INSTALLATION.md`.

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
