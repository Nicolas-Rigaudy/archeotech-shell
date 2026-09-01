# Frame + adaptive-corner handoff (Shadow Spears)

> Resume note for the WH40K frame redesign. The frame is ~90% done; the ONE open
> task is an **adaptive corner system**. Read this whole file first. Nothing is
> committed — the owner squashes/cleans before pushing. **Do NOT commit or push.**

> **UPDATE 2026-08-31 — frame reworked to a flat welded bezel (mitred brackets removed).**
> After a long design pass (see `docs/corner-options.html` history), the mitred/copper
> approach was dropped. `FrameFx.qml` now draws:
> - **Flat welded panel bands** (top band top-lit `_faHi→_faMd→_faLo`; rails flat `_faMd`)
>   — the old per-band NMM tube gradients caused a "four pipes" look; gone.
> - **Chamfer corners = tiny gap-wedge only.** A per-corner wedge (size = `cornerRadius`)
>   fills the chamfer gap the rect-bands leave, matching `_faMd`, with a faint lit line on
>   the 45° cut. The corner reads via the content chamfer + teal edge. **A bigger facet was
>   tried and reverted — a full-depth (~46px) plate physically clipped the workspace/power
>   widgets.** Any corner detail MUST stay inside the thin border, never reach the widgets.
> - **Edge trim:** copper bezel replaced by a thin **brass trim on the bar edge only**
>   (`_barEdgePath`, uses `_cuMid/_cuHi`) + a restrained **teal live-edge** all round
>   (`_tealEdge`, rgba a≈0.42). Strip rivets (fx.seams) still provide rail studs.
> Verified live eDP/HDMI/DP-3. Owner: "keep it clean for now" — no corner ornament.
> Deferred (needs care around live bar widgets, NOT yet built): the mockup's bar-face
> gear-rack + segment seams + centre nameplate. `panels/corner-bracket.png` still unused
> (delete at squash).

## Verify on the LIVE screen — NOT headless (this bit us all session)
The headless `shot.sh` uses a single-output 1280×720 fake HOME; it repeatedly
looked clean while the real multi-monitor bar was wrong. **Always grab the real
screen:**
```
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 grim /tmp/.../live.png   # 4920x1920
```
Monitors (grim composites all three): **eDP-1** x0–1920 y0–1200 (landscape),
**HDMI-A-1** x1920–3840 y60–1140 (landscape, shorter), **DP-3** x3840–4920 y0–1920
(**portrait**). Different sizes ⇒ different corner junction types ⇒ check ALL.
Crop+zoom a corner: `magick live.png -crop 110x110+0+0 +repage -filter point -resize 550% c.png`.

- QML / token / gradient edits **hot-reload** onto the live bar.
- A **new** PNG asset (new path) loads fresh; **replacing** an existing PNG is
  image-cached → needs a shell restart to show.
- Headless is fine only for a quick QML-validity check:
  `HOME=<fakehome> bash scripts/shot.sh -w 9 out.png`.
  fakehome: `/tmp/claude-1000/-home-corvus-Projects-archeotech-dotfiles/491f2206-cd2e-405b-abfa-69d821a12f61/scratchpad/fakehome`
  (set its `packs.shadow-spears.material` to `"matte"` if testing NMM).

## THE OPEN TASK — adaptive corner system (design agreed with owner)
Replace the current placeholder corner (a fixed `panels/corner-bracket.png`
sized to the border — owner rejected: a nub where the thick bar meets a thin
strip, cluttered where two strips meet, doesn't adapt). Build a **procedural,
per-junction** corner instead:

- **Follows the chamfer** — the plate's inner edge IS the 45° chamfer (not a square).
- **Adapts to the two adjacent members.** Per corner, read each side via
  `ShellServices.ShellConfig.sideType(side, screenName)` → `"bar"|"strip"|"holder"|none`
  and that member's thickness (the content inset for that side — see contentRect below):
  - **bar↔strip** (top corners here): L with a **thick** arm (bar width ~30) + a **thin** arm (strip width ~16).
  - **bar↔bar**: both thick arms.
  - **strip↔strip** (bottom corners here): small even thin L.
  - **END CAP**: if the adjacent side is `none`/`holder`, that member **terminates** → draw an end-cap on the member's end, not a junction bracket.
  - Each arm's width = its member's thickness (that's what makes it adapt).
- **One diagonal gradient** per corner (bright at the OUTER screen corner → dark
  toward the content) so the corner reads as a single machined piece with **no
  internal seam**. (Per-band gradients meet with different directions → the seam
  that motivated all this; the corner plate + diagonal light hides it.)
- **Rivets adapt to arm length**: long bar arm → 2, short strip arm → 1.
- **Copper bezel mitres** around the chamfered inner edge (already done, keep).
- Must be a **real machined plate** (bevel via edge highlight/shadow, domed rivet
  images) — NOT a flat grey Rectangle (owner called that out).

Data you need is in `FrameFx.qml`: `contentRect` (the content-hole rect) gives the
insets — left=`contentRect.x`, top=`contentRect.y`, right=`width-x-w`, bottom=
`height-y-h`; `cornerRadius` = the chamfer size (pack `frame.cornerRadius`=9).
`sideType` needs the screen name — FrameFx has `screenName`? confirm; else pass it
in from ShellSurface, or derive junction types from which insets are non-zero.

## Current frame architecture (all pack-gated; base pack untouched)
- **`FrameBackground.qml`** — ONE `Shape` fill for the whole frame. `fillet()`
  makes corners a 45° **chamfer** when `Commons.Appearance.frameChamfer`. Publishes
  `contentRect` + `cornerR`.
- **`FrameFx.qml`** (mounted BEFORE the SideLoaders → **behind** the bars, widgets
  draw on top). Sections, in paint order:
  - **Frame chassis (NMM steel)** — 4 per-band `Rectangle`s: top/bottom vertical
    gradient, left/right horizontal, tight high-contrast NMM steel
    (`_stHi`/`_stMid="#29323d"`(mean of brushed)/`_stLo`). *This is the frame FACE
    now — the bar has no separate plate.* Per-band directions are why corners need
    the adaptive plate.
  - **Corner bracket-plates** — CURRENT PLACEHOLDER to replace (`_brkSrc` =
    `panels/corner-bracket.png`, `_brkSz` = fit-to-border binding, rotated per corner).
  - **Copper bezel** — `_bezelPath` = one continuous stroked ShapePath tracing the
    chamfered content outline; 3 concentric strokes = NMM copper
    (`_cuLo`/`_cuMid`/`_cuHi`). GOOD, keep.
  - **Plate seams** (`fx.seams`) — periodic **strip rivets** only (grooves removed).
- **`Bar.qml`** — `_console` (gated `bar.dividers`) now only draws **zone divider
  seams** (groove + FLANKING rivets, one column per plate). No bar plate (FrameFx
  top band is the face). Zones inset +12px when console on.
- **`Appearance.qml`** — `packMaterialMatte` + `depthFlat` (matte = opaque BUT
  keeps shadows/gradients); `frameChamfer` (pack `frame.corners=="chamfer"`);
  `panelPlate` (pack `panels.surface` → for MetalSurface); `glassSheen*` matte =
  opaque steel-ish gradient.
- **`Commons/Primitives/MetalSurface.qml`** (new) — pack-aware card/panel surface,
  currently the **brushed** `plate.png`. Used by `DashCard`/`SettingsCard`.
  ⚠️ Still brushed — switch to NMM steel when doing the component pass.
- **`styles/GlassButton.qml`** — metal button delegate (brushed plate + NMM copper
  active). Registered in `pack.json` `styles:["GlassButton"]`.
- **`WorkspacesWidget.qml`** — NMM pills, gated on `Appearance.panelPlate!=""` so
  the base pack stays flat (leak fixed).

## Assets — `packs/shadow-spears/`
- `textures/brushed-metal.png` — clean brushed tile (frame no longer uses it; MetalSurface does).
- `panels/plate.png` — brushed 9-slice (MetalSurface / GlassButton).
- `panels/rivet.png` — domed copper rivet (reuse for corner rivets).
- `panels/corner-bracket.png` — the REJECTED fixed bracket; delete when the
  adaptive corners land.
- `fonts/Cinzel-{SemiBold,Regular}.ttf` + `OFL-Cinzel.txt`.
- Generate assets with ImageMagick (`magick`) — e.g. rivet = shaded sphere; plate =
  brushed `-raise` bevel. Keep OFL/self-made only.

## tokens.json (shadow-spears) — key values
`material:"matte"`, `frame:{cornerRadius:9,corners:"chamfer"}`,
`panels:{surface:"panels/plate.png"}`, `fx.bevel:{enabled,color:"peach",width:3}`
(drives copper bezel), `fx.seams:{enabled:true,bolt:"peach",spacing:190}` (strip
rivets), `fx.texture` off, `fx.rails:{enabled:true}` (gates the chassis bands +
corner plates). Palette: text `#e7e8ec` (cool white), `teal #57d8d2` (cyan),
green/blue muted, accent `peach #a8683c`.

## Gotchas (all cost us real time)
- **The running shell owns `activePack` + pack settings in memory and re-persists
  `~/.config/archeotech/config.json`, clobbering external edits.** Change material/
  pack via the **Settings UI**, or `pkill -x quickshell; <edit>; qs -c archeotech &`.
- **`material` MUST be `matte`** for NMM/depth (`flat`→`depthFlat`→no NMM). pack.json
  default is now `matte`. Owner's live config was stuck on `flat` (old default) —
  fixed. Backup: `~/.config/archeotech/config.json.bak-metal`.
- Never put debug visuals in live shell QML (hot-reloads onto the bar).
- `[[no-debug-visuals-in-live-shell]]`, `[[flagship-wip]]` memories apply.

## Done this session (frame)
Occlusion fix; palette→bible; Cinzel wired; matte material (opaque+depth);
NMM-steel chassis; continuous chamfered copper bezel; domed rivets; clean strips
(rivets kept, grooves gone); unified icons; MetalSurface + GlassButton delegate
(still brushed — NMM-ize later); media idle-width fix; NMM workspace pills.

## THE STYLE TO PROPAGATE (as of 2026-08-31 — the frame is the reference)
The frame now defines the Shadow Spears look. Bring everything else to match it:
- **Flat steel face** — `_faMd #28313d` body, `_faHi #333f4d` top-lit, `_faLo #1c232d`
  lower. **NOT** brushed `plate.png`, **NOT** the old NMM ridge (that read as tubes).
- **Recessed-screen depth** — dark edge line `#05080d` + a faint top/left lit lip
  (`#9fb0c2` ~0.5). This is what makes a surface read as machined, not flat.
- **Chamfered corners** — 45°, `cornerRadius` ≈ 9; reuse the `frameChamfer` chamfer.
  Keep corner treatments SMALL / inside the border — never overlap interactive content
  (the big corner facet clipped bar widgets and was reverted).
- **Trim = two thin lines, used with restraint:** brass (`_cuMid/_cuHi`, the peach
  accent) as a hairline; teal live-edge `#57d8d2` at α≈0.42 **reserved for active/live
  edges only** (the bible's "cyan = a pinpoint"). Don't flood surfaces with either.
- **Type:** Cinzel for titles/headers.

## DONE this session (2026-08-31, part 2 — popup/pack propagation)
The rest of the pack now matches the frame's flat welded-steel look. A **two-accent
system** emerged and is deliberate: **copper = structural chassis** (frame bezel, bar,
strip icon rail — the settled BarPill active pill stays copper) / **teal = live popup
content** (open-popup edge + every "selected/active" control). Verified live on eDP-1 +
HDMI-A-1 + DP-3 (portrait). Nothing committed.
- **Steel single-sourced**: `packs/shadow-spears/tokens.json` → `panels.steel {hi,md,lo,edge,lip}`
  (mirrors FrameFx `_faHi/_faMd/_faLo` + recess), exposed via `Appearance.steel`, forwarded
  into the `GlassButton` `api.colors` (steel* + teal + chamfer). One source, no re-hardcode.
- **Popup panel** (`Modules/Shell/Sides/Strip.qml`, `card`): steel branch gated on
  `Appearance.frameChamfer` — LOCAL top-lit steel fill (each popup its own plate) + a teal
  live-edge tracing the whole outline. Glass packs keep the screen-mapped sheen untouched.
- **`MetalSurface.qml`**: brushed `plate.png` → `Shape` flat-steel face + 45° chamfer + dark
  seat outline + inset brass hairline (steel branch on `frameChamfer`; plate/plain fallbacks
  kept). Drives `DashCard`/`SettingsCard`.
- **Pack `styles/GlassButton.qml`**: flat steel + chamfer + dark seat; rest = brass hairline,
  active = teal live-edge + lifted steel (copper wash + end-rivets gone). Base `GlassButton.qml`
  label now light under `frameChamfer` (was dark `base`, unreadable on steel).
- **`SegmentedControl.qml`**: active pill = steel + teal edge + light text (was copper wash).
- **`SettingsSidebar.qml`**: active pane bar + icon → teal. **`ColorSchemeBody.qml`**: selected
  family card border + check → teal. **`DashCard.qml`**: section titles → Cinzel (`font.display`).
- **Cleanup**: deleted `_metalharness.qml` + `panels/corner-bracket.png` (untracked).
- ⚠️ Hot-reload can RACE a grab — after an edit, `touch` the file + `sleep ~2` before `grim`,
  else you shoot the pre-reload frame (bit me on the Cinzel check).

## SESSION 3 (2026-09-01) — SUPERSEDES the teal parts of session 2
Big direction change: **teal is DROPPED everywhere** (selectors, sidebar, buttons AND the
frame edge) — the owner found cyan "too modern." Copper/`accent` carries active/selected
states now; teal is not used at all. Also the popup connection became a **bolted console**.

- **Bolted-console popups** — new `Commons/Primitives/ConsoleChrome.qml`: copper molded trim
  + far-corner gussets (never on the attach edge) + a **two-bar collar, NO bolts** (dark seam
  + two short copper mounting bars near the ends) on the bar/strip-attached edge. Flags:
  `showTrim/showGussets/showCollar`. Wired into `Strip.qml` (strip popups), `BarPanel.qml`
  (bar dropdown), and the mini popups (`CalendarPopup/WifiPopup/BtPopup/HoverCard`, collar-only
  = showTrim/showGussets false, content nudged down ~10px to clear it). NB the strip ICON RAIL
  owns the attach edge, so gussets skip that edge's corners.
- **Strip icon clipping fixed** — `_iconMargin`/`_popupExtra` (Strip.qml) are now fixed minima,
  NOT tied to the pack's tiny `radius.md` (which made the pack popup ~8px thinner than base and
  clipped the icon highlight). Hover-grow kept; soft drop-shadow OFF on strip cells + the BarPill
  active key under the steel pack (bled/looked modern).
- **Gothic selectors** — `SegmentedControl` (recessed dark slot + square-cut steel key, copper
  edge, no soft shadow), `ColorSchemeBody` theme cards (steel plate + copper hairline),
  `SettingsSidebar` (copper active bar+icon). Selected = copper (`colors.accent`), teal removed.
- **Cinzel everywhere** (`font.display`) — SectionLabel, sidebar page names, PaneHeader, DashCard
  titles, popup titles (dashboard greeting, Launcher RECENTS, Media, NC — icon+label SPLIT so the
  nerd-glyph keeps the icon font), bar popups (calendar month, wifi/bt titles, hovercard label),
  and the **bar clock DATE** (rich-text span `font-family` + `font-size +2` to match the time).
- **Frame content-edge (`FrameFx.qml`)** — copper/brass trim **all around** now (was teal on the
  rails + brass on the bar only; teal dropped). Removed the "soft inner shadow" black border =
  the **black line around content windows**. Copper Shape switched CurveRenderer → **GeometryRenderer**
  (CurveRenderer dithered the thin vertical strokes into a mottled/dashed copper, worst on the
  portrait output); bezel path pixel-snapped (`Math.round`).
- **Registers ENGINE — PARKED, do not build UI yet** — `tokens.json` `registers{space-marine/
  inquisition/mechanicus}` + `defaultRegister` + `Appearance._mergedPack` deep-merge +
  `Appearance.activeRegister/registers`. Dormant at default `space-marine` (no-op). The 3 faction
  palettes are placeholder/too-subtle. To test a register live: flip `defaultRegister` in tokens.
- **Copper-tone match — PARKED (owner: "figure out later")** — `Appearance.colors.copperLit =
  Qt.lighter(peach, 1.2)`; panels point their flat copper at it so it matches the frame trim's
  PEACHY read (frame = peach #a8683c + bright `lighter(peach,1.95)` highlight ≈ #cc7e49). If off,
  it's a ONE-number tune (the `1.2`). `Qt.lighter(>~1.3)` desaturates toward pink — avoid.
- **New doc** `docs/SHELL_VISUAL_DEV.md` — the render workflow (IPC for panels, `shot.sh --qml`
  + mock-holderRoot harness for hover-only popups, the reload race, monitor map, token sources).

## OPEN / NEXT SESSION
1. **Bar separators** clip the clock/date when window-title+media get long — make them fixed &
   centred with the clock, not moving with content.
2. **Deepen recessed wells** — cards read as recessed instrument screens (dark seat + lit lip).
3. **Registers UI + faction palettes** — scope the 3 factions together; engine is ready.
4. **Pack RENAME** — "Shadow Spears" is the owner's personal chapter; want a 40K-flavoured,
   non-trademarked name (candidates floated: Grimdark / Ceramite / Cogitator / Noosphere).
5. **Copper-tone final tune** (the `copperLit` factor) + selected-state copper if wanted.
6. **Squash cleanup** — untracked debug scaffolding to delete: `_*harness.qml`, `_panelmock.qml`,
   `docs/corner-options.html`.

## PROCESS NOTES (owner feedback — follow these)
- REASON from the code for computable values (colours, geometry); don't pixel-sample or render
  to check something the source already tells you. Render only for genuine layout/visual questions.
- Propose the direction, show it on ONE thing, and CONFIRM before applying broadly. Ask when unsure.
- Docs live in the project MDs, NOT the assistant auto-memory.
- Normally do NOT commit/push (owner squashes WIP) — this session the owner explicitly asked to commit.
