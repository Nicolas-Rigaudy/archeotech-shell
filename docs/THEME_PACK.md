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

## `pack.json`

```json
{
  "id": "shadow-spears",
  "name": "WH40K Shadow Spears",
  "tier": "official",          // official | verified | community
  "minShellVersion": "0.3.0",  // versioned style-contract gate
  "inherits": "base"           // optional — parent pack id (not resolved yet)
}
```

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

  "anim":    { "fast": 100, "base": 200, "panel": 240,
               "effectsFast": 150, "effectsMed": 200, "effectsSlow": 300,
               "spatialFast": 350, "spatialDefault": 500, "spatialSlow": 650,
               "enter": 400, "exit": 200 },   // Layer B — motion durations (ms)
  "curve":   { "standard": [0.2,0,0,1,1,1] }  // Layer B — any M3 bezier ctrl-pt
                                              // list may be overridden (see
                                              // Appearance.qml `curve` for keys)
}
```

Notes:
- `accent` names one of the palette colours (e.g. `"red"`); the semantic
  `accent`, `accentBorder`, `accentAlpha`, state tints and accent-warmth surfaces
  all derive from it, so one line re-tints the whole accent system.
- Glass sheen / card / warmth surfaces are derived from `mantle`/`surface0`/the
  accent, so overriding those base colours cascades through the glass look.
- `anim`/`curve` keys retune motion shell-wide — every component reads these
  tokens, so a pack changes the whole shell's feel with no per-component work.

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
- **brackets** — HUD corner brackets at the content-region corners; `length`/
  `thickness`/`inset` shape them, `radius` rounds the bend (0 = sharp; match your
  window corner rounding so they echo the windows rather than clash). Note: this
  frames the whole tiled content region (4 corners), not each window.

## Activation

The shell reads the active pack from the persisted key
`appearance.activePack` (empty string = base look, no overlay). A GUI selector
in the Settings / Plugin Manager arrives with pack discovery; for now it is a
config value.

## Not yet shipped

Per-component style delegates (`minShellVersion`-gated) and pack-scoped
`configSchema` settings are specified in adr_027 Layers C–D and land in later
waves.
