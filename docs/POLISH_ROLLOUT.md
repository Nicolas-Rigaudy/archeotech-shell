# Polish & Liveliness — shell-wide rollout

Follows the Launcher taste-test slice (commit `556bc3a`, ANALYSIS.md §18). The
Launcher is the quality bar. Rolled out in feel-gated rounds (apply → live-test
via Super+Shift+R → commit on confirm), grouped by shared recipe.

## Shipped so far (as of 2026-07-20)
- ✅ **Launcher** — StateLayer hover, warmth, depth, two-line rows (`556bc3a`).
- ✅ **Chrome liquid-glass sheen** — subtle vertical gradient on frame / strip &
  bar-panel cards / OSD / popups (`glassSheenTop`/`glassSheenBot` tokens).
- ✅ **Strip-card seam fix** — window-space mapped sheen (`5695ace`).
- ✅ **Dashboard rework** — hero + bento, `DashCard` shell, warm translucent
  `surfaceCard` cards (`4a99325`).
- ✅ **Shared card style unified on `surfaceCard`** — launcher tiles + search
  field moved off `surfaceWarm` onto the dashboard/notif `surfaceCard` + shadow
  (0,4)/0.45 so all cards read identically (`bd6abfe`).
- ✅ **Notifications** (toast + notification center) — screen-space glass sheen,
  `surfaceCard` history rows + shadow, 24px icons, two-line layout, `StateLayer`
  header/dismiss/close buttons, trash-can clear-all, toast enter/exit asymmetry
  (`717b2be`, `b7a9f29`, `710ccc5`, `8a46a94`); clear-all root-cause fix (`a11cc62`).
- ✅ **Round 3 — Settings** — full redesign onto shared `GlassButton`/`SettingsCard`/
  3D toggle/stat-bar slider; every pane unified (see Round 3 below). Reload script fixed.
- ✅ **Accent swatches → raised 3D dots** — sibling shadow + top-lit sphere gradient +
  hover-scale 1.08 / press-pulse 0.92 (toggle-knob recipe), selection ring kept (`ColorSchemeBody`).
- ✅ **Flat-mode toggle** (Settings→Appearance→Style) — `Appearance.flatMode` +
  `shadowStrength` tokens flatten the sheen gradient, `surfaceCard` (translucent,
  un-tinted — NOT opaque, per user 2026-07-31), and shared-primitive shadows
  (`GlassButton`/`SettingsCard`/`DashCard`). Default glass; persisted `appearance.flatMode`.
  **Extends per-surface as each is migrated** — a surface only responds to flat
  mode once its sheen/shadows route through these tokens, so the un-migrated
  Round-1/4 surfaces (popups, media, edit-mode, strip/bar openers) stay glassy
  until then. (Gotcha fixed: `_c()` returns a hex STRING → `Qt.rgba(str.r,…)` is
  solid black; go through `_rgba()`.)
- ▶ **NEXT:** Edit Layout buttons, then a full Settings design pass.

Working rhythm that stuck: pilot on ONE surface → user live-tests → tune → commit.
Cannot `qmllint` `Dashboard.qml` (pre-existing 255 from the panels-dir import);
lint the individual card files instead.

## Main style: modern minimalist "liquid glass" (decided 2026-07-17)
The DEFAULT aesthetic is modern, minimalist, translucent frosted glass. Named
theme *personalities* (Warhammer 40k, Star Wars, cyberpunk, …) come LATER as
theme variants on top of this foundation — don't build them yet.

**Liquid glass — SHIPPED approach: a subtle vertical SHEEN GRADIENT** (no blur, no
transparency change). `glassSheenTop`/`glassSheenBot` tokens (`Commons/Appearance.qml`)
give chrome a top-lit gradient fill instead of flat glass — on `FrameBackground`,
the strip & bar-panel cards, OSD, and popups. `glassBg` stays 0.96.

Dead ends (tried and reverted — don't redo without a new idea):
- **Compositor frost** (`blur_layer=1` + lowered `glassBg` alpha): SceneFX blurs the
  WHOLE transparent layer-surface region → banding/wash on our full-screen surfaces.
  Reverted; `blur_layer` stays 0, `glassBg` stays 0.96.
- **Specular top-edge rim** and **diagonal gradient**: both seam at every attach edge
  (surfaces have different coordinate origins). Plain vertical sheen is the only
  seamless option. A small surface low on screen reading ~uniform is CORRECT (single
  light source), not a bug.
- **Strip-card seam fix (kept):** strip cards map their sheen to WINDOW space
  (`mapToItem(null,0,0).y` + `screen.height`) because horizontal (top/bottom) strips
  aren't full-height, so `strip.height` ≠ screen height. `Window.height` reads 0 in
  Quickshell — use `screen.height`.

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
- [x] **Dashboard** — full rework: hero (greeting+clock+date), 2×2 bento + full-width
  tip strip, shared `DashCard` shell (translucent `surfaceCard` + `RectangularShadow`),
  ActiveProjects capped 4 rows + internal scroll. Cards `fillHeight` + `Layout.minimumHeight:
  implicitHeight` to align without shrink-overflow. **Phase 3 DONE:** StateLayer hover/press
  on QuickLaunch tiles & project rows; stat bars → sunk track + top-lit sheen fill (3d);
  width/height fill (QuickLaunch 4×2 fillHeight tiles; SystemNotes 2-col + uptime/kernel/host/ip).
  `DashCard.inner` now `fillHeight` so a card's content can opt into stretching. Follow-up
  features logged below (customizable grid, pinnable projects, hero quote, customizable +
  reliable System Notes).
- [x] **NotificationCenter + NotifToast** — DONE. Toast: chrome **glass sheen**
  (NOT surfaceWarm — a toast is chrome, kept the shared glass), 24px icon, two-line
  layout, StateLayer close, enter 400 decel / exit 200 accel. History rows: DashCard
  style (surfaceCard + shadow), 24px icon, StateLayer dismiss. Header: StateLayer
  icon buttons, trash-can clear-all. Per-index stagger skipped (over-eager; add later).
  Hard-won:
  - **Toast fill is chrome glass, not a warm card** — user rejected both surfaceWarm
    AND surfaceCard on the toast ("too purple"). Chrome cohesion rule wins: toast uses
    the `glassSheenTop/Bot` gradient like the OSD/frame. surfaceCard is for the *panel*
    history rows only.
  - **Screen-space sheen on the toast** — a local 0→1 gradient darkens the card's
    bottom; near the top of the screen that reads darker than the bar beside it. Sample
    the screen-scale gradient at the card's window-Y (`_mix(top,bot, winY/screenH)`),
    same principle as the strip cards. `Screen.height` (attached prop) works here.
    Widen the toast layer-surface window (+48 / margins 24) or the drop shadow clips hard.
  - **Toast exit before removal** — the host (`shell.qml`) splices the toast out of its
    array on dismiss/timeout → instant destroy, no exit anim. Fix stays in NotifToast:
    `_close()` sets `_closing`, animates `_progress→0`, and only emits the signal in
    `on_ProgressChanged` once it lands. Host untouched.
  - **clear-all was silently failing** — `_notif.dismiss()` throws on an already-expired
    notif, aborting the loop before `history=[]`. Empty the array FIRST, then best-effort
    dismiss each in try/catch. Same latent bug fixed in `dismiss(index)`.
  - Tooltips: the default QtQuick.Controls `ToolTip` is an ugly white rect — dropped it;
    icons (bell/bell-slash, trash-can) are self-explanatory. Style a glass tip if ever needed.

## Round 3 — settings controls + full Settings redesign (mostly DONE 2026-07-22)
Settings was taken well past the original checklist into a full unify-everything pass.

**New shared primitives (the Settings design language):**
- `Commons/Primitives/GlassButton.qml` — the unified button. Flat translucent
  `surfaceCard` resting + `glassBorder`, gentle top-lit gradient, soft drop shadow
  (blur 10 / (0,3) / 0.5), `StateLayer` press-depress. `active:` → accent-gradient
  fill (text→`base`). Default content slot for icon+label, or `text:`. Iterated hard:
  a heavy accent gradient + bright bevel read as "wet plastic" — depth comes from the
  SHADOW + a *gentle* gradient, no specular line.
- `Modules/Settings/Widgets/SettingsCard.qml` — group container = dashboard card
  language (`surfaceCard` + RectangularShadow, 16px padding). Rows as direct children.
- `ToggleSwitch` — DONE: recessed off-groove (dark-top→lit-bottom gradient) / raised
  accent-on track + shadowed knob (raised sphere gradient) + press-pulse.
- `SliderRow` — DONE: 8px sunk track + top-lit sheen fill (stat-bar language),
  handle 20px hover 1.08 / press 0.92.

**Unified across ALL panes** (buttons→GlassButton, group boxes incl. device/network
lists→SettingsCard, list rows/tabs→StateLayer, dividers `base`→`surface0`):
Notifications, Display, About, Plugins, Shell, Audio, Connections (WiFi/BT pills +
tabs→GlassButton), Appearance. Sidebar → translucent glass + StateLayer nav/results +
launcher-style search. Appearance `ColorSchemeBody` (shared w/ bottom switcher): mode
pills + flavor pills → GlassButton, theme family cards → shadow+gradient 3D. Plugins
built-in widgets → icon-card grid. About links → open-in-new glyph (was wifi-off).
Audio selected row → translucent accent gradient + border, inset 4px so it clears the
card edge.

**Hard-won (2026-07-22):**
- **Missing-import crash:** a pane using `GlassButton`/`StateLayer` without
  `import "../../../Commons/Primitives"` makes the WHOLE config fail to load → shell
  won't start, reloads do nothing. `qmllint` reports it as **"unqualified access"** —
  do NOT filter that out of lint checks (that's exactly what hid it). The running shell
  is the real proof it loads.
- **Reload script** (`archeotech-dotfiles/scripts/mango-reload.sh`): old `A || B || C`
  kill chain stopped at the first "success" → left survivors → duplicate bars stacked.
  Fixed: run every kill method + wait for exit before relaunch.
- **Don't run file-rewriting subagents on the live-reloaded tree** without care — a
  reload mid-write loads a half-file. Convert one pane fully, lint, then reload.
- qmllint can't fully resolve cross-dir types; the live shell (0 errors on launch) is
  the real check.

**Still open (next session):**
- [x] Accent color swatches → raised 3D dots (shadow + sphere gradient + hover/press scale).
- [ ] Edit Layout builder buttons (`EditOverlay`/`WidgetPalette`) → GlassButton/StateLayer.
- [ ] **Full design pass** over all of Settings — consistency, spacing, readability
  (use ui-ux-pro-max guidelines as a lens + multi-persona review).
- [ ] Automated screenshot + multi-persona playtest harness (roadmap idea, user 2026-07-22).

## Round 4 — strip + bar
- [ ] **Strip** openers — 44px rounded accent bg (statePressed active / stateHover
  hover), card scale-in 0.85→1, surfaceWarm card fill, holder-edge hover glow.
- [ ] Warm `BarPill` `showActiveBg` fill → statePressed/stateHover (only affects
  strip openers; bar stays flat since showActiveBg defaults off).
- [ ] **EditOverlay / WidgetPalette** — chip/tile hover+press states.
- [ ] **Bar** — SAFE only (bar is deliberately flat): smoother icon recolor curve,
  HoverCard enter/exit (done). Hover-fill / active-border need explicit sign-off.

## Design-pass plan — remaining "not-3D" surfaces (user list 2026-08-17)

Shared vocabulary (ALL shadows go through `shadowStrength`, so each surface
auto-gains flat-mode support the moment it's migrated):
- on-panel card → `surfaceCard` + soft `RectangularShadow`
- nested item (inside a card) → recessed `surface0Alpha`, no shadow
- button → `GlassButton` (shadow + states) or a `StateLayer` overlay
- selection / active → `accentAlpha` fill + `accentBorder` + accent text/glyph
- hover / press → `StateLayer` (scale + `stateHover`/`statePressed`)
- floating popup → keep the glass sheen; a lift needs a **shaped** shadow — the
  popups are neck `Shape`s, so a `RectangularShadow` pokes out at the neck. Build a
  Shape-based shadow helper ONCE and reuse across all bar popups.

**Progress (2026-08-17):** ✅ #1 strip icons (raised accent key), ✅ #2 bar-popup
**buttons** (wifi/bt raised) + **screen-space sheen** across Wifi/Bt/Calendar/BarPanel/
HoverCard (fixed the harsh local ramp). Still open on the popups: a **shaped drop
shadow** on the neck cards themselves (lift off content) — needs a Shape-based shadow,
deferred. Then #3 media, #4 settings-selection pill, #5 pickers, #6 tabs.

Two reusable wins:
- **Popups ARE headless-viewable** — direct-mount a popup in a `qs -p` harness with a
  stub `holderRoot` (`_wifiPopupVisible: true`, `side: "top"`, a `screen{height}`); no
  live bar/IPC needed. Same trick as the layout-picker body. (Extends testing Block 2.)
- **`ponytail:` debt** — the screen-space sheen (`_winY`/`_winH` + mapped gradient) is now
  copy-pasted in 6 cards (FrameBackground/Strip/BarPanel/Wifi/Bt/Calendar/HoverCard).
  Extract a shared `GlassSheen` helper so none drift back to a local ramp.

Feel-gated rhythm as before (one surface → `Super+Shift+R` → confirm → commit),
priority order:

1. **Strip widget icons — hover/active** (was Round 4). `PanelOpenerWidget` on a
   strip: 44px rounded cell, `stateHover` on hover, `accentAlpha` + accent glyph
   when its panel is active. Highest visibility (seen every session).
2. **Bar-popup buttons + popup lift** (was Round 1) — wifi/BT/calendar/power popups:
   action buttons → `GlassButton`, rows → `StateLayer`; AND give the popup card the
   shaped shadow (build the Shape-shadow helper here, reuse for all four).
3. **Music panel** (MediaPanel, was Round 1) — album-art/info as `surfaceCard`+shadow,
   transport buttons → `StateLayer`/GlassButton, progress bar like the 3D `SliderRow`.
4. **Settings section selection** — the sidebar ALREADY has `accentAlpha`+`StateLayer`;
   if it still reads flat, promote the selected row to a *raised pill* (surfaceCard/
   accent + subtle shadow + an accent left-bar) so selection pops, not just tints.
5. **Wallpaper / theme / logo pickers** — thumbnails are IMAGES → keep the border-ring
   highlight (do NOT shadow images — that's the "too much" trap). Add depth via a soft
   shadow under the **centered/active** carousel item only (the hero) + a crisper accent
   selection ring. Deliberately restrained.
6. **Appearance quick-switcher tabs** — selected tab is already `accentAlpha`; just add
   `StateLayer` hover + match the sidebar's selection style. Low effort.

**Power menu = wlogout (external).** NOT QML — a CSS/layout-themed external tool like
the lock screen. "3D" there is a **wlogout config-theming** task (palette-driven
generator, mirroring hyprlock), tracked separately from this QML rollout.

## Dashboard follow-ups (user ideas 2026-07-20, after the hero+bento rework)
- **Customizable grid** — user-arrangeable dashboard with custom cards + choice of
  placement (cf. DankMaterialShell's drag-drop widget grid). The `DashCard` shell +
  bento GridLayout are a decent base; would need a config-driven card registry +
  placement persistence.
- **Pinnable projects** in the ActiveProjects card (pin/unpin like the launcher's
  pinned apps; pinned repos sort first).
- **Quote under the welcome text** — a rotating quote/line beneath the hero greeting
  (like the lockscreen's quote). (`tips.txt` / a quotes file + the existing tip picker.)
- **Customizable System Notes** (user 2026-07-21) — let the user choose which stats
  show in the SYSTEM NOTES card (snapshot/updates/vpn/aws/uptime/kernel/host/ip/…),
  config-driven like `dashboard.scanRoots`. Card already renders a generic 2-col
  NoteRow grid — would need a config key + a per-stat fetch registry.
- **System Notes data reliability (PRE-1.0)** — the newer stats (uptime/kernel/host/ip)
  are solid; the original left-column ones are flaky and need a hardening pass before
  1.0 (pairs with customizable-notes: only surface sources that resolve):
  - *AWS* — `$AWS_PROFILE` isn't inherited by the Quickshell process; nearly always
    "unset". Needs a real source (read `~/.aws/config` current profile, or a login-shell env).
  - *Snapshot* — parser wants a dated snapper row; returns N/A when only `#0 current`
    exists. Handle the no-timeline-snapshots case.
  - *VPN* — `awk '/vpn/'` on `nmcli --active` is fragile; match on TYPE (wireguard/vpn/tun)
    instead of a substring.
  - *Updates* — `checkupdates` syncs a temp DB (slow/network-dependent) + async count;
    finicky. Consider caching / a loading state.

## Future ideas (user)
- **Flat vs glass as a setting** (user 2026-07-17): a config flag (e.g.
  `shell-config` `style: flat | glass`) toggling the sheen gradient vs a flat
  `fillColor` across surfaces. Cheap because the sheen is isolated to the
  `glassSheenTop`/`glassSheenBot` tokens + a `fillGradient` swap. Build once the
  glass look is dialed in and approved.
- **Named theme personalities** (40k / Star Wars / cyberpunk / Shadow Spear / …)
  as variants layered on the main liquid-glass base — LATER, not now.
- **Gradient / liquid-glass sheen on nested cards** (user 2026-07-21) — try the
  `glassSheenTop`/`glassSheenBot` gradient (or a softer variant) on `DashCard`/
  `SettingsCard`/notif cards to see if cards want the sheen treatment too, not just
  flat `surfaceCard`. Experiment once the flat card language is settled.

## Deferred (over-eager in studies)
Scrubber drag-thumb, marquee hover-underline, per-cell calendar hover borders,
heavy shadows on every nested row, ripple-on-tap, elevation-tint token (add when
M3-dark elevation is designed), per-card dashboard stagger via Qt.callLater
(that API takes no delay arg — use a Timer if we do stagger).
