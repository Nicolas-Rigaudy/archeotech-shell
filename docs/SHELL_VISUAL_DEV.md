# Shell visual-dev workflow (how to SEE a change)

> Standing reference so we don't rediscover the tools each session: how to render
> every surface without touching the running desktop, the gotchas that waste time,
> and where the theme tokens live.

## The rule
Every render goes through `scripts/shot.sh`. Never screenshot the real screen
(`grim`), never drive the running shell over IPC (`qs ipc` without `--pid`, or
`qs -c archeotech ipc …`), never start a second shell or compositor by hand. The
live bar is someone's working desktop.

`shot.sh` runs a nested headless mango in a private temp dir: a fake HOME seeded
with copies of your archeotech config and state, a private `XDG_RUNTIME_DIR`, its
own D-Bus session and a generated minimal mango config, so your autostart never
runs and nothing reaches the live session. Its `~/.local/bin` is an allowlist:
scripts that act on the live session by process name (theme-switch signals every
kitty; the reload scripts pkill the shell) are replaced by stubs that log their
arguments to `log/stubs.log` in the run dir (`--keep` to inspect). It launches the shell with
`qs -p <root>/shell.qml`, so it renders any checkout, including git worktrees. No
`HOME=` prefix is needed. Output is 1280x720 with the pixman renderer (no blur, no
audio).

## Rendering each surface

### Full shell and bar-edge panels
```
scripts/shot.sh out.png                                   # just the shell
scripts/shot.sh --state dashboard out.png                 # open a panel first
scripts/shot.sh --state settings:appearance out.png       # settings on a pane
scripts/shot.sh --root ../archeotech-shell.wt/foo out.png # render a worktree
```
States: `dashboard`, `launcher`, `settings[:pane]`, `notifications`, `wallpaper`,
`media`, `layout`, `editmode`, `theme` (reload). Handlers live in `shell.qml`; the
IPC call is made inside the nested session, addressed by pid.

### Looks: theme, pack, flat mode
```
scripts/shot.sh --theme archeotech-latte --pack grimdark --flat 0 --state launcher out.png
```
`--theme` takes a directory under `themes/` (its `theme.json` sets dark or light);
`--pack` takes a pack id or `base`; `--flat 0|1`. Unset flags keep your current
choice. For a matrix, loop the flags and build one contact sheet:
```
magick montage *.png -tile 4x -geometry 640x360+4+4 -label '%t' sheet.png
```
Independent runs can go two or three at a time.

### Motion, notifications and settings
`--burst N -i SECS` captures a series (`out-000.png` …); `--notify` fires a real
notification inside the nested session so toast motion can be checked across frames;
`--notify-count N` fires N notifications with no expiry (the shell's own timeout
applies). `--set key.path=value` edits the fake HOME's `config.json` (repeatable, value
parsed as JSON when possible), `--shell-config file.json` renders a fixed layout, and
`--fresh` copies none of your config or state (a stranger's first boot).
Note: harness components rendered with `--qml` don't get the shell's theme wiring
(Appearance colours are undefined), so test panel behaviour in the full shell.

### Hover and click popups (no IPC state)
Calendar (clock hover), wifi / bluetooth (tray click) and hover-cards have no IPC.
Render the component alone with `--qml`, from a throwaway harness written outside
the repo (a scratch dir), never at the repo root:
```
scripts/shot.sh --qml /path/to/scratch/calendar-harness.qml -w 9 out.png
```
Template (the harness forces a pack and mocks the `holderRoot` the component reads;
absolute imports need the `file:` scheme;
adjust the import paths to point at the checkout being rendered):
```qml
import QtQuick
import Quickshell
import "file:/home/<you>/Projects/archeotech-shell/Commons" as Commons
import "file:/home/<you>/Projects/archeotech-shell/Widgets/Bar"
ShellRoot { FloatingWindow {
    implicitWidth: 460; implicitHeight: 420; color: "#0c0f16"
    Component.onCompleted: {
        Commons.Appearance.activePackDir = "/home/<you>/Projects/archeotech-shell/packs/grimdark/"
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
mock headlessly: apply the verified pattern from a mockable sibling (Calendar,
HoverCard) and ask the owner to check those two on their own screen.

### When a render fails
Rerun with `--keep`; the run dir it prints holds `log/qs.log` and `log/mango.log`.

## Regression checks (goldens, logic tests, CI)
- **`scripts/golden.sh`** renders a fixed matrix (bar, dashboard, launcher, media,
  wallpaper, settings:appearance, notifications, editmode × macchiato dark / latte
  light / macchiato flat, plus a grimdark dashboard) with `--fresh` and the
  committed `tests/golden/fixture-wallpaper.png`, and diffs each frame against
  `tests/golden/<name>.png`. Dynamic regions (clocks, battery %, gauges, real repos,
  installed apps, the text cursor) are masked in `tests/golden/masks.txt`. Masked
  back-to-back runs measure 0 px; the default fail threshold is 40 px
  (`THRESHOLD=`/`FUZZ=` override). `--root <wt>` tests a worktree, `--only 'glob'`
  a subset. A failure leaves `<run>/diff/<name>.diff.png`.
- **Intended visual change?** Run `scripts/golden.sh --update --only '<affected>'`,
  look at the new PNGs, and commit them *with* the change. Goldens are
  machine-bound for now (fonts, icon theme, desktop entries).
- **Logic tests:** `tests/run.sh` (qmltestrunner, offscreen, throwaway HOME).
  Quickshell's types live in the `qs` binary, so testable logic goes in plain
  `.pragma library` JS next to its service (e.g. `Services/Shell/ShellConfigLogic.js`)
  and tests import that; see `tests/qml/tst_*.qml`.
- **Contrast:** `scripts/contrast-check.py` reports each theme's text-token contrast
  (body 4.5:1, muted 3:1); informational until the design-system floor lands
  (`--strict` to gate).
- **CI** (`.github/workflows/ci.yml`, job `qml`, Arch container): Qt6 qmllint via
  `scripts/qmllint-ci.py` (fails on syntax errors, prints per-id counts), the logic
  tests, and the contrast report. Renders need mango (AUR), so goldens run locally
  until a cached CI image exists.

## Hot-reload and the live bar
The live bar follows whatever `~/.config/quickshell/archeotech` points at. If it
points at the dev checkout, every save hot-reloads onto the running bar, so keep
every save valid and never add debug visuals. Pinning the live bar to a separate
worktree (see `archeotech-live.sh` in the dotfiles repo) removes that coupling:
edits then reach the bar only when a commit is promoted.

## Pack / config gotchas
- The running shell OWNS `activePack` + pack settings and re-persists
  `~/.config/archeotech/config.json`, so external edits to the real file get
  clobbered: change material/pack on the live bar via the **Settings UI**. In
  renders, use `shot.sh --pack`, which edits only the fake HOME's copy.
- To test a **register** without UI: flip `defaultRegister` in the pack
  `tokens.json` and render; set it back afterwards. (Registers = parked feature.)
- `material` MUST be `matte` for the steel/depth look; `frameChamfer` (pack
  `frame.corners=="chamfer"`) is currently the gate every Grimdark branch keys on
  (to be replaced by surface recipes, item_112).

## Theme tokens (single sources)
- Steel family: `packs/grimdark/tokens.json` → `panels.steel {hi,md,lo,edge,lip}`
  → `Commons/Appearance.qml` `steel` object. Mirrors FrameFx `_faHi/_faMd/_faLo`.
- Copper/accent = pack `colors.peach` (`Appearance.colors.accent`); NMM ramp in
  consumers = `peach` + `Qt.lighter/darker`. Teal `colors.teal`: **not** used on
  selectors (reads modern); reserved for genuine live data only.
- Display face (Cinzel) = `Appearance.font.display` (falls back to body mono for
  base packs). Use it for headers/titles; for icon+label headers, split the glyph
  (icon font) from the label (display) so the nerd-glyph survives.
- Console chrome primitive: `Commons/Primitives/ConsoleChrome.qml` (copper trim +
  far-corner gussets + a two-bar collar; `showTrim/showGussets/showCollar` flags).
