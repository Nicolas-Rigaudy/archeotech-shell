import QtQuick
import ".." as Commons

// Selected-row marker seam (adr_027 Layer C, item_156): the launcher's result
// highlight and the Settings sidebar's active page. The host keeps its own
// highlight as the base look and hides it while `active` (a pack's
// `styles/RowSelection.qml` loaded), which then draws the selection instead
// (bracket marks, a scanline bar, an inverted block). `context` names the host
// so a pack can style each differently. Chrome only: input stays in the host.
StyleDelegate {
    id: sel
    componentId: "RowSelection"

    property string context: ""        // "launcher" | "settingsNav"
    property bool   selected: true
    property bool   hovered: false
    property real   radius: 0

    // Label colour for the selected row: the delegate's optional `selectedText`,
    // else the host's own colour.
    function textColor(fallback) {
        var c = sel.active ? sel.item.selectedText : undefined
        return (c !== undefined && c !== null && c !== "") ? c : fallback
    }

    api: ({
        "context":  sel.context,
        "selected": sel.selected,
        "hovered":  sel.hovered,
        "radius":   sel.radius,
        "palette":  Commons.Appearance.colors
    })
}
