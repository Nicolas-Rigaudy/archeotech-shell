pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: workspace tag (adr_027 Layer C delegate for
// WorkspaceCell). A sheared square: the current tag is a long filled accent
// bar, occupied tags an accent outline, empty ones a dim outline.
Item {
    id: cell
    property var api: ({})
    property string register: ""

    readonly property var  _p:   api.palette
    readonly property bool _sel: api.selected === true
    readonly property bool _occ: api.occupied === true
    readonly property bool _urg: api.urgent === true

    implicitWidth: 22
    implicitHeight: 20

    Rectangle {
        anchors.centerIn: parent
        width: cell._sel ? 16 : 9
        height: 9
        antialiasing: true
        color: !cell._p ? "transparent" : cell._sel ? cell._p.accent : cell._urg ? cell._p.red : "transparent"
        border.width: 1
        border.color: !cell._p ? "transparent"
                    : cell._urg ? cell._p.red
                    : (cell._sel || cell._occ) ? cell._p.accent : cell._p.overlay0
        transform: Shear { xFactor: -0.4; origin.y: 4.5 }
        // Host-scaled duration (anim speed, reduce motion); 120 ms if absent.
    Behavior on width { NumberAnimation { duration: cell.api.animMs !== undefined ? cell.api.animMs : 120 } }
    }
}
