<div align="center">

<img src="docs/img/header.svg" alt="Archeotech" width="620">

### Your desktop, your rules.

[![Built with Quickshell](https://img.shields.io/badge/built%20with-quickshell-c6a0f6?style=for-the-badge&labelColor=24273a)](https://quickshell.org)
[![MangoWC](https://img.shields.io/badge/mangowc-supported-8aadf4?style=for-the-badge&labelColor=24273a)](https://github.com/DreamMaoMao/mangowc)
[![Hyprland](https://img.shields.io/badge/hyprland-supported-7dc4e4?style=for-the-badge&labelColor=24273a)](https://hyprland.org)
[![License](https://img.shields.io/badge/license-GPL--3.0-a6da95?style=for-the-badge&labelColor=24273a)](LICENSE)

</div>

<!-- Placeholder until the showcase video is recorded: replace with the bare user-attachments mp4 URL. -->
<div align="center">
<img src="docs/img/dashboard.png" alt="The Archeotech dashboard over the glass frame" width="900">
</div>

<details>
<summary><b>More screenshots</b></summary>

| | |
|:---:|:---:|
| <img src="docs/img/launcher.png" alt="Launcher" width="440"><br>Launcher | <img src="docs/img/settings.png" alt="Settings" width="440"><br>Settings |
| <img src="docs/img/editmode.png" alt="Edit mode" width="440"><br>Edit mode | <img src="docs/img/keyboard.png" alt="Keybinds panel" width="440"><br>Keybinds panel |
| <img src="docs/img/wallpaper.png" alt="Wallpaper picker" width="440"><br>Wallpaper picker | <img src="docs/img/themes.png" alt="Six themes" width="440"><br>Themes |

</details>

Archeotech is a shell made to be shaped. The layout, the look and the behaviour are yours to change,
from inside the shell, while it runs. Whatever is missing, you can add as a folder.

## Make it yours

**Layout.** Every screen edge can be a bar, an icon strip or nothing. Open edit mode and drag widgets where you want them.

**Look.** Pick a palette, dark or light, and any accent. Add a theme pack to change the material, the frames and the fonts.
Your terminal, GTK apps, launcher menus and editor follow along.

**Behaviour.** Everything else is a setting in one searchable app, and every setting goes back to its default in one click.

**Extend.** Widgets, panels and theme packs are plain folders with a manifest. Write your own or drop in someone else's.

Also in the box: a launcher, a dashboard, notifications, a wallpaper picker, a keybinds panel and display profiles that follow your monitors.

## Installation

You need [Quickshell](https://quickshell.org) 0.3 or newer, a Nerd Font and an icon theme (Papirus recommended).

```sh
git clone https://github.com/Nicolas-Rigaudy/archeotech-shell.git ~/Projects/archeotech-shell
cd ~/Projects/archeotech-shell
./scripts/install.sh --dry-run   # preview, then run it without the flag
qs -c archeotech
```

The installer links the repo to `~/.config/quickshell/archeotech`, adds the theme packages and two wallpapers,
and puts the helper scripts on your `PATH`. Optional tools (NetworkManager, bluez, brightnessctl, awww and others)
enable their widgets when present. The full list is in [`docs/INSTALL.md`](docs/INSTALL.md).

Then add the window rules and keybinds from [`examples/`](examples/) to your compositor:
[MangoWC](examples/mangowc.conf.example) or [Hyprland](examples/hyprland.conf.example).

> [!NOTE]
> Archeotech is pre-1.0. It is a daily driver on MangoWC; Hyprland is supported through the example config.

## Usage

Default binds from the example config:

| Keybind | Action |
|---|---|
| `Super + R` | Launcher |
| `Super + Home` | Dashboard |
| `Super + ,` | Settings |
| `Super + W` | Wallpaper picker |
| `Super + K` | Keybinds panel |
| `Super + Shift + K` | Special characters |
| `Super + ;` | Notifications |
| `Super + Shift + E` | Edit mode |

Everything is also reachable over IPC:

```sh
qs -c archeotech ipc call launcher toggle
qs -c archeotech ipc call settings openPane appearance
```

Targets: `launcher`, `dashboard`, `settings`, `wallpaper`, `keybinds`, `notifications`, `editmode`, `media`,
`layout`, `osd`, `panel`, `popup`, `sides`, `theme`.

## Configuring

Most things are set from the Settings app and edit mode. Both write `~/.config/archeotech/config.json`,
which hot-reloads when you edit it by hand.

<details>
<summary><b>Extend it</b></summary>

- Write a widget or a panel: [`docs/MODULE_API.md`](docs/MODULE_API.md), [`docs/WIDGET_API.md`](docs/WIDGET_API.md), [`docs/PANEL_API.md`](docs/PANEL_API.md)
- Make a theme: [`docs/THEME_SPEC.md`](docs/THEME_SPEC.md)
- Make a theme pack: [`docs/THEME_PACK.md`](docs/THEME_PACK.md), [`docs/STYLE_API.md`](docs/STYLE_API.md)
- MangoWC notes: [`docs/MANGOWC-SETUP.md`](docs/MANGOWC-SETUP.md)

</details>

<details>
<summary><b>Develop</b></summary>

- `scripts/shot.sh` renders the shell in an isolated headless compositor. Your running session stays untouched.
- `tests/run.sh` runs the logic tests. `scripts/golden.sh` compares 25 renders against the goldens.
- CI runs qmllint, the logic tests, palette fidelity and contrast checks.
- Regenerate the screenshots: [`docs/screenshots.md`](docs/screenshots.md).

</details>

## Updating

```sh
cd ~/Projects/archeotech-shell && git pull
```

The config dir is a link to the clone. QML changes hot-reload; restart the shell after a pull that adds packs or plugins.

## FAQ

**Does it work on other compositors?**
MangoWC and Hyprland only. The workspace and window widgets talk to their IPC.

**Where do my settings live?**
`~/.config/archeotech/config.json`. Delete it to start from the defaults.

**Can I use only the bar?**
Yes. Turn the other screen edges off in edit mode and leave the panels on their binds.

## Credits

- [outfoxxed](https://github.com/outfoxxed) and [Quickshell](https://quickshell.org), which makes all of this possible.
- [caelestia](https://github.com/caelestia-dots/shell), [end-4](https://github.com/end-4/dots-hyprland), [Noctalia](https://github.com/noctalia-dev/noctalia) and [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) for showing what a Quickshell shell can be.
- [Catppuccin](https://github.com/catppuccin), Dracula, Gruvbox, Nord and Tokyo Night for the palettes, and [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) for the icons.
- [MangoWC](https://github.com/DreamMaoMao/mangowc) for the compositor.

Want the whole desktop around it? [archeotech-dotfiles](https://github.com/Nicolas-Rigaudy/archeotech-dotfiles) is the machine config this shell runs on.

## License

[GPL-3.0](LICENSE). The bundled wallpapers are from [Pexels](https://www.pexels.com/license/).
