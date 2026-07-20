# Polish & Liveliness — shell-wide rollout

Follows the Launcher taste-test slice (commit `556bc3a`, ANALYSIS.md §18). The
Launcher is the quality bar. Rolled out in feel-gated rounds (apply → live-test
via Super+Shift+R → commit on confirm), grouped by shared recipe.

## Main style: modern minimalist "liquid glass" (decided 2026-07-17)
The DEFAULT aesthetic is modern, minimalist, translucent frosted glass. Named
theme *personalities* (Warhammer 40k, Star Wars, cyberpunk, …) come LATER as
theme variants on top of this foundation — don't build them yet.

**Liquid glass = translucency + compositor blur + soft delimiting, cohesive.**
- Translucency: shared `glassBg`/`glassBgLight` alphas lowered to 0.80/0.74
  (`Commons/Appearance.qml`). All chrome shares them (cohesion). Tune to taste;
  with blur on, can go lower (~0.6–0.7) for a stronger frost.
- **Frost (the enabler):** MangoWC runs SceneFX with `blur=1` but shipped
  `blur_layer=0`, which disabled blur for layer-shell surfaces (= our shell).
  Set `blur_layer=1` in `config/.config/mango/config.conf` → real frosted blur
  behind the bar/panels/OSD. Applied via `mango-reload.sh` (Super+Shift+R).
  Blur radius/passes are `blur_params_*` in the same file.
- Delimiting: frost + translucency already separate chrome from content; a soft
  content-edge shadow (Caelestia `Elevation.qml`, end-4 `StyledRectangularShadow`)
  can reinforce it. Our frame is one WindingFill `Shape` (FrameBackground.qml)
  with no interactive children → a MultiEffect shadow on it is allowed.

## The recipe (validated on the Launcher)
- **Chrome vs nested — the cohesion rule (learned 2026-07-17):** the bar, strips,
  panels, popups, and OSD are ONE continuous glass language — they must all keep
  the shared translucent `glassBg`/`glassBgLight` so nothing reads as disconnected.
  `surfaceWarm` is ONLY for **nested cards/items that should stand out *within* a
  surface** (launcher recents tiles, dashboard cards, settings rows). Never warm a
  chrome surface itself. (First pass wrongly warmed the OSD pill + HoverCard fill →
  they detached from the bar; reverted to glass.)
- **Warmth**: `colors.surfaceWarm` (surface0 blended 0.15 → accent, α 0.85) for
  resting fills of nested cards/items — NOT chrome surfaces (see above).
- **Hover/press**: `Commons/Primitives/StateLayer.qml` — accent wash
  (`stateHover` 0.20 / `statePressed` 0.30) + `hoverScale`~1.05 / `pressScale`~0.96.
  Sibling overlay, never `layer.enabled` on interactive content.
- **Depth**: `RectangularShadow` (QtQuick.Effects) *sibling behind* the surface,
  only on things that genuinely float. Launcher tile = blur 16 / offset (0,5) /
  black α 0.5. Custom-Shape popups (eared) can't use a rect shadow → use a 1px
  hairline stroke (`glassBorder`) for lift instead (end-4 "ambient as border").
- **Enter/exit asymmetry**: `Commons.Anim { exit: !visible; duration: ... }` —
  gentle decel in (~220–400), brisk accel out (~120–200). The `exit:` binding
  gives direction-aware curve+duration on a bool-driven Behavior.
- **Focus**: inputs brighten border → accent + thicken to 2px + accent glyph.
- Constraints: never `layer.enabled` on interactive content; antialias Shapes
  with `Shape.CurveRenderer`; black shadows read weakly on dark glass — prefer
  warmth + hairline/elevation-tint where a big shadow would muddy.

## Round 1 — floating overlays
- [x] **OSD** (`Modules/OSD/Osd.qml`) — kept `glassBg` (cohesion), sibling shadow,
  grow-from-bottom enter / brisk exit, scale 0.92→1.
- [x] **HoverCard** (`Widgets/Bar/HoverCard.qml`) — CurveRenderer (was
  layer.enabled on interactive content), kept `glassBgLight` fill (cohesion),
  asymmetric enter/exit. No warmth/stroke — it's chrome.
- [ ] **CalendarPopup / WifiPopup / BtPopup** — CurveRenderer, KEEP glass fill,
  asymmetric enter/exit; StateLayer + surfaceWarm only on nested nav/connect/
  toggle buttons + list rows (not the popup surface).
- [ ] **MediaPanel + MediaWidget** — panel stays glass; StateLayer on transport
  buttons (hoverScale 1.08 / pressScale 0.92); album-art card may take warmth +
  a shadow (it's a nested item, not the chrome).

## Round 2 — panel content
- [ ] **Dashboard** cards (`Modules/Dashboard/panels/*`) — surfaceWarm container +
  hover accent border; StateLayer on QuickLaunch tiles (→44px) & ActiveProjects
  rows; animate SystemStatus bar via Commons.Anim. Depth: ONE subtle shadow per
  card at most, or skip (cards sit inside an already-elevated panel).
- [ ] **NotificationCenter + NotifToast** — toast: surfaceWarm + shadow, icon
  14→24, close→StateLayer, enter 400 decel / add exit 200 accel; history rows:
  icon→32, taller, StateLayer dismiss, optional per-index stagger (40ms).

## Round 3 — settings controls
- [ ] `Commons/Primitives/ToggleSwitch.qml` — thumb press-pulse (0.92, spring).
- [ ] `Modules/Settings/Widgets/SliderRow.qml` — handle 16→20, hover 1.08 / press 0.92.
- [ ] `SettingsSidebar.qml` — nav items → StateLayer; search field warmth + focus.
- [ ] rows (`ToggleRow`/`SliderRow`/`TextFieldRow`) — surfaceWarm; field focus states.

## Round 4 — strip + bar
- [ ] **Strip** openers — 44px rounded accent bg (statePressed active / stateHover
  hover), card scale-in 0.85→1, surfaceWarm card fill, holder-edge hover glow.
- [ ] Warm `BarPill` `showActiveBg` fill → statePressed/stateHover (only affects
  strip openers; bar stays flat since showActiveBg defaults off).
- [ ] **EditOverlay / WidgetPalette** — chip/tile hover+press states.
- [ ] **Bar** — SAFE only (bar is deliberately flat): smoother icon recolor curve,
  HoverCard enter/exit (done). Hover-fill / active-border need explicit sign-off.

## Dashboard follow-ups (user ideas 2026-07-20, after the hero+bento rework)
- **Customizable grid** — user-arrangeable dashboard with custom cards + choice of
  placement (cf. DankMaterialShell's drag-drop widget grid). The `DashCard` shell +
  bento GridLayout are a decent base; would need a config-driven card registry +
  placement persistence.
- **Pinnable projects** in the ActiveProjects card (pin/unpin like the launcher's
  pinned apps; pinned repos sort first).
- **Quote under the welcome text** — a rotating quote/line beneath the hero greeting
  (like the lockscreen's quote). (`tips.txt` / a quotes file + the existing tip picker.)

## Future ideas (user)
- **Flat vs glass as a setting** (user 2026-07-17): a config flag (e.g.
  `shell-config` `style: flat | glass`) toggling the sheen gradient vs a flat
  `fillColor` across surfaces. Cheap because the sheen is isolated to the
  `glassSheenTop`/`glassSheenBot` tokens + a `fillGradient` swap. Build once the
  glass look is dialed in and approved.
- **Named theme personalities** (40k / Star Wars / cyberpunk / Shadow Spear / …)
  as variants layered on the main liquid-glass base — LATER, not now.

## Deferred (over-eager in studies)
Scrubber drag-thumb, marquee hover-underline, per-cell calendar hover borders,
heavy shadows on every nested row, ripple-on-tap, elevation-tint token (add when
M3-dark elevation is designed), per-card dashboard stagger via Qt.callLater
(that API takes no delay arg — use a Timer if we do stagger).
