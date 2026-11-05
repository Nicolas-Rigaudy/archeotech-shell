pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: strip key (adr_027 Layer C delegate for StripButton).
// A sheared slot with a teal hairline behind each icon, leaning like the bar
// zones; the open panel's key takes an accent edge and wash (the widget keeps
// its own accent icon, so the slot never goes solid), hover a fainter wash.
Item {
    id: key
    property var api: ({})
    property string register: ""

    readonly property var  _p:   api.palette
    readonly property bool _on:  api.active === true
    readonly property bool _hov: api.hovered === true
    readonly property bool _vert: api.side === "left" || api.side === "right"

    Rectangle {
        id: slot
        anchors.centerIn: parent
        width:  key._vert ? Math.min(32, key.width - 2) : Math.min(40, key.width - 2)
        height: key._vert ? Math.min(32, key.height - 2) : Math.min(28, key.height - 2)
        antialiasing: true
        color: !key._p ? "transparent"
             : key._on ? Qt.rgba(key._p.accent.r, key._p.accent.g, key._p.accent.b, 0.22)
             : key._hov ? Qt.rgba(key._p.accent.r, key._p.accent.g, key._p.accent.b, 0.14)
             : Qt.rgba(0.02, 0.05, 0.07, 0.7)
        border.width: key._on ? 1.5 : 1
        border.color: !key._p ? "transparent" : key._on ? key._p.accent : Qt.lighter(key._p.surface2, 1.45)
        transform: Shear { xFactor: key._vert ? 0 : -0.3; origin.y: slot.height / 2 }
    }
}
