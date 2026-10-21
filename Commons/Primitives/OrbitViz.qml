import QtQuick
import ".." as Commons
import "OrbitLogic.js" as Orbit

// Reusable Canvas "hero visualization": a glowing core with data nodes turning
// around it on a dashed ring, each tied to the core by an animated, sine-
// perturbed energy strand. Node size and strand energy follow the node's value.
//
//   OrbitViz {
//       nodes: [{ label: "CPU", value: 42, color: Commons.Appearance.colors.blue }, …]
//       coreText: "42%"            // optional label inside the core
//       coreColor: Commons.Appearance.colors.accent
//   }
//
// `style: "chain"` lays the nodes in a row instead, linked neighbour to neighbour.
// Perf: the repaint timer (~30 fps) runs ONLY while the item is visible, has a
// size and `animated` is true — a closed panel costs nothing. No layer.enabled.
Item {
    id: root

    property var    nodes: []
    property string style: "orbit"       // "orbit" | "chain"
    property string coreText: ""
    property color  coreColor: Commons.Appearance.colors.accent
    property bool   animated: true
    // Strand wobble, in px at full energy.
    property real   strandAmp: 7

    implicitHeight: 112

    readonly property bool _live: visible && width > 0 && height > 0
    property real _t: 0

    Timer {
        interval: 33
        repeat: true
        running: root._live && root.animated
        onTriggered: { root._t += 0.033; canvas.requestPaint() }
    }
    on_LiveChanged: if (_live) canvas.requestPaint()
    onNodesChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onCoreColorChanged: canvas.requestPaint()

    // Core text rides above the canvas so it stays crisp.
    Text {
        visible: root.style === "orbit" && root.coreText.length > 0
        anchors.centerIn: parent
        text: root.coreText
        color: Commons.Appearance.colors.textPrimary
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeMd
        font.bold: true
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        // Cheap raster canvas; Qt keeps the backing store on the render thread.
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        function _glow(ctx, x, y, r, col, a) {
            var g = ctx.createRadialGradient(x, y, 0, x, y, r)
            g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, a))
            g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0))
            ctx.fillStyle = g
            ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill()
        }

        function _strand(ctx, a, b, col, value, seed, reach) {
            var dist = Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y))
            var amp = root.animated ? root.strandAmp * (0.25 + 0.75 * Math.min(1, value / 100)) : 0
            var pts = Orbit.strandPoints(a.x, a.y, b.x, b.y, root._t, amp, seed, 24)
            var al = Orbit.strandAlpha(dist, reach, value)
            // Soft wide pass under a crisp thin one reads as glow.
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            var passes = [{ w: 3.5, k: 0.28 }, { w: 1.3, k: 1.0 }]
            for (var q = 0; q < passes.length; q++) {
                ctx.lineWidth = passes[q].w
                ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, al * passes[q].k)
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
                ctx.stroke()
            }
        }

        function _node(ctx, p, n, r) {
            _glow(ctx, p.x, p.y, r * 3.2, n.color, 0.35)
            ctx.fillStyle = n.color
            ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill()
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.25)
            ctx.beginPath(); ctx.arc(p.x - r * 0.3, p.y - r * 0.3, r * 0.35, 0, Math.PI * 2); ctx.fill()
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var ns = root.nodes || []
            if (w <= 0 || h <= 0 || ns.length === 0) return
            var cx = w / 2, cy = h / 2
            var cc = root.coreColor
            var t = root._t

            if (root.style === "chain") {
                var padX = Math.max(28, w * 0.1), n = ns.length
                var step = n > 1 ? (w - 2 * padX) / (n - 1) : 0
                var pts = []
                for (var i = 0; i < n; i++)
                    pts.push({ x: n > 1 ? padX + step * i : cx,
                               y: cy - 8 + Math.sin(t * 0.9 + i * 1.3) * 5 })
                for (var j = 0; j + 1 < n; j++)
                    _strand(ctx, pts[j], pts[j + 1], ns[j].color, (ns[j].value + ns[j + 1].value) / 2, j, step * 1.5)
                for (var k = 0; k < n; k++) {
                    var rr = Orbit.nodeRadius(ns[k].value, 6, 13)
                    _node(ctx, pts[k], ns[k], rr)
                    ctx.fillStyle = Commons.Appearance.colors.textSecondary
                    ctx.font = Commons.Appearance.font.sizeSm + "px " + Commons.Appearance.font.family
                    ctx.textAlign = "center"; ctx.textBaseline = "top"
                    ctx.fillText(ns[k].label + " " + Math.round(ns[k].value) + "%", pts[k].x, pts[k].y + rr + 8)
                }
                return
            }

            // ── orbit ──
            // Ring leaves room for node glow and a label under the lowest node.
            var rx = Math.max(10, w * 0.5 - 84), ry = Math.max(8, h * 0.5 - 22)
            var energy = 0
            for (var e = 0; e < ns.length; e++) energy += ns[e].value
            energy = energy / (ns.length * 100)

            // dashed orbit ring
            ctx.lineWidth = 1
            ctx.strokeStyle = Qt.rgba(cc.r, cc.g, cc.b, 0.28)
            if (ctx.setLineDash) ctx.setLineDash([3, 5])
            ctx.beginPath()
            ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
            ctx.stroke()
            if (ctx.setLineDash) ctx.setLineDash([])

            // core: breathing halo scaled by overall load
            var pulse = 1 + 0.08 * Math.sin(t * 2.1)
            _glow(ctx, cx, cy, (24 + 18 * energy) * pulse, cc, 0.7)
            ctx.fillStyle = cc
            ctx.beginPath(); ctx.arc(cx, cy, (5 + 3 * energy) * pulse, 0, Math.PI * 2); ctx.fill()
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.3)
            ctx.beginPath(); ctx.arc(cx - 1.5, cy - 1.5, 2, 0, Math.PI * 2); ctx.fill()

            var reach = Math.max(rx, ry)
            var placed = []
            for (var m = 0; m < ns.length; m++) placed.push(Orbit.nodePos(m, ns.length, t, cx, cy, rx, ry))
            for (var s = 0; s < ns.length; s++) _strand(ctx, { x: cx, y: cy }, placed[s], ns[s].color, ns[s].value, s, reach)
            for (var d = 0; d < ns.length; d++) {
                var r = Orbit.nodeRadius(ns[d].value, 5, 11)
                _node(ctx, placed[d], ns[d], r)
                ctx.fillStyle = Commons.Appearance.colors.textSecondary
                ctx.font = Commons.Appearance.font.sizeSm + "px " + Commons.Appearance.font.family
                ctx.textAlign = placed[d].x >= cx ? "left" : "right"
                ctx.textBaseline = "middle"
                ctx.fillText(ns[d].label + " " + Math.round(ns[d].value) + "%", placed[d].x + (placed[d].x >= cx ? r + 6 : -r - 6), placed[d].y)
            }
        }
    }
}
