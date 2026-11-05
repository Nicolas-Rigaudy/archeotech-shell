import QtQuick

// Cyberdeck Netrunner: launch housings (adr_027 Layer C delegate for
// LaunchTile). One cut plate for every launch surface; `api.context` says
// which: "tile" (dashboard quick launch), "recent" (launcher recents),
// "search" (launcher search box, accent edge on focus, "> " prompt) or "row"
// (launcher result: an index gutter, accent edge + wash when selected).
// Hover lifts tiles with a wash.
Item {
    id: tile
    property var api: ({})
    property string register: ""

    readonly property var    _p:   api.palette
    readonly property string _ctx: api.context || "tile"
    readonly property bool   _lit: api.selected === true || api.focused === true

    // Read back by the host: the search prompt glyph and the row lead gutter.
    readonly property string glyph:     _ctx === "search" ? ">" : ""
    readonly property int    leadInset: _ctx === "row" ? 26 : 0

    MetalSurface {
        anchors.fill: parent
        api: ({ "chamfer": tile._ctx === "row" ? 4 : 5, "palette": tile._p,
                "edge": tile._lit && tile._p ? tile._p.accent : undefined })
    }
    // Selected row / focused search / hovered tile: an accent wash.
    Rectangle {
        anchors.fill: parent; anchors.margins: 3
        visible: !!tile._p && (tile._lit || tile.api.hovered === true)
        color: tile._p ? Qt.rgba(tile._p.accent.r, tile._p.accent.g, tile._p.accent.b,
                                 tile._lit ? 0.12 : 0.10) : "transparent"
    }
    // Row index, zero-padded (mock "01".."05"), in the lead gutter.
    Text {
        visible: tile._ctx === "row" && !!tile._p && tile.api.index !== undefined
        x: 12; anchors.verticalCenter: parent.verticalCenter
        text: ("0" + ((tile.api.index || 0) + 1)).slice(-2)
        color: tile._p ? (tile._lit ? tile._p.accent : tile._p.overlay1) : "transparent"
        font { family: tile.api.font ? tile.api.font.mono : "monospace"; pixelSize: 11 }
    }
}
