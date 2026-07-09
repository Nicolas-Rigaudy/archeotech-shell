import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

// The one async loader for a holder widget (Sprint 26-C phase 4 — merges
// BarWidgetLoader + StripWidgetLoader). Resolves the QML file via WidgetRegistry
// (one resolver, holder-aware), mounts it asynchronously, and injects the
// `holderRoot` contract + per-instance `config`.
//
// holderRoot contract — every widget reads these off its injected `holderRoot`
// (a Bar or a Strip; both expose the same superset):
//
//   readonly property string side            // "top" | "bottom" | "left" | "right"
//   readonly property bool   horizontal      // side ∈ { top, bottom }
//   readonly property var    screen          // QtScreen
//   readonly property string screenName
//   readonly property string type            // "bar" | "strip" | "holder"
//   function togglePanel(id, side, anchor)   // open/close a panel from this holder
//   function dismissPopups()                 // clear transient control popups
//   function showsPanel(id)                  // is `id` the active panel on this holder
//   function iconHoverEnter() / iconHoverExit()
//   function showPopup(...) / hidePopup(...) // bar hover cards (no-op on a strip)
//
// Sprint 26 — per-instance `config` (schema defaults merged). Optional props are
// set in onLoaded only if the widget declares them (the `'x' in item` guard) so
// setSource stays strict-safe. External plugin widgets that declare
// `property var appearance` get the theme tokens injected (they can't
// `import Commons` from outside the config tree). See docs/WIDGET_API.md.
Loader {
    id: loader

    required property string widgetId
    required property var    holderRoot
    property var  config: ({})
    property bool isFirst: false
    property bool isLast:  false

    readonly property bool _isStrip: holderRoot
        && (holderRoot.type === "strip" || holderRoot.type === "holder")

    // Instance config with schema defaults merged underneath (built-in schema
    // from WidgetRegistry; plugin schema from its module.json).
    function _resolvedConfig() {
        if (ShellServices.WidgetRegistry.isPlugin(widgetId)) {
            var m = ShellServices.ModuleRegistry.moduleFor(widgetId)
            var defs = ShellServices.WidgetRegistry.schemaDefaults(m ? m.configSchema : null)
            if (config) for (var k in config) defs[k] = config[k]
            return defs
        }
        return ShellServices.WidgetRegistry.resolveConfig(widgetId, config)
    }

    // Push optional props onto an already-loaded widget without failing on
    // widgets that don't declare them. Also the config hot-update path: editing
    // an instance's config re-runs this, keeping the live widget instance.
    function _applyOptional() {
        if (!item) return
        if ('config' in item) item.config = _resolvedConfig()
        if (ShellServices.WidgetRegistry.isPlugin(widgetId) && ('appearance' in item))
            item.appearance = Commons.Appearance
    }
    onLoaded: _applyOptional()
    onConfigChanged: _applyOptional()

    // Caelestia first/last padding (bar zones) — harmless on a strip (the loader
    // isn't in a Layout there, so Layout.* is ignored). Vertical bars stack in a
    // ColumnLayout, so centre on the cross axis instead.
    Layout.leftMargin:  isFirst ? 2 : 0
    Layout.rightMargin: isLast  ? 2 : 0
    Layout.alignment:   (holderRoot && holderRoot.horizontal) ? Qt.AlignVCenter : Qt.AlignHCenter

    asynchronous: true
    visible: status === Loader.Ready

    function _resolve() {
        var reg = ShellServices.WidgetRegistry
        // Plugin module (entry QML lives outside the convention dir — load by
        // absolute file:// URL from ModuleRegistry).
        //   panel-content on a strip → the generic opener icon (module glyph),
        //     toggling a panel id == widgetId (PanelRegistry resolves content).
        //   otherwise               → the module's entry QML directly.
        if (reg.isPlugin(widgetId)) {
            var m = ShellServices.ModuleRegistry.moduleFor(widgetId)
            if (!m) { source = ""; return }
            if (_isStrip && (m.canLiveIn || []).indexOf("panel-content") !== -1) {
                loader.setSource("../../../Widgets/Bar/PanelOpenerWidget.qml", {
                    holderRoot: loader.holderRoot,
                    widgetId:   loader.widgetId,
                    glyph:      m.icon || "󰏗"
                })
                return
            }
            var url = ShellServices.ModuleRegistry.entryUrl(widgetId)
            if (!url) { source = ""; return }
            loader.setSource(url, { holderRoot: loader.holderRoot, widgetId: loader.widgetId })
            return
        }
        var file = reg.widgetFile(widgetId, _isStrip)
        if (!file) { source = ""; return }
        // Path relative to this file: Modules/Shell/Sides/ → repo root → Widgets/
        loader.setSource("../../../Widgets/" + file, {
            holderRoot: loader.holderRoot,
            widgetId:   loader.widgetId
        })
    }

    onWidgetIdChanged:     _resolve()
    Component.onCompleted: _resolve()

    onStatusChanged: {
        if (status === Loader.Error)
            console.warn("[WidgetLoader] failed to load", widgetId)
    }
}
