import QtQuick
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

// Reusable panel-content kernel (Sprint 26-C, phase 1). Mounts a panel's
// content (built-in PanelRegistry Component or external plugin file://) and
// computes its size targets, so any holder — a strip's card or a bar's
// dropdown — can host a panel without re-deriving the loader + sizing logic.
//
// The holder owns the chrome (glass card, animation, positioning) and reads
// `perpTarget` / `axisTarget` (or the raw hints: panelSize / axisSizeRaw / ready
// / contentImplicitAxis) to size it; PanelHost just mounts the content filling
// itself and reports what size it wants. `panelRoot` (with close() / panelOpen)
// is supplied by the holder and injected into the content. Both holders use it:
// BarPanel (bar dropdown) and Strip (edge card).
Item {
    id: host

    // ── Inputs (bound by the holder) ────────────────────────────────────────────
    required property string side
    required property var    screen
    property string panelId:    ""      // active panel id ("" = none)
    property bool   shown:      false    // holder's show/animate gate
    property int    screenAxis: 0        // along-axis screen extent (clamp ceiling)
    property int    axisFloor:  0        // along-axis minimum
    property var    panelRoot:  null     // injected into content (close/panelOpen)

    readonly property bool horizontal: side === "top" || side === "bottom"

    // ── Panel metadata: built-in (PanelRegistry) or plugin panel-content module.
    // Plugin panels carry `contentUrl` (absolute QML) instead of `content`.
    function _metaFor(id) {
        var m = ShellServices.PanelRegistry.panelFor(id)
        if (m) return { content: m.content, contentUrl: null, size: m.size, axisSize: m.axisSize }
        if (ShellServices.WidgetRegistry.isPlugin(id)) {
            var mod = ShellServices.ModuleRegistry.moduleFor(id)
            if (mod && (mod.canLiveIn || []).indexOf("panel-content") !== -1) {
                var p = mod.panel || {}
                return {
                    content:    null,
                    contentUrl: ShellServices.ModuleRegistry.entryUrl(id),
                    size:       p.size || (mod.defaultSize && mod.defaultSize.width) || 380,
                    axisSize:   p.axisSize !== undefined ? p.axisSize : "auto"
                }
            }
        }
        return null
    }

    readonly property var  meta:        (shown && panelId) ? _metaFor(panelId) : null
    readonly property int  panelSize:   meta ? meta.size : 0
    readonly property var  axisSizeRaw: (meta && meta.axisSize !== undefined) ? meta.axisSize : "full"

    readonly property var  _item: builtinLoader.item || pluginLoader.item
    readonly property real contentImplicitAxis: (_item && _item.implicitAxis !== undefined)
                                                ? _item.implicitAxis : 0

    // Auto-sized panels only know their axis extent once content has measured
    // implicitAxis; hold until then so the holder expands in one motion (mirrors
    // Strip's anti-jitter gate).
    readonly property bool ready: !shown
                                  || axisSizeRaw !== "auto"
                                  || contentImplicitAxis > 0
                                  || (!!_item && _item.implicitAxis === undefined)

    // Perpendicular depth away from the edge, and along-axis extent (clamped to
    // screen, floored at axisFloor). The holder adds its own chrome padding.
    readonly property real perpTarget: panelSize
    readonly property real axisTarget: !ready ? axisFloor
        : axisSizeRaw === "full" ? screenAxis
        : axisSizeRaw === "auto" ? Math.min(screenAxis, Math.max(axisFloor, contentImplicitAxis))
        :                          Math.min(screenAxis, Math.max(axisFloor, axisSizeRaw))

    // ── Content mount — built-in via sourceComponent, plugin via source URL.
    // Split into two mutually-exclusive Loaders (binding both source and
    // sourceComponent on one Loader races). `active` gates each.
    function _inject(item) {
        if (!item) return
        if ('panelRoot'  in item) item.panelRoot  = host.panelRoot
        if ('appearance' in item) item.appearance = Commons.Appearance
    }
    onPanelRootChanged: { _inject(builtinLoader.item); _inject(pluginLoader.item) }

    Loader {
        id: builtinLoader
        anchors.fill: parent
        active: host.shown && !!host.meta && !host.meta.contentUrl
        sourceComponent: (host.meta && !host.meta.contentUrl) ? host.meta.content : null
        onLoaded: host._inject(item)
    }
    Loader {
        id: pluginLoader
        anchors.fill: parent
        active: host.shown && !!host.meta && !!host.meta.contentUrl
        source: (host.meta && host.meta.contentUrl) ? host.meta.contentUrl : ""
        onLoaded: host._inject(item)
    }
}
