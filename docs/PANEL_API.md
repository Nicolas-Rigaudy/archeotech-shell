# Panel API

Panels are the larger content surfaces a holder shows — Notifications, Launcher, Dashboard, Settings, Media, Wallpaper Picker. Each panel is a single QML file under `Modules/Shell/Panels/Content/` plus an entry in `Services/Shell/PanelRegistry.qml`.

A panel is *not* a window, and it is *not* tied to a strip. Both holder types host panels through the shared **`PanelHost`** kernel (`Modules/Shell/Panels/PanelHost.qml`), which resolves the panel meta, mounts the content, injects `panelRoot`, and reports size hints:

- a **strip** shows the panel in its edge card (`Strip.qml`);
- a **bar** drops it from the bar edge, anchored under the opener (`Widgets/Bar/BarPanel.qml`).

The holder owns the chrome (glass card, animations, click-outside, Esc); PanelHost mounts the content; the panel file is just the inner content.

---

## Quick start — add a panel

1. Create `config/.config/quickshell/Modules/Shell/Panels/Content/<PascalName>.qml`.
2. Declare `property var panelRoot` and anchor-fill the parent.
3. Add an entry to `PanelRegistry.qml`.
4. Add its opener to the catalogue (`availableWidgets` in `WidgetRegistry`, with `strip`/`bar` caps) and place that id in a side's `content` in `shell-config.json`. No per-panel icon file — `PanelOpenerWidget` is the shared opener (see [WIDGET_API.md](WIDGET_API.md)).

```qml
// Modules/Shell/Panels/Content/MyPanel.qml
import QtQuick
import "../../../../Commons" as Commons

Item {
    id: root
    anchors.fill: parent
    property var panelRoot

    Text {
        anchors.centerIn: parent
        text:  "Hello panel"
        color: Commons.Appearance.colors.text
    }
}
```

```qml
// Services/Shell/PanelRegistry.qml — add to the panels map
myPanel: {
    content:  _myPanelComp,
    side:     "right",
    size:     320,
    axisSize: 440
}
```

---

## PanelRegistry entry fields

| Field      | Type            | Meaning                                                                 |
|------------|-----------------|-------------------------------------------------------------------------|
| `content`  | `Component`     | Wraps the QML file. Loaded async by `Strip.qml` when the panel opens.   |
| `side`     | `"top"`, `"right"`, `"bottom"`, `"left"` | Which edge strip hosts this panel.        |
| `size`     | `int`           | Perpendicular dimension (depth into the screen, away from the edge).    |
| `axisSize` | `int`, `"auto"`, `"full"` | Along-strip dimension (see below).                            |

### `axisSize` semantics

| Value      | Behaviour                                                                                |
|------------|------------------------------------------------------------------------------------------|
| `<number>` | Panel grows to exactly `N` pixels along the strip axis, clamped to the screen extent.    |
| `"auto"`   | Panel reads its content's `implicitAxis` property and sizes to fit, clamped to screen.   |
| `"full"`   | Legacy — panel occupies the entire screen axis (pre-Sprint 20 behaviour).                |

In all cases the size is floored at the icon row width (`_bodyAxis + 2 * radius.md`) so the icon cluster never gets clipped.

### When to use which

- **Numeric** — most panels. Pick a comfortable width that fits the content with breathing room.
- **`"auto"`** — content height varies a lot (e.g. notifications: 0 → many). Cheaper than picking an arbitrary fixed size that's too tall when empty.
- **`"full"`** — only if the panel really needs the entire screen axis (none currently do — kept as a fallback for incremental migration).

---

## `panelRoot` API

`PanelHost` injects `panelRoot` into the panel content on load (the holder — Strip or BarPanel — supplies it). The object exposes:

| Member         | Type     | What                                                                    |
|----------------|----------|-------------------------------------------------------------------------|
| `close()`      | function | Closes the panel (clears `ShellState` across screens).                  |
| `panelOpen`    | `bool`   | `true` while this holder's panel is active.                             |

Use it to dismiss the panel after a successful action:

```qml
TapHandler { onTapped: { doThing(); if (panelRoot) panelRoot.close() } }
```

Watch `panelOpen` to react to open/close (refresh, focus a field, etc.):

```qml
Connections {
    target: root.panelRoot
    enabled: root.panelRoot !== null
    function onPanelOpenChanged() {
        if (root.panelRoot.panelOpen) searchInput.forceActiveFocus()
    }
}
```

---

## `implicitAxis` — opting in to `axisSize: "auto"`

Expose a numeric `implicitAxis` property on the root content Item. The Strip reads it (when defined) and uses it as the target along-axis size:

```qml
Item {
    id: root
    anchors.fill: parent
    property var panelRoot

    // Strip clamps to [iconRowWidth, screenAxis] and adds 2 * radius padding.
    readonly property real implicitAxis:
        Math.max(220, contentColumn.implicitHeight + Commons.Appearance.spacing.xl * 2)
}
```

The floor (`220` above) keeps the panel from collapsing to header-only when content is missing. Pick a value that leaves the empty state breathable.

---

## Animation tokens

Use the shared `Commons.Appearance.anim` tokens for any panel-internal transitions so everything matches the strip's perp/axis growth:

| Token   | ms  | Use for                                                            |
|---------|-----|--------------------------------------------------------------------|
| `fast`  | 100 | Hover-color, button-color transitions.                             |
| `base`  | 200 | Content fades, in-panel size changes, hover→active state.          |
| `slow`  | 300 | Slower reveal animations (collapsible sections, modal dialogs).    |
| `panel` | 240 | Strip popup ↔ panel transition. Defined for symmetry — usually owned by Strip.qml, not panel content. |

Stick to `OutCubic` easing for entrance/exit motion.

---

## Empty states

When a panel can have no content (notifications, recents, no paired devices), use `Commons/Primitives/EmptyState.qml`:

```qml
import "../../../../Commons/Primitives"

EmptyState {
    Layout.fillWidth: true
    visible: model.count === 0
    icon:    "󰂚"
    title:   "No notifications"
    hint:    "" // optional second line
}
```

This gives a consistent visual treatment (subtle `surface1` icon + `overlay0` text) across all panels.

---

## What lives where

```
config/.config/quickshell/
├── Services/Shell/PanelRegistry.qml    # the panels map (id → metadata)
├── Modules/Shell/Panels/
│   ├── PanelHost.qml                   # shared kernel: meta + content mount + size hints
│   └── Content/
│       ├── NotificationCenter.qml      # axisSize: "auto" — exposes implicitAxis
│       ├── Launcher.qml                # recents + search + list
│       ├── Dashboard.qml               # left/right cols
│       ├── MediaPanel.qml
│       ├── SettingsPanel.qml
│       └── WallpaperPicker.qml         # horizontal carousel
├── Modules/Shell/Sides/Strip.qml       # strip card chrome + anims (hosts PanelHost)
└── Widgets/Bar/BarPanel.qml            # bar dropdown chrome (hosts PanelHost)
```

Only `PanelRegistry.qml` knows the full panel list. A holder mounts whichever panel is active for that screen/side via `ShellState` + `PanelHost`.
