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
| `colors` | object | `{ accent, surface, border, text, base }` — live theme colours |

_(More components — DashCard, SegmentedControl, BarPill, PanelShadow, a form Row
— are added here as they gain delegate seams.)_
