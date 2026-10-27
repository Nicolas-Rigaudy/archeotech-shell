import QtQuick
import "../../../Commons" as Commons

// Search anchor for one setting (item_138). When State.settingsFocusKey equals
// `key` (a search result or launcher pick, PaneRegistry.focusSetting), it
// scrolls the pane's Flickable to `target` and pulses an accent outline over it,
// then clears the request. Rows embed one via their `searchKey`; a pane can also
// place one for a section (a card, a picker), with `target` set to it.
// Checks on creation too: a lazy pane built by the same pick still reveals.
Item {
    id: st
    property string key: ""
    property Item target: parent
    signal revealing()   // before the scroll: a pane can switch a tab here

    width: 0; height: 0

    function _check() {
        if (st.key === "" || Commons.State.settingsFocusKey !== st.key) return
        Commons.State.settingsFocusKey = ""
        st.revealing()
        _settle.restart()
    }
    Connections {
        target: Commons.State
        function onSettingsFocusSerialChanged() { st._check() }
    }
    Component.onCompleted: _check()

    // Wait for the pane to be shown and laid out before measuring.
    Timer { id: _settle; interval: Commons.Appearance.anim.panel; onTriggered: st._reveal() }

    property Item _shown: null    // what the outline is over (target, or a visible ancestor)
    property var  _flick: null

    function _reveal() {
        var flick = null
        // The pane's Flickable: the first scrollable ancestor that is not a
        // ListView/GridView (those have a model; a row inside one is not ours to scroll).
        for (var p = st.target ? st.target.parent : null; p; p = p.parent)
            if (p.contentY !== undefined && p.contentItem && p.model === undefined) { flick = p; break }
        if (!flick) return
        // A hidden row (e.g. Temperature while night light is off) reveals the
        // nearest visible container instead, but never the whole pane: a section
        // hidden for a missing device (no touchpad) just opens the pane.
        var t = st.target
        while (t && !t.visible) t = t.parent
        if (!t || t.parent === flick.contentItem) return
        var pos = t.mapToItem(flick.contentItem, 0, 0)
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(maxY, pos.y - Commons.Appearance.spacing.s6))
        st._shown = t; st._flick = flick
        hl.parent = flick.contentItem
        st._place()
        _pulse.restart()
    }
    // Re-measured while the outline shows: a pane built by this pick may still be
    // settling its layout (widths grow once it is shown).
    function _place() {
        if (!st._shown || !st._flick) return
        var m = Commons.Appearance.spacing.s1
        var pos = st._shown.mapToItem(st._flick.contentItem, 0, 0)
        hl.x = pos.x - m; hl.y = pos.y - m
        hl.width = st._shown.width + 2 * m; hl.height = st._shown.height + 2 * m
    }
    Timer { interval: 50; repeat: true; running: _pulse.running; onTriggered: st._place() }

    // Accent outline over the target, drawn in the Flickable's content (a plain
    // Item, never a Layout, so any target works, even a Layout root).
    Rectangle {
        id: hl
        parent: null
        z: 100
        radius: Commons.Appearance.radius.base
        color: "transparent"
        border.width: 2
        border.color: Commons.Appearance.colors.accent
        opacity: 0
        visible: opacity > 0
    }
    // In fast, hold ~1 s, fade slowly: about 1.5 s in all (owner pick, 2026-10-12).
    SequentialAnimation {
        id: _pulse
        NumberAnimation { target: hl; property: "opacity"; to: 1; duration: Commons.Appearance.anim.fast }
        PauseAnimation  { duration: Commons.Appearance.anim.base * 5 }
        NumberAnimation { target: hl; property: "opacity"; to: 0; duration: Commons.Appearance.anim.base * 3 }
        onStopped: { st._shown = null; st._flick = null }
    }
}
