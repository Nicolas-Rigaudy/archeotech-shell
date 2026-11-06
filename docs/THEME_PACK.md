# Theme Packs (authoring reference)

A **theme pack** deeply reskins the shell's presentation without changing any
behaviour, keybinds, IA, or config semantics (adr_026 skin/structure boundary).
Packs are authored like widget plugins and distributed on the same rails.

This document covers **Layer A — the token overlay** and **Layer B — motion +
decorator/FX** (adr_027), which ship today. Component style-delegates and
pack-scoped settings arrive in later waves.

## Location

A pack is a directory under `$XDG_DATA_HOME` (freedesktop data convention):

```
~/.local/share/archeotech/packs/<pack-id>/
  pack.json     # manifest
  tokens.json   # token overrides (Layer A)
```

Bundled packs (`packs/`) are real packs only (Cyberdeck, Grimdark). The engine's test packs,
`angular` (recoloured base) and `hud` (glow, grid texture, window brackets, window
corner radius), live in `tests/fixtures/packs/` and never show in the pack picker;
`tests/py/test_pack_fixtures.py` keeps them loadable.

## `pack.json`

```json
{
  "id": "grimdark",
  "name": "Grimdark",
  "tier": "official",          // official | verified | community
  "minShellVersion": "0.3.0",  // versioned style-contract gate
  "inherits": "base",          // optional — parent pack id (not resolved yet)
  "wallpapers": "walls"        // optional — folder inside the pack holding its wallpapers
}
```

`wallpapers` names a folder inside the pack (relative; absolute paths and `..` are
ignored). While the pack is active, the wallpaper pickers offer only its
jpg/png/webp files that suit the mode (plus the wallpaper on screen), labelled with
the pack's name; **Show all** adds the user's own (`~/.config/archeotech/wallpapers`).
A mode the pack ships nothing for (light, for a dark-only pack) gets the user's
wallpapers as usual. They leave the pickers when the pack changes.
Wallpapers that can't ship with a pack (franchise art you keep for yourself) go in
`~/.local/share/archeotech/pack-wallpapers/<pack id>/` (subfolders included, a
symlink to a folder elsewhere works): the pickers count them as the pack's, for
any pack whose id is letters, digits, `-` and `_`, even one that ships none. Keep their file names unique across subfolders.
Record each image's origin and licence in the folder's `CREDITS.md`. A pack
wallpaper that is on screen stays there after a switch to another pack (as any
applied wallpaper does) until the next pick or mode flip. Like `tokens.json`,
wallpapers are not gated on `minShellVersion`; only style delegates are.

## `tokens.json` — the overlay

Every key is **optional**. Precedence at each lookup is:

**active pack `tokens.json` › base `theme.json` › built-in fallback.**

Because the reactive `Appearance` singleton reads through this overlay, setting a
token repaints the whole shell live — no per-component work.

```json
{
  "accent": "red",                     // a PALETTE COLOUR NAME (not a hex)
  "colors": {                          // any palette key below may be overridden
    "base": "#2a0e12", "mantle": "#1f0a0d", "crust": "#160709",
    "surface0": "#4a1620", "surface1": "#5e1d29", "surface2": "#742734",
    "text": "#ffe6cf", "subtext1": "#e8b9a0", "subtext0": "#...",
    "overlay0": "#...", "overlay1": "#...", "overlay2": "#...",
    "mauve": "#...", "blue": "#...", "sapphire": "#...", "sky": "#...",
    "teal": "#...", "green": "#...", "yellow": "#...", "peach": "#...",
    "maroon": "#...", "red": "#...", "pink": "#...", "flamingo": "#...",
    "rosewater": "#...", "lavender": "#..."
  },
  "roles": {                           // which slot each text role uses (see THEME_SPEC)
    "textPrimary": "text", "textSecondary": "subtext1", "textMuted": "overlay1"
  },
  "radius":  { "sm": 2, "base": 2, "md": 3, "lg": 4, "xl": 5, "pill": 999 },
  "spacing": { "xs": 4, "sm": 6, "base": 8, "md": 10, "lg": 12, "xl": 16 },
  "font":    { "family": "monospace",
               "sizeSm": 11, "sizeBase": 12, "sizeMd": 13,
               "sizeLg": 14, "sizeXl": 16, "sizeIcon": 16 },
  "bar":     { "height": 30, "marginTop": 0, "marginSide": 0, "innerPadding": 4 },

  "frame":   { "cornerRadius": 4 },    // Layer B — always-visible frame/strip
                                       // corner connections. Overrides the user's
                                       // Settings→Shell corner value (theme wins;
                                       // user value is the fallback with no pack).

  "window":  { "cornerRadius": 0, "borderWidth": 2 },   // the theme reaching the
                                       // REAL windows: drives mango's border_radius
                                       // + borderpx (applied live on pack switch;
                                       // restored to 12/2 on base). Omit ⇒ base.

  "anim":    { "fast": 100, "base": 200, "panel": 240,
               "effectsFast": 150, "effectsMed": 200, "effectsSlow": 300,
               "spatialFast": 350, "spatialDefault": 500, "spatialSlow": 650,
               "enter": 400, "exit": 200 },   // Layer B — motion durations (ms)
  "curve":   { "standard": [0.2,0,0,1,1,1] }  // Layer B — any M3 bezier ctrl-pt
                                              // list may be overridden (see
                                              // Appearance.qml `curve` for keys)
}
```

A pack that ships its own `colors` should declare `roles`; `scripts/contrast-check.py`
tests them against the pack's colours and again for each register, using that
register's own `accent` and `roles` when it sets them.

A register (`registers.<name>` in `tokens.json`) deep-merges over the pack base
and may override any token block (`accent`, `colors`, `roles`, `material`,
`frame`, `radius`, `window`, `anim`, `bar`, `fx`, `font`); nested blocks merge
key by key. Cyberdeck's three registers (megacorp,
netrunner, deck) each carry their own palette, material and corner set; the
base block is the default register (`defaultRegister`). `scripts/golden.sh`
scenarios take an optional 6th `set` field, so one scenario per register can
pin it with `packs.<id>.register=<name>`.

Notes:
- **Own palette**: a pack MAY override the whole `colors` block, not just the
  accent — a strongly-themed pack (e.g. a grimdark 40K identity) can carry its own
  scheme where the base's modern palette is off-identity. Keep it coherent.
- **Display font hook** (adr_027 / item_083): `font.displayFamily` (an installed
  family) or `font.displayFile` (a pack-relative `.ttf`/`.otf` loaded via
  FontLoader) sets a header/display face; body text stays the mono base for
  legibility. Read as `Appearance.font.display`. Ship open (OFL) fonts only.
- **Data face and display options** (shell 0.5.0): `font.monoFile` loads a
  pack-relative mono for readouts (`Appearance.font.mono`); `font.displayCaps`
  sets display text (settings pane titles, dashboard greeting) in capitals;
  `font.trackingDisplay` sets its letter spacing; `font.clockFace: "display"`
  draws time readouts in the display face instead of the mono.
- **Extra roles** (shell 0.5.0): `roles.clock` (dashboard clock, default
  accent), `roles.barClock` (bar clock, default text) and `roles.sectionLabel`
  (settings section captions, default overlay1) name a palette slot. Section
  captions read `sectionLabel`, so overriding only `textMuted` no longer
  recolours them.
- **Bar clock and seams** (shell 0.5.0): `bar.clockSize` (time px, 0 = the
  base size), `bar.dateFace` (`display` | `mono`), `bar.dateCaps` (bool), and
  `bar.grooves` (false drops the full-height grooves between zones that
  `bar.dividers` draws, for packs whose segments stand on their own).
- **Launcher captions and hints**: `launcher.captionPrefix` (string put before
  the RECENTS caption, e.g. `"// "`), `launcher.captionFace` (`display` |
  `mono`) and `launcher.hints` (`keycap` draws the footer key hints as raised
  keys, `bracket` as `[KEY] LABEL` text in the `sectionLabel` colour).
- **List bullets**: `list.bullet` (`dot` | `slant`) shapes the dashboard
  Active Projects bullets; `slant` is a sheared bar.
- **Side strips**: `strip.iconStride` (48), `strip.padLong` (10) and
  `strip.iconMargin` (9) set the icon slot along a strip, the padding at each
  end and the clearance around the icon cell; a pack whose `StripButton`
  housing fills the slot widens them (Cyberdeck: 60 / 16 / 12).
  `strip.panelCutInset` (0) is the extra top space a strip panel's content
  leaves under a `PanelChrome` corner cut (Cyberdeck: 12, settings search).
  These tokens apply whether or not the pack ships those delegates; set them
  together with the delegate they make room for.
- `accent` names one of the palette colours (e.g. `"red"`); the semantic
  `accent`, `accentBorder`, `accentAlpha`, state tints and accent-warmth surfaces
  all derive from it, so one line re-tints the whole accent system.
- Glass sheen / card / warmth surfaces are derived from `mantle`/`surface0`/the
  accent, so overriding those base colours cascades through the glass look.
- `anim`/`curve` keys retune motion shell-wide — every component reads these
  tokens, so a pack changes the whole shell's feel with no per-component work.

## `tokens.json` — `surfaces` (per-role surface recipes)

A recipe says HOW one surface role is drawn; core primitives read these values
and never ask which pack is active (item_112). Every key is optional: unset keys
keep the glass default. Colours are a palette/role name (`"accent"`,
`"glassBorder"`, `"copperLit"`), a group token (`"steel.hi"`) or a literal
(`"#05080d"`), with optional modifiers: `"accent+1.25"` = `Qt.lighter(accent, 1.25)`,
`"steel.lo-1.5"` = `Qt.darker`, `"peach/0.32"` = that colour at alpha 0.32 (a
trailing `+`/`-`/`/` and number is always read as a modifier).
Gradient `stops` are three `[position, colour]` pairs.

| role | drawn by | keys (default) |
|------|----------|----------------|
| `popup` | bar hover/click popups (PopupSurface) | `sheen` `"screen"` (screen-mapped glass) or `"local"` (each card its own plate), `stops` (glass sheen), `strokeWidth` 0, `strokeColor`, `collar` false (ConsoleChrome on the bar edge), `padTop` 0 |
| `panel` | bar panel card + strip popup card | `sheen`, `stops`, `strokeWidth`, `strokeColor` (as popup) |
| `selector` | SegmentedControl | `trackRadius` -1 (= `radius.base`), `trackColor` `"recessedTrack"`, `trackBorderWidth` 0, `trackBorderColor`, `innerShadow` false, `keyRadius` -1, `keyBorderWidth` 0, `keyBorderColor`, `keyStops` [] (= accent sheen), `keyShadow` `"soft"` or `"seat"`, `seatColor` `"crust"`, `keyText` `"base"` |
| `choice` | theme family cards | `radius` -1 (= `radius.md`), `softShadow` true, `borderOn` 3, `borderOff` 1, `borderOnColor` `"accent"`, `borderOffColor` `"glassBorder"`, `stops` [] (= card sheen) |
| `key` | raised key behind strip icons (BarPill) | `stripShadow` true |
| `button` | GlassButton | `activeText` `"base"` (label on an active button), `chamfer` false (handed to a GlassButton delegate as `api.colors.chamfer`) |
| `segment` | bar clusters housed in a `BarSegment` style | `pad: { clock, title, workspaces, mediaLead, mediaTail, bank }` (26, 14, 16, 4, 16, 10) |

Structure beyond values (a steel plate, bolted hardware, rivets) is a style
delegate, not a recipe: see Layer C below. `fx.rails.cornerPlates: true` adds
the raised steel corner plates to a pack that draws frame rails.

## `tokens.json` — `fx` (Layer B decorator/FX)

Optional ADDITIVE overlays drawn once over the frame chrome (never per-widget).
Every effect is off unless declared; with no pack the base look is untouched.
Colour fields accept a palette name (`"accent"`, `"mauve"`, …) or a literal
colour.

```json
{
  "fx": {
    "texture":  { "source": "textures/weave.png", "opacity": 0.10 },
    "glow":     { "enabled": true, "color": "accent", "strength": 0.45, "size": 40 },
    "brackets": { "enabled": true, "color": "accent", "length": 28, "thickness": 3, "inset": 8, "radius": 12 }
  }
}
```

- **texture** — a pack-relative image tiled over the four frame bands (the content
  hole stays clean). `opacity` keeps it subtle.
- **glow** — an accent rim glow hugging the content-hole edge, `strength` (0–1
  alpha) and `size` (px falloff).
- **ornaments** — pack-supplied SVG/PNG art placed at frame anchors (adr_027 /
  item_083): `fx.ornaments: [{ source, anchor, size, opacity }]`. `anchor`
  `"corners"` places art at all four content-hole corners, auto-rotated so a
  graphic drawn for the top-left hugs each corner (also `top-left`/`top-right`/
  `bottom-left`/`bottom-right`). Use for gothic filigree, sigils, framing — ship
  **open / non-IP** assets only. SVG renders via Qt's svg plugin.
- **brackets** — HUD corner brackets drawn at **every window's** corners (live
  from compositor client geometry, not just the screen corners). `length`/
  `thickness`/`inset` shape them, `radius` rounds the bend (0 = sharp; match your
  `window.cornerRadius` so brackets and windows agree). Focused window's brackets
  read full-strength, unfocused dim back — so with `window.borderWidth: 0` the
  brackets alone carry focus indication (no window border needed).

## Activation

The shell reads the active pack from the persisted key
`appearance.activePack` (empty string = base look, no overlay). A GUI selector
in the Settings / Plugin Manager arrives with pack discovery; for now it is a
config value.

## `pack.json` — `configSchema` (Layer D pack settings)

A pack may expose its own settings in **Settings → Appearance → Pack Settings**
(shown only while the pack is active). Declare a `configSchema` in `pack.json`
using the shared ConfigForm shape, keyed by the **dotted token path the setting
overrides** — so the control drives the real look, no extra wiring:

```json
{
  "configSchema": {
    "fx.glow.strength":    { "type": "real", "label": "Glow strength", "min": 0, "max": 1, "step": 0.05, "default": 0.6 },
    "fx.brackets.enabled": { "type": "bool", "label": "Window brackets", "default": true },
    "window.cornerRadius": { "type": "int",  "label": "Window corner radius", "min": 0, "max": 16, "unit": "px", "default": 0 }
  }
}
```

- Field `type` ∈ `bool` (toggle), `int`/`real` (slider), `enum` (`options` →
  buttons/dropdown), `string` (text field).
- Set `default` to match the pack's `tokens.json` value so the control starts at
  the pack's own look.
- Values persist under Config `packs.<id>` and **override the matching token
  path** in the pack's data (colours, tokens, `fx.*`, `window.*` all honoured) —
  live, via the same reactive getters. Component style-delegates (Layer C) also
  receive pack state, so a delegate can read settings through its `api`.

## Component style delegates (Layer C)

To replace a component's *visual* wholesale (beyond tokens), ship
`<packDir>/styles/<ComponentId>.qml` — see **docs/STYLE_API.md** for the curated
set and the versioned `api` contract.
