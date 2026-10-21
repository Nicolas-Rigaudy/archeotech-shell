import QtQuick
import "../../../../Commons" as Commons
import "../../../../Commons/Primitives" as Prim

// SystemStatus face: "orbit" — the same cpu/ram/disk/bat data as four nodes
// circling a glowing core, tied to it by animated energy strands (Canvas hero
// viz, Commons/Primitives/OrbitViz). Node size and strand energy follow load.
// Binds to `card`.
Prim.OrbitViz {
    id: face
    property var card

    implicitHeight: 112
    coreColor: Commons.Appearance.colors.accent

    readonly property int _bat: card ? card.bat : 0
    nodes: [
        { label: "CPU",  value: card ? card.cpu  : 0, color: Commons.Appearance.colors.blue },
        { label: "RAM",  value: card ? card.ram  : 0, color: Commons.Appearance.colors.mauve },
        { label: "Disk", value: card ? card.disk : 0, color: Commons.Appearance.colors.peach },
        { label: "Bat",  value: _bat, color: _bat > 20 ? Commons.Appearance.colors.green : Commons.Appearance.colors.red }
    ]
}
