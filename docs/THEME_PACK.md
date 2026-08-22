# Theme Packs (authoring reference)

A **theme pack** deeply reskins the shell's presentation without changing any
behaviour, keybinds, IA, or config semantics (adr_026 skin/structure boundary).
Packs are authored like widget plugins and distributed on the same rails.

This document covers **Layer A — the token overlay** (adr_027), which is what
ships today. Decorator/FX, motion overrides, component style-delegates, and
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
  "bar":     { "height": 30, "marginTop": 0, "marginSide": 0, "innerPadding": 4 }
}
```

Notes:
- `accent` names one of the palette colours (e.g. `"red"`); the semantic
  `accent`, `accentBorder`, `accentAlpha`, state tints and accent-warmth surfaces
  all derive from it, so one line re-tints the whole accent system.
- Glass sheen / card / warmth surfaces are derived from `mantle`/`surface0`/the
  accent, so overriding those base colours cascades through the glass look.

## Activation

The shell reads the active pack from the persisted key
`appearance.activePack` (empty string = base look, no overlay). A GUI selector
in the Settings / Plugin Manager arrives with pack discovery; for now it is a
config value.

## Not yet in Layer A

Motion (`anim`/`curve`) overrides, decorator/FX overlays, per-component style
delegates (`minShellVersion`-gated), and pack-scoped `configSchema` settings are
specified in adr_027 Layers B–D and land in later waves.
