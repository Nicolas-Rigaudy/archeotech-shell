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
The FrameStyle, ScreenEffects, CardHeader, SegmentedControl, RowSelection and
StripButton seams, and BarSegment's `cluster`/`vertical`, need `0.4.0`.
The GaugeFace, WorkspaceCell, PanelChrome and LaunchTile seams, the
`register` property, and the `sectionLabel`/`clock`/`barClock` roles and font
tokens they lean on need `0.5.0`.

A delegate that declares `property string register` receives the active pack
register (`Appearance.activeRegister`, e.g. Cyberdeck `netrunner`), so one
`styles/` directory can draw every register without importing Commons.

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
| `cluster` | string | which housing: `bank` (the status bank), `clock`, `workspaces`, `title`, `media` |
| `vertical` | bool | the bar runs down a left/right edge |

### `BarDivider`
Hardware on the console's zone seams (`bar.dividers`). The core draws the groove;
the delegate sits on the groove's x with the bar's height and zero width. No
fields beyond the shared ones.

### `FrameStyle`
The whole frame (bands + corners) on each screen, drawn over the core glass
(z 1, beside FrameFx). Without `replacesGlass` the delegate is an overlay; set
`property bool replacesGlass: true` on the delegate's root to blank the core glass
fill and paint the frame body yourself. The compositor blurs wherever the layer's
alpha is above 0, so a body painted fully transparent loses the frame blur: keep
some alpha where blur should show.

| field | type | meaning |
|-------|------|---------|
| `contentRect` | rect | the content hole (where windows show) |
| `cornerRadius` | real | the hole's corner radius |
| `framePath` | string | SVG path of the frame shape (outer rect minus the hole), for a `PathSvg` |
| `chamfer` | bool | the pack cuts corners at 45° (`frame.corners: "chamfer"`) |
| `bands` | object | `{ top, bottom, left, right }`: band thickness in px |
| `screenName` | string | output name |
| `palette` / `steel` | object | `Appearance.colors` / `Appearance.steel` |

### `ScreenEffects`
A full-screen overlay above the bar and strips (z 11, below edit mode); never
takes input, and hides with the frame when the sides auto-hide. Scanlines, vignette, glitch bursts. **Never paint inside
`contentRect`**: the compositor blurs wherever the layer's alpha is above 0, so
anything drawn over the hole blurs the windows under it.

| field | type | meaning |
|-------|------|---------|
| `contentRect` | rect | the content hole (keep it clear) |
| `level` | string | the pack setting `screenEffects` (the pack defines the values; `""` unset) |
| `animate` | bool | false under reduced motion: draw a still frame |
| `palette` | object | `Appearance.colors` |

### `CardHeader`
A dashboard card's title row (`Prim.CardHeader`, used by DashCard). The base draws
the accent title over a divider; with a delegate the row takes the delegate's
`implicitWidth`/`implicitHeight`, so a tab or label plate can be taller. The
delegate must set `implicitHeight` (the row collapses to 0 without it).

| field | type | meaning |
|-------|------|---------|
| `title` | string | card title |
| `code` | string | optional short code; no host sets one yet, so `""` today |
| `font` | object | `{ display, size, tracking }`: the base title font |
| `palette` | object | `Appearance.colors` |

### `SegmentedControl`
The selector's track and selected key. With a delegate the core track, seat,
shadows, pill and hover wash are hidden; the labels and hit areas stay core.
Optional delegate properties `activeText` / `idleText` (colors) recolour the
selected and other labels to suit the key.

| field | type | meaning |
|-------|------|---------|
| `count` | int | number of segments |
| `currentIndex` / `hoveredIndex` | int | selected / hovered segment (`-1` none) |
| `vertical` | bool | segments stack vertically |
| `segmentSize` | real | one segment's length along the track |
| `keyRect` | rect | where the core pill would sit (animated between segments) |
| `enabled` | bool | control enabled |
| `radius` | real | track corner radius |
| `palette` | object | `Appearance.colors` |

### `RowSelection`
The selected-row highlight in lists (`Prim.RowSelection`). The host hides its own
highlight while the delegate is active. Optional delegate property `selectedText`
(color) recolours the selected row's text. In `launcher` there is one instance
(the moving highlight) and `selected` is always true. In `settingsNav` every row
has one and the host drops its own hover pill, so the delegate draws hover too.

| field | type | meaning |
|-------|------|---------|
| `context` | string | which list: `launcher`, `settingsNav` |
| `selected` | bool | this row is the current one |
| `hovered` | bool | pointer over the row |
| `radius` | real | host row radius |
| `palette` | object | `Appearance.colors` |

### `StripButton`
Housing behind each strip icon (key cap, socket, bracket), under the widget.
When a pack ships one, panel openers drop their lifted accent cell
(`Strip.buttonStyled`), so the delegate draws the active and hover states.

| field | type | meaning |
|-------|------|---------|
| `side` | string | strip edge: `top` `bottom` `left` `right` |
| `index` | int | slot position on the strip |
| `widgetId` | string | the widget in this slot |
| `active` | bool | this slot's panel is open |
| `hovered` | bool | pointer over the slot |
| `activePanel` | string | the strip's open panel id (`""` none) |
| `panelOpen` | bool | any panel of this strip is open |
| `palette` | object | `Appearance.colors` |

### `GaugeFace`
The dashboard System Status gauges (`SystemStatusGauges`). When a pack ships one,
the host hides its bars and the delegate draws the whole face (labels, meters,
readouts); its `implicitHeight` sizes the card.

| field | type | meaning |
|-------|------|---------|
| `stats` | array | `[{ label, value, kind }]`: `value` 0..100 (percent); `kind` `cpu` `ram` `disk` `bat` (`bat` below 0 means no battery: skip it) |
| `palette` | object | `Appearance.colors` |
| `font` | object | `Appearance.font` (`display`, `mono`, `clock`…) |

### `WorkspaceCell`
One workspace marker in the bar `Workspaces` widget, replacing the base dot.
Its `implicitWidth`/`implicitHeight` size the cell; the click area stays in the
host.

| field | type | meaning |
|-------|------|---------|
| `selected` | bool | the focused workspace |
| `occupied` | bool | holds windows |
| `urgent` | bool | has an urgent window |
| `index` | int | the workspace number (1-based) |
| `vertical` | bool | the bar runs down a left/right edge |
| `animMs` | int | size-change duration, already scaled by anim speed and reduce motion (`Appearance.anim.spatialFast`) |
| `palette` | object | `Appearance.colors` |

### `PanelChrome`
The body of a panel card that grows out of a strip (`Strip.qml`). The host drops
the fill gradient and stroke of its whole outline while the delegate is active,
the corner fillets toward the strip included, so the delegate paints the body
inside `bodyRect` and the fillet area stays empty.

| field | type | meaning |
|-------|------|---------|
| `side` | string | strip edge: `top` `bottom` `left` `right` |
| `bodyRect` | rect | the card body, without the fillets toward the strip |
| `panelOpen` | bool | a panel of this strip is open |
| `palette` | object | `Appearance.colors` |

### `LaunchTile`
Housing for launch surfaces: dashboard Quick Launch tiles and the launcher's
recents tiles, search box and result rows, and the settings sidebar search
box (`search` context). The host drops its own fill and
border while the delegate is active. Optional delegate properties read back by
the host: `glyph` (string, the search prompt glyph) and `leadInset` (int, a lead
gutter in px before a result row's icon, e.g. for an index).

| field | type | meaning |
|-------|------|---------|
| `context` | string | `tile` (Quick Launch), `recent`, `search`, `row` |
| `hovered` | bool | pointer over (`tile`, `recent`) |
| `focused` | bool | the search field has focus (`search`) |
| `selected` | bool | the current result (`row`) |
| `index` | int | result position, 0-based (`row`) |
| `font` | object | `Appearance.font` (`row`) |
| `palette` | object | `Appearance.colors` |

### `Toast`
Housing for a notification toast (`NotifToast`). The host drops its sheen,
border and shadow while the delegate is active, keeps the close button and the
click-to-dismiss area, and titles the toast in `Appearance.font.display` with
`displayCase`. Optional delegate properties read back by the host: `caption`
(string, shown in place of the app name, mono, tracked), `captionColor`
(color), `hideIcon` (bool, drop the app icon) and `dataBody` (bool, set the body
in the mono face).

| field | type | meaning |
|-------|------|---------|
| `urgency` | int | 0 low, 1 normal, 2 critical |
| `font` | object | `Appearance.font` |
| `palette` | object | `Appearance.colors` |

_(More components (BarPill, PanelShadow, a form Row) are added here as they gain
delegate seams.)_
