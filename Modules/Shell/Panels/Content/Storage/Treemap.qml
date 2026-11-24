pragma ComponentBehavior: Bound
import QtQuick
import "../../../../../Commons" as Commons
import "../../../../../Services/System/StorageLogic.js" as Logic

// Two-level squarified treemap of one folder (item_183, owner pick "ExploreB"):
// each sub-folder is a frame with a name / size strip and its own sub-folders
// as boxes inside; a folder too small for a strip, a file and the lumped
// "N more folders" / "files" nodes are one box. A box's area is its share of
// the bytes; its colour is its cleanup tier (theme tokens, so it follows the
// theme): safe green, review peach, your files the accent, the rest neutral.
// One HoverHandler + TapHandler for the whole map, hit-testing the layout, so
// a few hundred boxes cost no handlers of their own.
Item {
    id: map
    property var node: null              // { children: [...] } of the folder shown
    property var hovered: null           // the hovered node (set by the view, from hover here or the list)
    signal hover(var node)               // the node under the pointer (null over a gap)
    signal open(var node)                // a folder box or frame strip was clicked

    // Sizes with no Appearance token, named once: the strip under a folder's
    // name, the smallest frame that gets boxes, the smallest box that gets a label.
    readonly property int _strip: Commons.Appearance.font.sizeBase + Commons.Appearance.spacing.s2
    readonly property int _minFrame: Commons.Appearance.spacing.s10
    readonly property int _minLabelW: Commons.Appearance.spacing.s12 + Commons.Appearance.spacing.s2
    readonly property int _pad: Commons.Appearance.spacing.s1 + 2
    // { frames: [{x, y, w, h, item, kids, strip}], boxes: [{x, y, w, h, item, tier}] }
    // The size it is laid out for follows width / height after a short settle,
    // so a resize does not rebuild every box on every frame.
    property real _w: 0
    property real _h: 0
    function _settle() { _w = width; _h = height }
    onWidthChanged: _w > 0 ? settle.restart() : _settle()
    onHeightChanged: _h > 0 ? settle.restart() : _settle()
    Timer { id: settle; interval: 60; onTriggered: map._settle() }
    readonly property var _layout: _build(node, _w, _h)
    // A new layout (resize, grafted scan) under a still pointer: hit-test again.
    on_LayoutChanged: if (hov.hovered) map.hover(map._at(hov.point.position.x, hov.point.position.y))

    function _build(n, w, h) {
        var frames = [], boxes = []
        if (!n || !n.children || w <= 0 || h <= 0) return { frames: frames, boxes: boxes }
        var l1 = Logic.treemap(n.children, 0, 0, w, h)
        for (var i = 0; i < l1.length; i++) {
            var r = l1[i], it = r.item
            var f = { x: r.x + 1, y: r.y + 1, w: Math.max(0, r.w - 2), h: Math.max(0, r.h - 2), item: it }
            var kids = it.kind === "dir" && (it.children || []).length > 0 && f.w > map._minFrame && f.h > map._minFrame
            f.kids = kids
            f.strip = kids && f.h > map._minFrame + map._strip * 1.4 ? map._strip : 0
            frames.push(f)
            if (!kids) continue
            var l2 = Logic.treemap(it.children, f.x + 1, f.y + 1 + f.strip, f.w - 2, f.h - 2 - f.strip)
            for (var j = 0; j < l2.length; j++) {
                var b = l2[j]
                if (b.w < 3 || b.h < 3) continue
                boxes.push({ x: b.x + 1, y: b.y + 1, w: b.w - 2, h: b.h - 2, item: b.item, tier: b.item.tier || it.tier || "" })
            }
        }
        return { frames: frames, boxes: boxes }
    }

    // The node under (x, y): a box first, else the frame (its strip or a gap).
    function _at(x, y) {
        var bs = _layout.boxes, fs = _layout.frames, i
        for (i = 0; i < bs.length; i++)
            if (x >= bs[i].x && x < bs[i].x + bs[i].w && y >= bs[i].y && y < bs[i].y + bs[i].h) return bs[i].item
        for (i = 0; i < fs.length; i++)
            if (x >= fs[i].x && x < fs[i].x + fs[i].w && y >= fs[i].y && y < fs[i].y + fs[i].h) return fs[i].item
        return null
    }

    function fill(tier, kind) {
        var c = Commons.Appearance.colors
        if (kind === "more" || kind === "files") return c.surface0
        return tier === "safe" ? c.green : tier === "review" ? c.peach : tier === "personal" ? c.accent : c.surface1
    }
    // Label colour on a box: base or textPrimary, whichever contrasts more with
    // the fill (WCAG relative luminance; HSL lightness put dark text on latte's
    // saturated mauve).
    function _lum(col) {
        function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(col.r) + 0.7152 * ch(col.g) + 0.0722 * ch(col.b)
    }
    function _contrast(a, b) {
        var la = _lum(a), lb = _lum(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function ink(fillColor) {
        var c = Commons.Appearance.colors
        return _contrast(fillColor, c.base) >= _contrast(fillColor, c.textPrimary) ? c.base : c.textPrimary
    }
    function _same(a, b) { return !!a && !!b && a.path === b.path && a.kind === b.kind && a.name === b.name }

    // ── Frames: one per sub-folder of the shown folder ─────────────────────
    Repeater {
        model: map._layout.frames
        delegate: Rectangle {
            id: frame
            required property var modelData
            readonly property var n: modelData.item
            readonly property bool hot: map._same(map.hovered, n)
            x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
            radius: Commons.Appearance.radius.xs
            color: modelData.kids ? Commons.Appearance.colors.mantle : map.fill(n.tier || "", n.kind)
            border.width: hot ? 2 : 1
            border.color: hot ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.crust

            // The strip: the folder's name and size (a click on it opens the folder).
            Item {
                visible: frame.modelData.strip > 0
                width: parent.width; height: frame.modelData.strip
                clip: true
                Text {
                    x: map._pad; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - sizeT.implicitWidth - 3 * map._pad
                    text: frame.n.name
                    elide: Text.ElideRight
                    color: Commons.Appearance.colors.textPrimary
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeBase
                    font.weight: Commons.Appearance.font.weightSemibold
                }
                Text {
                    id: sizeT
                    anchors.right: parent.right; anchors.rightMargin: map._pad; anchors.verticalCenter: parent.verticalCenter
                    text: Logic.formatBytes(frame.n.bytes)
                    color: Commons.Appearance.colors.subtext0
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeBase
                }
            }
            // A frame without boxes inside: one box with its own label.
            Column {
                visible: !frame.modelData.kids && frame.width > map._minLabelW && frame.height > map._strip
                x: map._pad; y: Commons.Appearance.spacing.s1
                width: frame.width - 2 * map._pad
                Text {
                    width: parent.width
                    text: frame.n.name
                    elide: Text.ElideRight
                    color: map.ink(frame.color)
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
                Text {
                    visible: frame.height > 2 * map._strip - Commons.Appearance.spacing.s1
                    text: Logic.formatBytes(frame.n.bytes)
                    color: map.ink(frame.color)
                    opacity: 0.75
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
            }
        }
    }

    // ── Boxes: the sub-folders' own contents ───────────────────────────────
    Repeater {
        model: map._layout.boxes
        delegate: Rectangle {
            id: box
            required property var modelData
            readonly property bool hot: map._same(map.hovered, modelData.item)
            x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
            radius: Math.min(Commons.Appearance.radius.xs, width / 2, height / 2)
            color: map.fill(modelData.tier, modelData.item.kind)
            border.width: hot ? 2 : 0
            border.color: Commons.Appearance.colors.textPrimary
            Column {
                visible: box.width > map._minLabelW && box.height > map._strip
                x: map._pad - 1; y: Commons.Appearance.spacing.s1 - 1
                width: box.width - 2 * map._pad
                Text {
                    width: parent.width
                    text: box.modelData.item.name
                    elide: Text.ElideRight
                    color: map.ink(box.color)
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
                Text {
                    visible: box.height > 2 * map._strip - Commons.Appearance.spacing.s1
                    text: Logic.formatBytes(box.modelData.item.bytes)
                    color: map.ink(box.color)
                    opacity: 0.75
                    font.family: Commons.Appearance.font.mono
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
            }
        }
    }

    HoverHandler {
        id: hov
        cursorShape: { var n = map.hovered; return n && n.kind === "dir" ? Qt.PointingHandCursor : Qt.ArrowCursor }
        // Leaving the map keeps the last box (the view latches it for the card).
        onPointChanged: if (hovered) map.hover(map._at(point.position.x, point.position.y))
    }
    TapHandler {
        onTapped: (ev) => {
            var n = map._at(ev.position.x, ev.position.y)
            if (n && n.kind === "dir") map.open(n)
        }
    }
}
