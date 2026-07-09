pragma Singleton
import QtQuick

// Sprint 18 — convention-based widget id → filename resolution.
//
//   Built-in bar widget id   "clock"        → "ClockWidget.qml"
//   Built-in strip icon  id  "nc"           → "NcIcon.qml"
//   Plugin widget id         "plugin:foo"   → "" (S20 work)
//
// The loader (WidgetLoader) owns the directory path prefix because
// Loader.source resolves relative to the calling file — keeping it relative
// avoids Qt URL handling pitfalls (it would double-prefix file:// URLs
// treated as relative strings).
QtObject {
    id: root

    // ── Palette catalogue (Sprint 21, unified Sprint 26-C phase 3) ──────────────
    // ONE hand-maintained built-in set. `bar`/`strip` tag which holder flavour
    // each widget can live in (a clock is bar-only; a panel opener is both; `nc`
    // is strip-only — the bar opens it via `notifications`). Sprint 22 (Module
    // Builder) replaces this with manifest discovery, keeping the shape so the
    // palette UI is unchanged. `availableBarWidgets`/`availableStripIcons` are
    // derived views over this so existing palette code keeps working.
    readonly property var availableWidgets: [
        { id: "workspaces",    name: "Workspaces",         icon: "󰧨", bar: true,  strip: false },
        { id: "title",         name: "Window Title",       icon: "󰖯", bar: true,  strip: false },
        { id: "media",         name: "Media",              icon: "󰝚", bar: true,  strip: true  },
        { id: "clock",         name: "Clock",              icon: "󰥔", bar: true,  strip: false },
        { id: "mic",           name: "Microphone",         icon: "󰍬", bar: true,  strip: false },
        { id: "volume",        name: "Volume",             icon: "󰕾", bar: true,  strip: false },
        { id: "brightness",    name: "Brightness",         icon: "󰃟", bar: true,  strip: false },
        { id: "network",       name: "Network",            icon: "󰤨", bar: true,  strip: false },
        { id: "bluetooth",     name: "Bluetooth",          icon: "󰂯", bar: true,  strip: false },
        { id: "battery",       name: "Battery",            icon: "󰁹", bar: true,  strip: false },
        { id: "notifications", name: "Notifications",      icon: "󰂚", bar: true,  strip: false },
        { id: "settings",      name: "Settings",           icon: "󰒓", bar: true,  strip: true  },
        { id: "power",         name: "Power",              icon: "󰐥", bar: true,  strip: false },
        // Panel openers — placed directly (like strip icons); on a bar each drops
        // its own panel from the edge (resolved to PanelOpenerWidget by id); on a
        // strip each is a hover-reveal icon.
        { id: "dashboard",     name: "Dashboard",          icon: "󰕮", bar: true,  strip: true  },
        { id: "launcher",      name: "Launcher",           icon: "󱓞", bar: true,  strip: true  },
        { id: "wallpaper",     name: "Appearance",         icon: "󰏘", bar: true,  strip: true  },
        { id: "nc",            name: "Notification Center", icon: "󰂚", bar: false, strip: true  }
    ]

    readonly property var availableBarWidgets: availableWidgets.filter(function(w) { return w.bar })
    readonly property var availableStripIcons: availableWidgets.filter(function(w) { return w.strip })

    // Bar-widget ids that are panel openers → all resolve to PanelOpenerWidget
    // (the panel is the id itself). Keeps them out of the *Widget.qml filename
    // convention. "nc"/"settings" already have dedicated bar widgets; "media" is
    // the marquee, which opens the media panel itself.
    readonly property var _panelOpenerIds: ["dashboard", "launcher", "wallpaper"]

    function _metaFor(list, id) {
        for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
        return { id: id, name: id, icon: "" }
    }
    // One meta lookup over the unified catalogue; the bar/strip aliases remain
    // for existing callers.
    function widgetMeta(id)    { return _metaFor(availableWidgets, id) }
    function barWidgetMeta(id) { return widgetMeta(id) }
    function stripIconMeta(id) { return widgetMeta(id) }

    // ── Per-instance config (Sprint 26) ─────────────────────────────────────────
    // configSchema for built-in widgets (plugins declare theirs in module.json,
    // read via ModuleRegistry). Field types map to Settings/Widgets rows in
    // ConfigForm.qml: bool→ToggleRow, int/real→SliderRow, enum→ButtonGroupRow /
    // DropdownRow, string→TextFieldRow. Add a widget's schema here to make it
    // per-instance configurable; widgets with no entry are config-less.
    readonly property var _builtinSchemas: ({
        clock: {
            format: {
                type: "enum", label: "Time format", "default": "24h",
                options: [{ value: "24h", label: "24-hour" }, { value: "12h", label: "12-hour" }]
            },
            showSeconds: { type: "bool", label: "Show seconds", "default": false }
        }
    })

    function configSchemaFor(id) {
        if (_isPlugin(id)) return {}   // plugin schema comes from ModuleRegistry
        return _builtinSchemas[id] || {}
    }

    // Default config object derived from a schema's declared defaults.
    // Loaders merge instance overrides on top of this.
    function schemaDefaults(schema) {
        var out = {}
        if (!schema) return out
        for (var k in schema) {
            if (schema[k] && schema[k]["default"] !== undefined) out[k] = schema[k]["default"]
        }
        return out
    }

    // Instance config with schema defaults filled in for any unset field.
    function resolveConfig(id, instanceConfig) {
        var out = schemaDefaults(configSchemaFor(id))
        if (instanceConfig) for (var k in instanceConfig) out[k] = instanceConfig[k]
        return out
    }

    // "active-window" → "ActiveWindow". PascalCase from kebab/snake input.
    function _pascalCase(id) {
        var parts = id.split(/[-_]/)
        var name = ""
        for (var i = 0; i < parts.length; i++) {
            if (!parts[i]) continue
            name += parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
        }
        return name
    }

    function _isPlugin(id) { return typeof id === "string" && id.indexOf("plugin:") === 0 }
    // Public alias — loaders branch on this to route plugin ids to ModuleRegistry.
    function isPlugin(id) { return _isPlugin(id) }

    // Resolve a built-in widget id to its QML file, relative to Widgets/ (the one
    // WidgetLoader prefixes the path). Sprint 26-C phase 4: one resolver for both
    // holders — on a strip/holder EVERY entry is a panel opener → the single
    // opener component; on a bar the panel-opener ids resolve to it too, and
    // everything else is a dedicated <PascalId>Widget.qml. Plugins load by
    // absolute URL (handled in the loader), so they return "".
    function widgetFile(id, isStrip) {
        if (!id || _isPlugin(id)) return ""
        if (isStrip || _panelOpenerIds.indexOf(id) !== -1) return "Bar/PanelOpenerWidget.qml"
        return "Bar/" + _pascalCase(id) + "Widget.qml"
    }
}
