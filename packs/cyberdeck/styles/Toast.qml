import QtQuick

// Cyberdeck Netrunner: notification toast housing (adr_027 Layer C delegate for
// Toast). The cut MetalSurface plate with an accent edge (red when critical),
// and an "INCOMING TRANSMISSION" caption read back by the host in place of the
// app name. No Commons import: everything arrives through `api`.
Item {
    id: toast
    property var api: ({})
    property string register: ""

    readonly property var  _p:        api.palette
    readonly property bool _critical: api.urgency === 2

    // Read back by the host (docs/STYLE_API.md, Toast).
    readonly property string caption:      _critical ? "PRIORITY ALERT" : "INCOMING TRANSMISSION"
    readonly property color  captionColor: !_p ? "transparent" : _critical ? _p.red : _p.yellow
    readonly property bool   hideIcon:     true
    readonly property bool   dataBody:     true

    MetalSurface {
        anchors.fill: parent
        api: ({ "chamfer": 6, "palette": toast._p,
                "edge": toast._p ? (toast._critical ? toast._p.red : toast._p.accent) : undefined })
    }
}
