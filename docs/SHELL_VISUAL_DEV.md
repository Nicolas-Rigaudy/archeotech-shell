# Shell visual-dev workflow (how to SEE a change)

> Standing reference so we don't rediscover the tools each session. How to render
> every surface, the gotchas that waste time, and where the theme tokens live.
> The shell hot-reloads QML onto the LIVE bar — keep every save valid, no debug
> visuals on the live bar.

## Environment for every grim / IPC call
The sandbox `$HOME` is NOT `/home/corvus`. Always:
```
export HOME=/home/corvus XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0
```
Without the real HOME, `qs -c archeotech ipc ...` errors with "Could not find
archeotech config directory" and the shell reads the wrong config.

## Monitors (grim composites the whole layout)
- **eDP-1** x0–1920 y0–1200 (landscape)
- **HDMI-A-1** x1920–3840 y60–1140 (landscape, shorter)
- **DP-3** x3840–4920 y0–1920 (**portrait**)

`grim out.png` sometimes returns the full 4920×1920, sometimes a single 1920×1200
output — **always `identify` the PNG first**, then `magick -resize 1476x576` to an
overview to LOCATE the popup (its monitor/position varies per open), then crop
full-res. Panels open GLOBALLY (on every monitor); pick whichever is framed best.

## Rendering each surface

### Bar-edge PANELS — drive by IPC, then grim
dashboard / launcher / settings / notifications / wallpaper / media open via IPC:
```
qs -c archeotech ipc call dashboard open   # then grim, then:
qs -c archeotech ipc call dashboard close
```
Targets: `dashboard`, `launcher`, `settings` (+ `settings openPane <pane>`),
`notifications`, `wallpaper`, `media`. (Handlers live in `shell.qml`.)

### HOVER / CLICK popups — CANNOT be IPC'd → render in ISOLATION
calendar (clock hover), wifi / bluetooth (tray click), hover-cards (bar-widget
hover) have no IPC. Render the component alone in a nested headless compositor:
```
bash scripts/shot.sh --qml <harness.qml> -w 9 out.png
```
Write a throwaway `_<x>harness.qml` at the repo root that forces the pack + mocks
the `holderRoot` the component reads. Delete it after. Template:
```qml
import QtQuick
import Quickshell
import "Commons" as Commons
import "Widgets/Bar"
ShellRoot { FloatingWindow {
    implicitWidth: 460; implicitHeight: 420; color: "#0c0f16"
    Component.onCompleted: {
        Commons.Appearance.activePackDir = "/home/corvus/Projects/archeotech-shell/packs/shadow-spears/"
        Commons.Appearance.activePackStyles = ["GlassButton"]
    }
    QtObject { id: h
        property bool _calendarVisible: true          // or _popupVisible for HoverCard
        property int _calendarMonth: 9; property int _calendarYear: 2026
        property string side: "top"; property real width: 460; property var screen: null
        function keepPopupsAlive() {} ; function hideCalendar(c) {}
    }
    CalendarPopup { holderRoot: h }
} }
```
Services-backed popups (WifiPopup/BtPopup read `NetworkServices.*`) are hard to
mock headlessly — apply the verified pattern from a mockable sibling (Calendar/
HoverCard) and ask the owner to eyeball those two live.

## The reload RACE (bit us many times)
A QML edit hot-reloads, but a grim fired too soon captures the PRE-reload frame
(sometimes the base-pack fallback). After editing, before grim:
```
touch <the-edited-file> ; sleep 2.5   # 4s if it didn't take
```
`shot.sh --qml` spawns a fresh instance so it's already current.

## Pack / config gotchas
- The running shell OWNS `activePack` + pack settings and re-persists
  `~/.config/archeotech/config.json` — external edits get clobbered. Change
  material/pack via the **Settings UI**, not the file.
- To test a **register** live without UI: flip `defaultRegister` in the pack
  `tokens.json` (hot-reloads), then set it back. (Registers = parked feature.)
- `material` MUST be `matte` for the steel/depth look; `frameChamfer` (pack
  `frame.corners=="chamfer"`) is the gate every Shadow-Spears branch keys on.

## Theme tokens (single sources)
- Steel family: `packs/shadow-spears/tokens.json` → `panels.steel {hi,md,lo,edge,lip}`
  → `Commons/Appearance.qml` `steel` object. Mirrors FrameFx `_faHi/_faMd/_faLo`.
- Copper/accent = pack `colors.peach` (`Appearance.colors.accent`); NMM ramp in
  consumers = `peach` + `Qt.lighter/darker`. Teal `colors.teal` — **not** used on
  selectors (reads modern); reserved for genuine live data only.
- Display face (Cinzel) = `Appearance.font.display` (falls back to body mono for
  base packs). Use it for headers/titles; for icon+label headers, split the glyph
  (icon font) from the label (display) so the nerd-glyph survives.
- Console chrome primitive: `Commons/Primitives/ConsoleChrome.qml` (copper trim +
  far-corner gussets + a two-bar collar; `showTrim/showGussets/showCollar` flags).
