import QtQuick
import QtQuick.Effects

// A drop shadow that falls only OUTSIDE the glass it lifts.
//
// RectangularShadow fills its whole rect, darkest right under the body. Under
// translucent glass that fill shows through as a dark patch in the middle of the
// panel, lighter towards its edges, and under layer blur its alpha stacks on the
// glass so the compositor blurs the middle fully and the edges only partly
// (scenefx-coverage weights the blur by alpha). So the body is cut out of the
// shadow: what remains is the soft falloff around the free edges.
//
// Place it over the body (anchors.fill: body) as a sibling BEHIND it. `cuts`
// lists the glass areas to cut, in this item's coordinates (default: this rect
// rounded by `radius`); the trim* properties pull the shadow's own rect off this
// item's edges (a neck panel takes it off the attached edge).
Item {
    id: root

    property real radius: 0
    property real blur: 0
    property vector2d offset: Qt.vector2d(0, 0)
    property real spread: 0
    property color color: "transparent"

    property real trimLeft: 0
    property real trimTop: 0
    property real trimRight: 0
    property real trimBottom: 0
    property real shadowRadius: radius

    // [{ x, y, w, h, tl, tr, br, bl }] — rounded rects of glass, item coordinates.
    property var cuts: [{ x: 0, y: 0, w: width, h: height,
                          tl: radius, tr: radius, br: radius, bl: radius }]

    // Room for the blur, offset and spread around the body, so nothing clips.
    readonly property int _m: Math.ceil(blur + spread + Math.max(Math.abs(offset.x), Math.abs(offset.y))) + 2

    Item {
        id: canvas
        visible: root.color.a > 0   // nothing to draw: no layer either
        x: -root._m; y: -root._m
        width: root.width + 2 * root._m
        height: root.height + 2 * root._m
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: cutMask
            maskSpreadAtMin: 1.0   // follow the cut's anti-aliased edge
        }

        RectangularShadow {
            x: root._m + root.trimLeft
            y: root._m + root.trimTop
            width:  Math.max(0, root.width - root.trimLeft - root.trimRight)
            height: Math.max(0, root.height - root.trimTop - root.trimBottom)
            radius: root.shadowRadius
            blur:   root.blur
            offset: root.offset
            spread: root.spread
            color:  root.color
        }
    }

    Item {
        id: cutMask
        x: canvas.x; y: canvas.y
        width: canvas.width; height: canvas.height
        visible: false
        layer.enabled: canvas.visible

        Repeater {
            model: root.cuts
            Rectangle {
                required property var modelData
                x: root._m + modelData.x
                y: root._m + modelData.y
                width: modelData.w
                height: modelData.h
                topLeftRadius: modelData.tl
                topRightRadius: modelData.tr
                bottomRightRadius: modelData.br
                bottomLeftRadius: modelData.bl
                antialiasing: true
                color: "black"
            }
        }
    }
}
