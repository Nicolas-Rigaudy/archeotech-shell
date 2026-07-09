# Module API

Archeotech's community-extension system. A **module** is a self-describing folder
you drop into a modules directory; the shell discovers it, lists it in edit mode,
and mounts it where you assign it — no QML edits, no shell restart.

> Built-in bar widgets, strip icons and panels are **not** modules — they live in
> `WidgetRegistry` / `PanelRegistry`. Modules are strictly the third-party layer.
> For the built-in widget contract see [WIDGET_API.md](WIDGET_API.md).

## Where modules live

Both roots are scanned (by `Services/Shell/ModuleRegistry.qml`, via a `jq` sweep):

| Path | Use |
|------|-----|
| `~/.config/quickshell/modules/<id>/` | bundled / repo-tracked modules (stowed) |
| `~/.local/share/archeotech/modules/<id>/` | user-installed modules |

Each module is a folder containing a `module.json` manifest and at least one
QML entry file. Discovery re-runs whenever edit mode opens, so a freshly-dropped
folder appears in the palette immediately.

## `module.json`

```json
{
  "id": "weather",
  "name": "Weather",
  "author": "you",
  "version": "1.0.0",
  "canLiveIn": ["panel-content"],
  "entry": "Weather.qml",
  "icon": "󰖐",
  "defaultSize": { "width": 340, "height": 0 },
  "panel": { "size": 360, "axisSize": "auto" },
  "configSchema": {}
}
```

| Field | Required | Meaning |
|-------|----------|---------|
| `id` | yes | Unique slug. Referenced in `shell-config.json` as `plugin:<id>`. |
| `name` | yes | Display name (palette tile, etc.). |
| `entry` | yes | QML file (relative to the module folder) that is the module's content. |
| `canLiveIn` | yes | Placement targets — see below. |
| `icon` | rec. | Nerd-font glyph; used for the palette tile and the auto-generated panel opener. |
| `author`, `version` | rec. | Metadata. |
| `defaultSize` | opt. | `{ width, height }` hint. `width` is the panel fallback `size` if `panel` is absent. |
| `panel` | opt. | `{ size, axisSize }` for `panel-content` modules — see Panel sizing. |
| `configSchema` | opt. | Per-instance config fields → auto-generated settings form. See [Per-instance config](#per-instance-config-configschema). |
| `verified` | opt. | `true` shows a "Verified" badge in the Plugins pane. Honored, not cryptographically checked (signing is a later sprint). |
| `description` | opt. | One-line blurb (shown in the Plugins pane). |

### `canLiveIn` targets

| Target | Behaviour | Status |
|--------|-----------|--------|
| `bar-zone` | `entry` mounts inline as a bar widget in a bar zone. | ✅ Chunk 2 |
| `strip-icon` | `entry` mounts directly as a strip icon (small, self-contained). | ✅ Chunk 2 |
| `panel-content` | the holder auto-generates an opener (the shared `PanelOpenerWidget` with the `icon` glyph); clicking it toggles a panel whose content is `entry`. | ✅ Chunk 2 |
| `desktop-widget` | placed free-floating on the desktop layer. | ⏳ Sprint 21 Chunk 3 |

A module may list several. When placed on a strip, `panel-content` wins over
`strip-icon` (the richer behaviour); on a bar zone, `bar-zone` is used.

## The entry QML contract

**`bar-zone` / `strip-icon`** — same contract as a built-in widget. Declare the
injected properties; use the `holderRoot` context API (one contract for bars and
strips — see [WIDGET_API.md](WIDGET_API.md)):

```qml
Item {
    required property var    holderRoot   // a Bar or a Strip; same superset API
    required property string widgetId
    implicitWidth: /* your content width */
    implicitHeight: 22
    // holderRoot.showPopup(item, label, primary, secondary, hint) / hidePopup(item)
}
```

**`panel-content`** — declare `property var panelRoot` (call `panelRoot.close()`
to dismiss). The panel mounts in the hosting holder (a strip card or a bar
dropdown) via the shared `PanelHost`; its size comes from the manifest `panel`
block:

```qml
Item {
    property var panelRoot
    // optional: property real implicitAxis   // drives axisSize:"auto"
}
```

### Panel sizing

`panel.size` = perpendicular depth (away from the strip edge). `panel.axisSize` =
extent along the strip: a number (px), `"auto"` (the entry exposes a numeric
`implicitAxis` the strip reads), or `"full"` (whole screen edge). If `panel` is
omitted, `size` falls back to `defaultSize.width` (or 360) and `axisSize` to
`"auto"`. See [PANEL_API.md](PANEL_API.md) for the underlying model.

## Per-instance config (`configSchema`)

`configSchema` declares a widget's user-configurable fields. Each *placed*
instance carries its own values, so two instances of the same module can differ
(e.g. two clocks, one 12-hour). The shell auto-generates a settings form from
the schema — you write no UI. It's a flat object of `field → spec`:

```json
"configSchema": {
  "city":     { "type": "string", "label": "City",     "default": "Berlin", "placeholder": "City name" },
  "units":    { "type": "enum",   "label": "Units",    "default": "c",
                "options": [ { "value": "c", "label": "°C" }, { "value": "f", "label": "°F" } ] },
  "interval": { "type": "int",    "label": "Refresh",  "default": 15, "min": 5, "max": 60, "step": 5, "unit": " min" },
  "showIcon": { "type": "bool",   "label": "Show icon", "default": true }
}
```

| `type` | Renders as | Extra spec keys |
|--------|-----------|-----------------|
| `bool` | toggle | — |
| `int` / `real` | slider | `min`, `max`, `step`, `unit` (label suffix) |
| `enum` | segmented buttons (≤3 options) or dropdown | `options: [{value,label}]` |
| `string` | text field | `placeholder` |

Every spec may also carry `label` (falls back to the field key) and
`description`. `default` fills the value until the user overrides it.

**Reading config in the entry QML** — declare `property var config`; it's
injected (defaults merged in) and updated live when edited:

```qml
Item {
    required property var    holderRoot
    required property string widgetId
    property var config: ({})          // { city, units, interval, showIcon }
    // e.g. config.units === "f" ? … : …
}
```

Users edit an instance's config from the gear on its chip in **Edit Layout**
(`Super+Shift+E`). The Plugins pane (Settings → Plugins) lists modules and marks
configurable ones; it does not store a global default (config is per-instance).

## Theming

**Every** module — bundled *or* external — is mounted by absolute `file://`
URL, so `import "../../Commons"` does **not** resolve (it either fails or loads a
separate, empty singleton → `Cannot read property … of undefined`). Quickshell's
`qs.Commons` import only works for files inside the config tree, and there's no
import-path knob for outside files. So a module must **not** `import Commons`.

Instead declare `property var appearance`; the loader injects the live theme
tokens (`colors / font / radius / spacing / anim`). It's set just after the
object is created, so guard uses until it arrives:

```qml
Item {
    required property var holderRoot    // (panel-content declares panelRoot instead)
    property var appearance
    property var config: ({})
    readonly property var _a: appearance
    // color: _a ? _a.colors.text : "#cdd6f4"
    // font.family: _a ? _a.font.family : "sans-serif"
}
```

`appearance` is injected for all three placement types (bar-zone, strip-icon,
panel-content) and only if the property exists. The bundled examples (`hello`,
`notes`) use exactly this pattern — copy them. (Access to shell *services*
beyond theme tokens is not yet exposed to modules.)

## Worked example

`~/.config/quickshell/modules/notes/` →

- `module.json` with `"canLiveIn": ["panel-content"]`, `"entry": "Notes.qml"`,
  `"icon": "󰎞"`, `"panel": { "size": 360, "axisSize": 420 }`.
- `Notes.qml` — an `Item` with `property var panelRoot` rendering the content.

Then: `Super+Shift+E` → click a strip's `+` → pick **Quick Notes** → an opener
icon appears on that strip; click it → the Notes panel slides out. The
assignment persists in `shell-config.json` as `plugin:notes` in that side's
`content` list.
