pragma ComponentBehavior: Bound
import QtQuick
import "../../../Commons" as Commons
import "../../../Services/Hardware" as Hardware
import "../../../Services/Hardware/DisplaysLogic.js" as Logic

// Monitor arrangement canvas (item_135 wave 1): the enabled outputs drawn to
// scale in their logical size (rotation swaps w/h, scale divides), fitted to
// the canvas. Click selects; drag moves an output and, on release, snaps it
// flush against the nearest neighbour edge (never overlapping) with edges
// aligned within a threshold. The layout is re-normalised to start at 0,0.
// Stateless: `outputs` is the caller's staged list; edits come back as signals.
Item {
    id: root

    property var    outputs: []        // staged, same shape as Displays.outputs
    property string selected: ""
    signal select(string name)
    signal moved(string name, int x, int y)

    implicitHeight: 220

    readonly property var _shown: outputs.filter(o => o.enabled)
    // Layout bounds (logical px) and the fit scale into the canvas.
    readonly property var _bounds: {
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
        for (var i = 0; i < _shown.length; i++) {
            var o = _shown[i], s = Hardware.Displays.logicalSize(o)
            x0 = Math.min(x0, o.x); y0 = Math.min(y0, o.y)
            x1 = Math.max(x1, o.x + s.w); y1 = Math.max(y1, o.y + s.h)
        }
        return _shown.length ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 }
    }
    readonly property real _pad: Commons.Appearance.spacing.s4
    readonly property real _k: Math.min((width - 2 * _pad) / Math.max(1, _bounds.w),
                                        (height - 2 * _pad) / Math.max(1, _bounds.h))
    readonly property real _ox: (width - _bounds.w * _k) / 2
    readonly property real _oy: (height - _bounds.h * _k) / 2

    // Snapping lives in DisplaysLogic.js (tested in tests/qml/tst_displayslogic.qml).
    function snap(name, px, py) { return Logic.snap(root.outputs, name, px, py) }

    Rectangle {
        anchors.fill: parent
        radius: Commons.Appearance.radius.md
        color: Commons.Appearance.colors.recessedTrack
    }

    Repeater {
        model: root._shown
        delegate: Rectangle {
            id: tile
            required property var modelData
            readonly property var _s: Hardware.Displays.logicalSize(tile.modelData)
            readonly property bool _sel: tile.modelData.name === root.selected
            // Where the model puts the tile on the canvas (x/y bind to these).
            readonly property real _homeX: root._ox + (tile.modelData.x - root._bounds.x) * root._k
            readonly property real _homeY: root._oy + (tile.modelData.y - root._bounds.y) * root._k
            x: _homeX
            y: _homeY
            width:  Math.max(24, _s.w * root._k)
            height: Math.max(24, _s.h * root._k)
            radius: Commons.Appearance.radius.sm
            color: _sel ? Commons.Appearance.colors.accentAlpha
                 : drag.containsMouse ? Commons.Appearance.colors.stateHover : Commons.Appearance.colors.surfaceCard
            border.width: _sel || drag.containsMouse ? 2 : 1
            border.color: _sel ? Commons.Appearance.colors.accent
                        : drag.containsMouse ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.borderStrong
            z: drag.drag.active ? 10 : (_sel ? 2 : 1)

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.modelData.name
                    color: Commons.Appearance.colors.textPrimary
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeBase
                    font.weight: Commons.Appearance.font.weightMedium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile._s.w + "×" + tile._s.h
                    color: Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.size2xs
                    visible: tile.height > 40
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: tile
                drag.threshold: 4
                onPressed: root.select(tile.modelData.name)
                hoverEnabled: true
                onReleased: {
                    // Only a real drag moves the output; a click just selected it.
                    if (drag.drag.active || tile.x !== tile._homeX || tile.y !== tile._homeY) {
                        // Canvas → logical, then snap and hand back.
                        var lx = root._bounds.x + (tile.x - root._ox) / root._k
                        var ly = root._bounds.y + (tile.y - root._oy) / root._k
                        var p = root.snap(tile.modelData.name, lx, ly)
                        root.moved(tile.modelData.name, p.x, p.y)
                    }
                    // Always re-bind to the model (dragging broke the x/y bindings).
                    tile.x = Qt.binding(() => tile._homeX)
                    tile.y = Qt.binding(() => tile._homeY)
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root._shown.length === 0
        text: Hardware.Displays.ready ? "No enabled outputs" : "Reading outputs…"
        color: Commons.Appearance.colors.textMuted
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeBase
    }
}
