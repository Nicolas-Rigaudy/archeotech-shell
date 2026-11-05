pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: selected list row (adr_027 Layer C delegate for
// RowSelection). A faint accent wash with a solid accent tick on the left
// edge; hover is the wash alone at half strength.
Item {
    id: row
    property var api: ({})
    property string register: ""

    readonly property var _p: api.palette
    readonly property bool _on: api.selected === true
    readonly property bool _hov: api.hovered === true
    property color selectedText: _p ? _p.accent : "white"

    Rectangle {
        anchors.fill: parent
        visible: !!row._p && (row._on || row._hov)
        color: row._p ? Qt.rgba(row._p.accent.r, row._p.accent.g, row._p.accent.b, row._on ? 0.14 : 0.07) : "transparent"
        border.width: row._on ? 1 : 0
        border.color: row._p ? Qt.rgba(row._p.accent.r, row._p.accent.g, row._p.accent.b, 0.45) : "transparent"
    }
    Rectangle {
        visible: !!row._p && row._on
        x: 0; y: 4; width: 3; height: parent.height - 8
        color: row._p ? row._p.accent : "transparent"
    }
}
