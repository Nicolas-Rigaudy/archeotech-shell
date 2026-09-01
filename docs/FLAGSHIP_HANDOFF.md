# Flagship pack + theming-engine — session handoff

> **ACTIVE WORK (2026-08-26): the metal frame redesign.** The whole frame was
> reworked into a WH40K machined chassis (matte NMM steel + chamfered copper
> bezel + rivets). The ONE open task is an **adaptive per-junction corner
> system** — full spec, current architecture, the live-screen verify workflow,
> and gotchas are in **`docs/FRAME_CORNER_HANDOFF.md`. Read that first.**


> Working note for resuming the Shadow Spears flagship + theming-engine work in a
> fresh session. Delete once merged. Point the new session at this file.

## TL;DR state
- **Theming engine (adr_027 Layers A–D) is DONE** (`task_011`/`item_081` closed).
- **item_083** (ornament overlay, font hook, material token, bevel, rivets, console
  housings, cross-app theming) is built incrementally, mostly working.
- **Shadow Spears flagship (`item_082`) is in ACTIVE WIP** — a WH40K "instrument
  console" look. Current direction is agreed and looks right; refinements remain.
- **Nothing since commit `c0ceedc` is committed on purpose.** The owner will clean
  up / squash the WIP git history before pushing. **Do NOT commit until they OK it.
  Do NOT push.**

## Git state
- Repo `~/Projects/archeotech-shell` (the shell + theme-switch + packs live here).
- Last commit: `c0ceedc`. **Uncommitted working tree = the bar-console feature:**
  `Commons/Appearance.qml` (bar.dividers token), `Modules/Shell/Sides/Bar.qml`
  (console housings), `packs/shadow-spears/tokens.json` (bar.dividers + look).
- Commits roughly `bb86eb5`→`c0ceedc` are WIP flagship iterations the owner wants
  to squash before push. `theme-switch.py` changes are in `7dc18c7`/`9314e9e`.
- Dotfiles repo `~/Projects/archeotech-dotfiles` holds the logics docs. `item_082`
  / `item_083` were NOT updated with the latest iterations — do that when resuming.

## Working rules (important — these bit us this session)
1. **Don't commit until the owner approves a milestone.** They review by eye first.
2. **These files are the LIVE shell** (`~/.config/quickshell/archeotech` →symlink→
   this repo; Quickshell hot-reloads on save). A broken intermediate save breaks
   their running bar. Keep every save valid; land whole edits.
3. **ACTUALLY LOOK at renders, critically.** The recurring failure was calling
   subtle/flawed changes "good." Judge by *does it read as the goal*, not by
   narrating progress. Hairline changes (1px lines) are invisible = not real.
4. **HOME gotcha:** the sandbox `$HOME` ≠ `/home/corvus`. Use absolute paths, and
   `HOME=/home/corvus` for HOME-sensitive commands.
5. **Pack `configSchema` is read from `pack.json`, NOT `tokens.json`.**

## How to render/verify (headless, safe)
- `scripts/shot.sh [out.png]` = full shell; `--qml <file>` = one component.
- To test a **pack** without touching the live system, build a fake HOME:
  - `$FAKE/.config/quickshell/archeotech` → symlink to this repo
  - `$FAKE/.config/archeotech/config.json` with `appearance.activePack:"shadow-spears"`
  - `$FAKE/.config/archeotech/theme.json` + `themes/archeotech-macchiato/` copied in
  - `$FAKE/.config/mango/config.conf` with `border_radius=0`, `borderpx=0`
  - Launch mango with **`HOME=$FAKE`** (so it reads that config), open a couple of
    `kitty` windows in the STARTUP to see the frame↔window interaction.
  - A prebuilt fake HOME is at the session scratchpad `.../scratchpad/fakehome`.
- **Do NOT run the full `theme-switch.py` against the live session** — its
  `apply_mango` calls `mmsg dispatch reload_config` on the REAL compositor (reloads
  it + cycles the keyboard layout). Test appliers in isolation (import the module,
  stub `run`, redirect `HOME`).

## The engine — pack capability surface (what a pack can do today)
A pack = `packs/<id>/` with `pack.json` (manifest + `configSchema` + `minShellVersion`)
and `tokens.json`. Discovery: `Services/Shell/PackRegistry.qml`. Overlay merge +
all tokens: `Commons/Appearance.qml`. Pack tokens (all optional):
- `accent` (palette name) and full `colors{}` override (packs may carry their own
  palette — Shadow Spears does).
- `radius{}`, `spacing{}`, `font{ family, size*, displayFamily, displayFile }`,
  `bar{ height…, dividers }`, `anim{}`, `curve{}`.
- `frame.cornerRadius` (frame corner connections; overrides user Settings→Shell).
- `window.{cornerRadius,borderWidth}` → drives mango decoration via
  `Services/Compositor/MangoWC.applyWindowDecor` (idempotent; reversible on base).
- `material` = `"flat"`/`"matte"` → opaque, no glass (`Appearance.packMaterialFlat`
  → flatMode; glass fills opaque under flat).
- `fx.texture{source,opacity}`, `fx.glow{…}`, `fx.brackets{…}` (per-WINDOW, in
  `Modules/Shell/WindowBrackets.qml`, live client geom from MangoWC),
  `fx.bevel{enabled,color,width}` (recessed-screen lip), `fx.rivets{…}` (bolt
  studs), `fx.ornaments[{source,anchor,size,opacity}]` (SVG/PNG at frame corners),
  `fx.ornamentsEnabled` (toggle).
- Frame FX live in `Modules/Shell/FrameFx.qml`. Content-hole geom is published by
  `Modules/Shell/FrameBackground.qml` (`contentRect`, `cornerR`).
- **Component style delegates (Layer C):** `packs/<id>/styles/<ComponentId>.qml`
  replaces a component's visual (curated set = GlassButton so far). Contract in
  `docs/STYLE_API.md`; loader `Commons/Primitives/StyleDelegate.qml`;
  `minShellVersion`-gated. Delegate reads one `api` object (no Commons import).
- **Pack settings (Layer D):** `pack.json`→`configSchema` (dotted token paths as
  keys) → rendered by the existing ConfigForm in `Modules/Settings/Panes/AppearancePane.qml`
  → persisted under Config `packs.<id>` → merged over tokens (`Appearance._mergedPack`).
  Real (verified drives the look). Global "Flat mode" toggle is hidden when a pack
  is active (pack owns material).
- **Cross-app theming:** `scripts/theme-switch.py --pack <dir>` overlays the pack
  palette above mode/theme/flavor/accent. `Services/Theming/ColorScheme.qml._apply`
  passes `--pack` on pack switch (reversible on base). **kitty** now renders from
  the palette (template `scripts/themes/templates/kitty-colors.conf.tmpl`).
  **Still TODO:** gtk/vscode/obsidian/zen appliers use baked/app-specific assets and
  do NOT follow a pack palette yet — each needs a palette-render path.

## Shadow Spears — current look (`packs/shadow-spears/`)
Cold **blue-gunmetal** base (not brown/black), **opaque flat matte** slab, warm
**bone** text, **aged copper** accent (`peach`=#a8683c) with **steel** structure,
**gothic-arch copper** corner ornaments (`ornaments/gothic-corner.svg`), **vertical
brushed-metal** texture (`textures/brushed.png`, subtle), **domed copper rivets**
on the frame, **recessed bevel** screens, **full grimdark palette** so bar icons are
themed (the old bright-blue network icon was `colors.blue`, now overridden), **serif
display** headers (placeholder — see fonts below), and **bar console housings**:
left cluster / centre clock gauge / right status bank each in a steel-bordered
recessed housing with copper corner rivet studs (`bar.dividers:true`).

## Design direction (agreed)
Make it read as **real WH40K instrument tech**, not decoration-on-a-border. Key
principle: **framed instrument segments + density + structure + labels**, with
**steel = structure, copper = accents/fittings**. The bar is the console.

## Next steps (ranked)
1. **Refine console housings** — LEFT housing is too wide/empty (the `title` widget
   reserves width even blank). Size housings to real content, or exclude title.
2. **Stencil section labels** (`CHRON`/`STATVS`/`VOX` over each housing) — the
   biggest "reads Imperial" lever. **BLOCKED on an OFL gothic/stencil font:** none
   installed and can't fetch in-sandbox. Owner must drop a `.ttf` into
   `packs/shadow-spears/fonts/` and we set `font.displayFile`. (font hook already
   drives `Appearance.font.display`; wired into `PaneHeader` title so far.)
3. **Heavier structural rail** — a defined top/bottom edge on the bar.
4. **#5 Wear/grime** — recess ambient shadow, verdigris on copper, faint scratches.
5. **#2 Phosphor readouts** — per-widget glow + scanlines (a widget-styling pass;
   overlaps the dashboard/widget styling the owner flagged as "#6").
6. **#4 Corner style as a pack setting** — arch vs bracket vs plate.
7. Engine: finish gtk/vscode/obsidian/zen cross-app appliers; **coordinate the
   double mango-reload** on pack switch (theme-switch `apply_mango` + shell
   `applyWindowDecor` both reload → flicker + double keyboard cycle).

## Key files
- Engine: `Commons/Appearance.qml`, `Services/Shell/PackRegistry.qml`,
  `Commons/Primitives/StyleDelegate.qml`, `Modules/Shell/FrameFx.qml`,
  `Modules/Shell/WindowBrackets.qml`, `Modules/Shell/FrameBackground.qml`,
  `Modules/Shell/Sides/Bar.qml`, `Services/Compositor/MangoWC.qml`,
  `Services/Theming/ColorScheme.qml`, `scripts/theme-switch.py`,
  `Modules/Settings/Panes/AppearancePane.qml`.
- Pack: `packs/shadow-spears/{pack.json,tokens.json,textures/,ornaments/,styles/}`.
- Docs: `docs/THEME_PACK.md`, `docs/STYLE_API.md`.
- Untracked dev harnesses: `_packharness.qml`, `_ssheaderharness.qml`, `_btnharness*.qml`.
