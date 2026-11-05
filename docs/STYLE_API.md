# Component Style Delegates (Layer C — versioned contract)

adr_027 Layer C. A **curated** set of load-bearing components delegate their
**visual chrome** to a theme pack, while keeping their behaviour, properties,
slots and interaction in the base component. This is the theming engine's
**versioned public API for pack authors** — kept deliberately small, expanded
carefully.

Layers A/B (tokens, motion, decorator/FX, window chrome) already reskin the
whole shell with no code. Reach for a style delegate ONLY when a pack must change
a component's *structure* beyond what tokens allow (e.g. a flat sharp dataslate
button instead of the glass one).

## How it works

A pack ships a delegate at, by filename convention:

```
<packDir>/styles/<ComponentId>.qml
```

`PackRegistry` discovers these at scan time (`styles: [...]` on the pack), gates
them by the pack's `minShellVersion` against `Appearance.shellVersion`, and
`shell.qml` pushes the compatible id list onto `Appearance.activePackStyles`. A
curated component embeds a `StyleDelegate { componentId: "<Id>"; api: {...} }`:

- no delegate for this id (or pack incompatible) ⇒ `StyleDelegate.active === false`
  and the component draws its **base visual** (packs are purely additive; the
  base always works),
- a delegate present ⇒ it loads and receives one property, **`api`** — an object
  the host fills with the state the visual needs.

The delegate is **chrome only**. It must NOT import `Commons` (it lives outside
the shell tree) — every value it needs, including theme colours, arrives through
`api`. Interaction (StateLayer, click, press-scale) and content stay in the base
component, layered above the delegate.

## Versioning

Colours in `api.colors` are semantic: `api.colors.text` is the label colour for the
control (the `textSecondary` role on GlassButton), so it follows each theme's
contrast-checked role map rather than a fixed palette step.

`api` is a single object, not N positional props, so the contract can gain new
fields without breaking older delegates. **Add fields; never remove or repurpose
them.** A pack declares the minimum contract it needs via `minShellVersion` in
`pack.json`; if the running shell is older, its delegates are ignored (base
visuals stand) and a warning is logged. `Appearance.shellVersion` is the current
version.

## Delegate skeleton

```qml
import QtQuick
Item {
    property var api: ({})
    Rectangle {
        anchors.fill: parent
        color: api.active ? api.colors.accent : "transparent"
        border.color: api.colors.border
    }
    // …your chrome, reading only from `api`…
}
```

## Curated components & their `api`

The set is intentionally small; entries are added as real packs need them.

### `GlassButton`
| field | type | meaning |
|-------|------|---------|
| `active` | bool | selected/on state |
| `hovered` | bool | pointer over |
| `pressed` | bool | pointer down |
| `text` | string | the button label (already drawn by the base content layer) |
| `radius` | int | the base corner radius token |
| `colors` | object | `{ accent, surface, border, text, base, teal, steelHi, steelMd, steelLo, steelEdge, steelLip, chamfer }`: live theme colours, the plate tones, and whether the pack cuts chamfered corners (`frame.corners`) |

Every delegate below also receives `palette` (the live `Appearance.colors`
object: read `api.palette.peach`, `api.palette.copperLit`, …) and `steel` (the
stable chassis ramp `Appearance.steel`: `hi md lo edge lip`, set by the pack's
`panels.steel`, so any pack can define its own plate tones there). Read them through
a guard (`api.palette ? api.palette.x : "transparent"`): `api` is `{}` for the
first binding pass. A delegate may reuse a sibling delegate of the same pack
(same directory), e.g. a `BarSegment` built from the pack's `MetalSurface`.

### `MetalSurface`
Card/panel/tooltip/tray-menu background. A loaded delegate replaces the whole
visual; the host exposes `styled: true`, and hosts drop their own glass rim.

| field | type | meaning |
|-------|------|---------|
| `radius` | real | host corner radius |
| `chamfer` | int | corner cut the host asks for (clamp to half the smaller side) |
| `seatOpacity` | real | weight of a recessed seat outline (0..1) |
| `topLit` | bool | raised top highlight (false for flush bar housings) |
| `crisp` | bool | no anti-aliasing (edge meets nothing under layer blur) |
| `color` | color | the host's fallback fill |

### `ConsoleChrome`
Hardware drawn over popup and panel cards where they fasten to the bar/strip.
Core draws nothing without a delegate.

| field | type | meaning |
|-------|------|---------|
| `attachSide` | string | `top` `bottom` `left` `right`: the edge on the bar/strip |
| `radius` | real | card corner radius |
| `showCollar` / `showTrim` / `showGussets` | bool | which parts the host wants |
| `inset` | real | trim inset from the card edge |
| `specular` | real | `Appearance.opacity.specular` |

### `BarSegment`
Housing behind one bar cluster. Core draws nothing without a delegate, and bar
layouts pad their clusters (`surfaces.segment.pad`) only when the pack ships one.

| field | type | meaning |
|-------|------|---------|
| `chamfer` | int | corner cut |
| `vMargin` | int | top/bottom inset from the bar edges |

### `BarDivider`
Hardware on the console's zone seams (`bar.dividers`). The core draws the groove;
the delegate sits on the groove's x with the bar's height and zero width. No
fields beyond the shared ones.

_(More components (DashCard, SegmentedControl, BarPill, PanelShadow, a form Row)
are added here as they gain delegate seams.)_
