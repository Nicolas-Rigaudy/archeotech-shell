import QtQuick
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices

// The one panel opener for any holder (Sprint 26-C phase 4 — merges the old
// bar PanelOpenerWidget and strip StripIconBase). Toggles a panel; the panel is
// the widget's own id (config.panelId is a legacy fallback). Icon comes from the
// unified catalogue, or the injected `glyph` (plugin panel-content openers).
//
//   • On a BAR   — an always-visible flat pill; clicking drops the panel from
//                  the bar edge, anchored under this opener.
//   • On a STRIP — fills the icon cell + shows the rounded accent/hover highlight
//                  (the old StripIconBase look); clicking toggles the strip card.
//
// Adapts purely off `holderRoot.type`, so one component serves every side.
BarPill {
    id: root
    property var config: ({})
    property string glyph: ""   // plugin openers inject their module glyph

    readonly property string _panelId: (config && config.panelId) ? config.panelId
                                       : (widgetId ? widgetId : "dashboard")
    readonly property var    _meta:    ShellServices.WidgetRegistry.widgetMeta(_panelId)
    readonly property bool   _onStrip: holderRoot && (holderRoot.type === "strip" || holderRoot.type === "holder")
    readonly property bool   _open:    holderRoot ? holderRoot.showsPanel(_panelId) : false

    // Strip: fill the delegate cell + big glyph + highlight. Bar: implicit pill, flat.
    anchors.fill: _onStrip ? parent : undefined
    icon:     glyph !== "" ? glyph : ((_meta && _meta.icon) ? _meta.icon : "󰏗")
    iconSize: _onStrip ? 22 : 18
    iconColor: _open ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
    hoverColor: Commons.Appearance.colors.accent
    showActiveBg: _onStrip
    active:       _open

    // No hover popup — just open the panel on click, like a strip icon does.
    onClicked: {
        if (!holderRoot) return
        holderRoot.dismissPopups()
        // Record where the panel should drop from (this opener's centre) and pass
        // this holder's side so the panel opens from THIS holder.
        var c = mapToItem(holderRoot, width / 2, height / 2)
        holderRoot.togglePanel(_panelId, holderRoot.side, holderRoot.horizontal ? c.x : c.y)
    }
    onEntered: if (holderRoot) holderRoot.iconHoverEnter()
    onExited:  if (holderRoot) holderRoot.iconHoverExit()
}
