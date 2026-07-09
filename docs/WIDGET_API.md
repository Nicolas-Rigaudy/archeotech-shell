# Widget API

The shell composes its bars and edge strips from independent widget files. Add a built-in widget by dropping one QML file under `Widgets/Bar/`. No central registry to edit, no enum to update.

A **bar** and a **strip/holder** are both *holders*: they expose the same `holderRoot` contract, mount widgets through the same `WidgetLoader`, and read their layout from the same per-side `content` list. One widget can therefore run on any side. This document is the contract every widget must follow.

---

## Quick start — add a bar widget

1. Create `config/.config/quickshell/Widgets/Bar/<PascalName>Widget.qml`.
2. Declare `required property var holderRoot` (and optionally `property string widgetId`).
3. Render whatever you want; the file is mounted by `WidgetLoader` and injected with the holderRoot API.
4. Add the id (kebab-case of `<PascalName>`) to a side's `content` in `shell-config.json`.

```qml
// Widgets/Bar/UptimeWidget.qml
import QtQuick
import QtQuick.Layouts
import "../../Commons" as Commons

Text {
    required property var holderRoot
    property string widgetId

    visible: holderRoot && holderRoot.horizontal
    Layout.alignment: Qt.AlignVCenter
    text: "up: …"
    color: Commons.Appearance.colors.subtext1
    font.family: Commons.Appearance.font.family
    font.pixelSize: Commons.Appearance.font.sizeSm
}
```

```json
// shell-config.json
"top": {
  "type": "bar",
  "content": [
    { "id": "uptime",  "align": "right" },
    { "id": "battery", "align": "right" },
    { "id": "power",   "align": "right" }
  ]
}
```

Save, watch the bar update — Quickshell hot-reloads.

Most bar widgets build on the shared **`BarPill`** capsule (`Widgets/Bar/BarPill.qml`), which owns the horizontal↔vertical fork (icon + value on a wide bar, icon-only on a thin one) so individual widgets stay orientation-blind. See `ClockWidget.qml` / `VolumeWidget.qml` for the pattern.

---

## Filename convention

`Services/Shell/WidgetRegistry.qml` (`widgetFile(id, isStrip)`) resolves widget ids to QML files under `Widgets/`:

| Id (kebab-case) | Resolves to | Notes |
|-----------------|-------------|-------|
| `clock`         | `Widgets/Bar/ClockWidget.qml`         | dedicated bar widget |
| `active-window` | `Widgets/Bar/ActiveWindowWidget.qml`  | PascalCase; `-`/`_` are separators |
| `dashboard` / `launcher` / `wallpaper` / `nc` / `settings` (on a strip) | `Widgets/Bar/PanelOpenerWidget.qml` | **panel openers** — one component, panel = the id |
| `plugin:foo`    | resolved from `module.json` | see [MODULE_API.md](MODULE_API.md) |

**Panel openers** don't get their own file — `PanelOpenerWidget` is the single opener for every holder. It reads its glyph from the unified catalogue (`availableWidgets` in `WidgetRegistry`) and toggles the panel whose id equals the widget id. On a strip *every* entry is an opener; on a bar the opener ids are `dashboard`/`launcher`/`wallpaper` (the others there are dedicated widgets). To add a new opener, add an entry to `availableWidgets` and register its panel in `PanelRegistry` — no new QML file.

---

## holderRoot — the widget context

Every widget receives a `holderRoot` reference (a `Bar` or a `Strip`; both expose the same superset). Treat it as the only legitimate hook into its holder; reaching past it into `Bar.qml`/`Strip.qml` internals will break with future refactors.

### Properties

| Name                    | Type    | What it tells you |
|-------------------------|---------|-------------------|
| `holderRoot.side`       | string  | `"top"`, `"bottom"`, `"left"`, `"right"` |
| `holderRoot.horizontal` | bool    | `side === "top"` or `"bottom"` |
| `holderRoot.type`       | string  | `"bar"`, `"strip"`, or `"holder"` |
| `holderRoot.screen`     | var     | The QtScreen (use `.name` for IPC) |
| `holderRoot.screenName` | string  | Convenience for `ShellState` calls |
| `holderRoot.thickness`  | int     | Cross-axis extent — bar height / strip body depth |

### Panel + popup functions

| Function | Effect | Holder |
|----------|--------|--------|
| `togglePanel(id, side, anchor)` | Open/close a panel from this holder. `side` = `""` for a wildcard (bar gear / IPC), else the holder's own side. `anchor` (optional) is the along-axis pixel a bar panel drops under. | both |
| `showsPanel(id)` | `true` iff `id` is the active panel shown on **this** holder (for active-state highlight). | both |
| `dismissPopups()` | Clear transient control popups (WiFi/BT) before opening a panel. | bar (no-op on strip) |
| `iconHoverEnter()` / `iconHoverExit()` | Keep a strip's hover-reveal card alive while the cursor is on an icon. | strip (no-op on bar) |
| `showPopup(item, label, primary, secondary, hint)` | Anchor + show the shared hover-info card above `item`. Pass `""` for unused slots. | bar |
| `hidePopup(caller)` | Start the 250 ms hide timer; passing the calling item guards against stale exit races. | bar |
| `hideCalendar(caller)` / `keepPopupsAlive()` | Calendar hide timer / cancel pending hides so the cursor can drift onto a card. | bar |

Bar-only functions are safe to call unconditionally (a strip stubs them), but gate hover **cards** on `holderRoot.horizontal` — a thin vertical bar has no room for one.

### Panel openers

Openers are catalogue-driven, not hand-written — `PanelOpenerWidget` handles the click (`togglePanel`), the active highlight (`showsPanel`), and the bar-vs-strip look (flat pill vs. filled cell with accent highlight) off `holderRoot.type`. You almost never write one; you add a catalogue entry (see the filename table). Plugin `panel-content` openers reuse it too, with the module's glyph injected.

### Mutually-exclusive popup state (advanced)

`NetworkWidget`/`BluetoothWidget` toggle their own popup cards (`WifiPopup`/`BtPopup`). That state lives on the (bar) holderRoot as plain properties so components synchronise:

| Property | Owner |
|----------|-------|
| `_wifiPopupVisible` (bool) / `_wifiAnchorX` (real) | NetworkWidget toggles, WifiPopup reads |
| `_btPopupVisible` (bool) / `_btAnchorX` (real)     | BluetoothWidget / BtPopup |
| `_calendarVisible` (bool)                          | ClockWidget / CalendarPopup |

Prefer `holderRoot.dismissPopups()` to poking `_wifiPopupVisible`/`_btPopupVisible` directly (it does the same and works on any holder).

---

## Per-instance config (`configSchema`)

A widget can expose user-configurable fields. Each *placed* instance carries its own values, so two of the same widget can differ (two clocks, one 12-hour). The shell auto-generates the settings form — no UI to write.

**1. Declare the schema.** Built-in widgets register it in `Services/Shell/WidgetRegistry.qml` under `_builtinSchemas`, keyed by id (plugins declare it in `module.json` — see [MODULE_API.md](MODULE_API.md)):

```qml
readonly property var _builtinSchemas: ({
    clock: {
        format:      { type: "enum", label: "Time format", "default": "24h",
                       options: [{ value: "24h", label: "24-hour" }, { value: "12h", label: "12-hour" }] },
        showSeconds: { type: "bool", label: "Show seconds", "default": false }
    }
})
```

Field types → form rows: `bool`→toggle, `int`/`real`→slider (`min`/`max`/`step`/`unit`), `enum`→segmented buttons (≤3 options) or dropdown (`options:[{value,label}]`), `string`→text field (`placeholder`). Every spec takes `label`, `description`, `default`.

**2. Read it in the widget.** Declare `property var config` — the loader injects it (schema defaults merged in) and updates it live when the user edits:

```qml
Item {
    required property var    holderRoot
    property string widgetId
    property var config: ({})            // { format, showSeconds }
    function _fmt() { return config.format === "12h" ? "h:mm AP" : "HH:mm" }
}
```

`ClockWidget.qml` is the reference. Users edit an instance from the gear on its chip in **Edit Layout** (`Super+Shift+E`); the **Plugins** settings pane lists which widgets are configurable. There is no global-default layer — config is per-instance, stored on the entry in `shell-config.json`.

---

## Loader injection details

Widgets are loaded asynchronously by `Modules/Shell/Sides/WidgetLoader.qml` (one loader for both holders):

```qml
loader.setSource("../../../Widgets/" + file, {
    holderRoot: holder,   // the Bar or Strip
    widgetId:   id
})
```

`holderRoot` + `widgetId` are set at construction time (required props must come through this map — a declarative `holderRoot: holder` on a `Loader` does NOT satisfy a required property). **Optional** props are set in `onLoaded` guarded by `'x' in item`, so setSource stays strict-safe:

- `config` — set on any widget that declares it (see above); re-applied when the instance's config changes, keeping the live widget instance.
- `appearance` — injected only for external `plugin:` widgets that declare `property var appearance` (they can't `import Commons` from outside the config tree). Built-in widgets `import Commons` directly and ignore this.

---

## Orientation

`holderRoot.horizontal` is `true` only for top/bottom bars. Vertical side bars are now fully config-driven and render the same widgets via `BarPill`'s icon-only mode — a widget that builds on `BarPill` is orientation-aware for free. Widgets that can't meaningfully go vertical (title, media marquee) should still gate:

```qml
visible: holderRoot && holderRoot.horizontal
```

---

## Per-side content model

A side's layout is one ordered list:

```json
"top": {
  "type": "bar",
  "content": [
    { "id": "workspaces", "align": "left" },
    { "id": "clock",  "config": { "format": "12h" }, "align": "center" },
    { "id": "battery", "align": "right" }
  ]
}
```

- **`id`** — the widget id (or `plugin:<id>`).
- **`config`** — optional per-instance config object (see above).
- **`align`** — on a **bar**, the zone: `"left"`, `"center"`, `"right"`. On a **strip/holder** it's omitted (icons cluster at the edge).

Old files using the split `zones: { left, center, right }` / `icons: [...]` format still load unchanged — `ShellConfig` normalizes them to `content` on read. Editing a side in the GUI rewrites just that side to `content`.

### Stable ListModel (preserve delegates)

`Bar.qml` syncs each zone's entries into a `ListModel` via `_syncZone()` (HyprPanel-style diff). Rows are keyed on a stable `instanceKey` (`id + "#" + occurrence`) so two same-id widgets keep distinct delegates; config rides as a JSON string and is updated in place, so editing an instance's config does not reload the widget. When `shell-config.json` changes, only added/removed/moved widgets churn — unchanged widgets keep their state (MPRIS marquee position, transient hover, etc.). Widgets don't need to design around this; edits hot-reload cleanly.

---

## Plugins

`plugin:<id>` ids are **not** resolved by the filename convention — `WidgetLoader` routes them to `Services/Shell/ModuleRegistry.qml`, which discovers self-describing module folders (`module.json` + entry QML) under `~/.config/quickshell/modules/` and `~/.local/share/archeotech/modules/`. Plugin widgets share this same contract (`holderRoot`, `config`, and — for external modules — the injected `appearance`). Authoring, `module.json`, `configSchema`, placement targets, and the external-import story live in [MODULE_API.md](MODULE_API.md).

See `.claude/ANALYSIS.md` §12 for the chosen pattern (Noctalia-style filesystem convention + `plugin:<id>` namespacing).
