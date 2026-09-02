import QtQuick
import QtQuick.Shapes
import "../../Commons" as Commons

// Decorator/FX overlay for the shell frame (adr_027 Wave 2, Layer B).
//
// ADDITIVE, pack-gated chrome mounted once over the FrameBackground (never
// per-widget). A theme pack's `fx` block drives it; with no pack (or no fx) every
// effect is off and NOTHING draws — the base look is untouched. Anchors to the
// content-hole geometry the frame publishes, so effects sit on the exact edges/
// corners the frame draws. Purely decorative: it never adds to the input mask, so
// the content hole stays click-through.
//
// Frame-scoped effects (each optional, all off by default):
//   fx.texture  { source, opacity }               — tiled texture over the frame chrome
//   fx.glow     { enabled, color, strength, size } — accent glow on the frame's content edge
// (fx.brackets draws per-WINDOW in WindowBrackets.qml, not here.)
//
// Paint order (declaration order at equal z): texture ▸ glow.
Item {
    id: fx

    // Content-hole rect + inner corner radius (from FrameBackground).
    property rect contentRect: Qt.rect(0, 0, 0, 0)
    property int  cornerRadius: 0
    property string packDir: ""            // active pack dir (texture source base)

    readonly property var _fx: Commons.Appearance.fx
    readonly property bool _hasHole: contentRect.width > 0 && contentRect.height > 0

    // ── Background texture ───────────────────────────────────────────────────
    // Tiled over the four frame bands (never the content hole). packDir is
    // absolute with a trailing slash; source is pack-relative.
    readonly property var    _tx:        _fx.texture || ({})
    readonly property bool   _txOn:      !!_tx.source && _hasHole && packDir !== ""
    readonly property string _txSource:  _tx.source ? ("file://" + packDir + _tx.source) : ""
    readonly property real   _txOpacity: _tx.opacity !== undefined ? _tx.opacity : 0.08
    // Band rects around the hole: top, bottom, left, right.
    readonly property var _bands: !_txOn ? [] : [
        Qt.rect(0, 0, width, contentRect.y),
        Qt.rect(0, contentRect.y + contentRect.height, width, height - contentRect.y - contentRect.height),
        Qt.rect(0, contentRect.y, contentRect.x, contentRect.height),
        Qt.rect(contentRect.x + contentRect.width, contentRect.y, width - contentRect.x - contentRect.width, contentRect.height)
    ]
    Repeater {
        model: fx._bands
        delegate: Image {
            source: fx._txSource
            fillMode: Image.Tile
            opacity: fx._txOpacity
            x: modelData.x; y: modelData.y
            width: modelData.width; height: modelData.height
        }
    }

    // ── Accent rim glow ──────────────────────────────────────────────────────
    // A soft accent rim tracing the ROUNDED content-hole edge, blurred so it is
    // continuous through the corners (the old 4-band version left the corner arc
    // dark — a harsh seam). A transparent rounded rect whose accent border is
    // blurred by MultiEffect; the layer is grown by _glSize so the outward blur
    // isn't clipped. Non-interactive, so layer.enabled is fine here.
    readonly property var   _gl:         _fx.glow || ({})
    readonly property bool  _glOn:       !!_gl.enabled && _hasHole
    readonly property color _glColor:    Commons.Appearance.fxColor(_gl.color, Commons.Appearance.colors.accent)
    readonly property real  _glStrength: _gl.strength !== undefined ? _gl.strength : 0.5
    readonly property int   _glSize:     _gl.size !== undefined ? _gl.size : 24
    readonly property color _glEdge:     Qt.rgba(_glColor.r, _glColor.g, _glColor.b, _glStrength)

    // Glow lives ON THE FRAME (bar/strip side of the content edge), NOT over the
    // windows: four gradient bands, accent strongest at the content edge, fading
    // out into the frame. Top/bottom span the FULL width so the corners (frame
    // above/below the side strips) are covered — no dark corner seam.
    Rectangle {   // top — on the bar, accent at the content edge, fading up
        visible: fx._glOn
        x: 0; y: fx.contentRect.y - fx._glSize
        width: fx.width; height: fx._glSize
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: fx._glEdge }
        }
    }
    Rectangle {   // bottom
        visible: fx._glOn
        x: 0; y: fx.contentRect.y + fx.contentRect.height
        width: fx.width; height: fx._glSize
        gradient: Gradient {
            GradientStop { position: 0.0; color: fx._glEdge }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {   // left strip — accent at the content edge, fading left
        visible: fx._glOn
        x: fx.contentRect.x - fx._glSize; y: fx.contentRect.y
        width: fx._glSize; height: fx.contentRect.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: fx._glEdge }
        }
    }
    Rectangle {   // right strip
        visible: fx._glOn
        x: fx.contentRect.x + fx.contentRect.width; y: fx.contentRect.y
        width: fx._glSize; height: fx.contentRect.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: fx._glEdge }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Frame chassis (NMM steel) ────────────────────────────────────────────────
    // Per-band tight, HIGH-CONTRAST NMM steel cross-sections (deep shadow → bright
    // ridge packed across the band) so each rail reads as painted metal. The
    // different gradient DIRECTIONS where bands meet are covered by a bevelled
    // corner bracket-plate (below), turning the junction into a deliberate fitting.
    // FLAT welded panel face (top-lit), NOT a tube cross-section: the four bands share
    // one tonal family with a gentle top→bottom fall, so the frame reads as a single
    // machined bezel rather than four pipes. (Old NMM ridge caused the tube look.)
    readonly property bool  _rlOn:   !!(_fx.rails && _fx.rails.enabled) && _hasHole
    readonly property color _stHi:   Qt.lighter(Commons.Appearance.colors.surface2, 1.45)  // (kept for compat)
    readonly property color _stMid:  "#2b3542"
    readonly property color _stLo:   Qt.darker(Commons.Appearance.colors.mantle, 1.12)
    readonly property color _faHi:   "#333f4d"   // top-lit face
    readonly property color _faMd:   "#28313d"   // body face
    readonly property color _faLo:   "#1c232d"   // lower face
    Rectangle {   // top band (bar) — top-lit flat panel
        visible: fx._rlOn && fx.contentRect.y > 1
        x: 0; y: 0; width: fx.width; height: fx.contentRect.y
        gradient: Gradient {
            GradientStop { position: 0.00; color: fx._faHi }
            GradientStop { position: 0.22; color: fx._faMd }
            GradientStop { position: 1.00; color: fx._faLo }
        }
    }
    Rectangle {   // bottom band — flat panel
        visible: fx._rlOn && (fx.height - fx.contentRect.y - fx.contentRect.height) > 1
        x: 0; y: fx.contentRect.y + fx.contentRect.height
        width: fx.width; height: fx.height - fx.contentRect.y - fx.contentRect.height
        gradient: Gradient {
            GradientStop { position: 0.00; color: fx._faMd }
            GradientStop { position: 1.00; color: fx._faLo }
        }
    }
    Rectangle {   // left band (rail) — flat
        visible: fx._rlOn && fx.contentRect.x > 1
        x: 0; y: fx.contentRect.y; width: fx.contentRect.x; height: fx.contentRect.height
        color: fx._faMd
    }
    Rectangle {   // right band (rail) — flat
        visible: fx._rlOn && (fx.width - fx.contentRect.x - fx.contentRect.width) > 1
        x: fx.contentRect.x + fx.contentRect.width; y: fx.contentRect.y
        width: fx.width - fx.contentRect.x - fx.contentRect.width; height: fx.contentRect.height
        color: fx._faMd
    }

    // ── Adaptive corner brackets (procedural, per-junction) ──────────────────────
    // Replaces the fixed corner PNG. One machined steel plate per corner, built from
    // the content-hole insets + chamfer size: each arm's WIDTH = its member's
    // thickness (bar ~30 / strip ~16), the inner edge follows the 45° chamfer, the
    // outer screen corner is solid. Lit by ONE per-corner diagonal gradient (bright
    // at the outer screen corner → dark toward content) so the two arms read as a
    // single piece — no inter-band seam. A full-perimeter bevel (bright rim on the
    // light-facing edges, dark cliff on the inner/arm-end edges) makes it a RAISED
    // plate; copper rivets bolt it down (corner stud + one per arm). Adjacent side
    // none/holder ⇒ that inset is 0 ⇒ the member terminates as an end-cap instead of
    // a junction bracket. Chamfered frames only; drawn under the copper bezel.
    // Fixed steel for the plate face (the Grimdark armour is
    // always this cool steel; only the copper trim follows the accent). Tuned tones,
    // brighter than the derived chassis so the plate reads as a RAISED piece.
    readonly property bool  _coOn:     _rlOn && Commons.Appearance.frameChamfer
    readonly property color _faceHi:   "#3a4757"   // facet hotspot at the outer corner
    readonly property color _faceMd:   "#2c3644"
    readonly property color _faceLo:   "#1a212b"   // toward the content
    readonly property color _coLit:    "#cdd9e8"   // lit outer bevel
    readonly property color _coShadow: "#05080d"   // cut / inlay shadow

    // Chamfer corner treatment kept SMALL and at the content edge — a tiny wedge that
    // fills the chamfer gap the flat rect-bands leave (so no glass shows through),
    // matching the band, with a faint lit line along the 45° cut. It lives entirely in
    // the frame border at the content corner, so it never reaches into the bar's widget
    // zone (the old full-depth facet clipped the workspace/power icons). Chamfered frames
    // only; a zero-inset side is skipped.
    readonly property var _corners: {
        if (!_coOn || !_hasHole || cornerRadius < 1) return []
        var cr = contentRect, cham = cornerRadius
        var rgt = width - cr.x - cr.width, bot = height - cr.y - cr.height
        var C = [
            [cr.x,          cr.y,           1,  1, cr.y, cr.x],
            [cr.x+cr.width, cr.y,          -1,  1, cr.y, rgt],
            [cr.x,          cr.y+cr.height, 1, -1, bot,  cr.x],
            [cr.x+cr.width, cr.y+cr.height,-1, -1, bot,  rgt]
        ]
        var out = []
        for (var i = 0; i < C.length; i++) {
            var px = C[i][0], py = C[i][1], sx = C[i][2], sy = C[i][3], thH = C[i][4], thW = C[i][5]
            if (thH <= 1 || thW <= 1) continue
            var hx = px + sx*cham, hy = py            // chamfer end on the horizontal edge
            var vx = px,           vy = py + sy*cham  // chamfer end on the vertical edge
            out.push({ fill: "M " + px + " " + py + " L " + hx + " " + hy + " L " + vx + " " + vy + " Z",
                       cut:  "M " + hx + " " + hy + " L " + vx + " " + vy })
        }
        return out
    }
    Repeater {
        model: fx._corners
        delegate: Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false
            readonly property var cd: modelData
            ShapePath {                                       // fill the chamfer gap, matching the band
                fillColor: fx._faMd
                strokeWidth: 0; strokeColor: "transparent"
                PathSvg { path: cd.fill }
            }
            ShapePath {                                       // faint lit machined line along the cut
                fillColor: "transparent"; strokeColor: Qt.rgba(0.8, 0.85, 0.9, 0.35)
                strokeWidth: 1; capStyle: ShapePath.FlatCap
                PathSvg { path: cd.cut }
            }
        }
    }

    // ── Bevel (adr_027 / item_083: depth) ───────────────────────────────────────
    // A thin machined "lip" tracing the content-hole edge — reads as the metal
    // bezel of a recessed screen, restoring dimension a flat matte fill loses.
    // fx.bevel = { enabled, color, width }.
    readonly property var   _bev:      _fx.bevel || ({})
    readonly property bool  _bevOn:    !!_bev.enabled && _hasHole
    readonly property color _bevColor: Commons.Appearance.fxColor(_bev.color, Commons.Appearance.colors.overlay1)
    readonly property int   _bevW:     _bev.width !== undefined ? _bev.width : 2
    // Copper molding trim — one lit bevel bead per content edge instead of a flat
    // border line. A cross-section gradient (bright toward the top-left light
    // source → dark) reads as rounded metal, so the copper stops looking painted.
    // NON-METALLIC-METAL copper (miniature painting): a smooth, high-contrast
    // painted gradient — bright hotspot, mid copper, deep shadow, faint bounce —
    // NOT a brushed/flake texture. Reads as polished copper trim.
    readonly property color _cuHi:     Qt.lighter(fx._bevColor, 1.95)   // hotspot
    readonly property color _cuMid:    fx._bevColor                     // body copper
    readonly property color _cuLo:     Qt.darker(fx._bevColor, 2.3)     // core shadow
    readonly property color _cuBounce: Qt.darker(fx._bevColor, 1.4)     // reflected light
    readonly property int   _cuW:      Math.max(4, fx._bevW + 1)
    readonly property int   _cr:       Math.max(0, fx.cornerRadius)   // = chamfer size

    // ONE continuous copper bezel, stroked along the (chamfered) content-hole
    // outline. Replaces the per-edge beads + corner pieces + wedges — a single
    // path has no junctions, so no seams/gaps can appear at any corner on any
    // monitor. Three concentric strokes fake an NMM cross-section (dark edges →
    // bright centre ridge). The path mirrors the FrameBackground shape: 45°
    // chamfered corners when the pack requests it, else square.
    // (No separate chamfer wedge — the FrameBackground shape already fills the
    // chamfered corner with the one global steel gradient, so a wedge here would
    // just be a mismatched flat patch.)
    readonly property string _bezelPath: {
        if (!_bevOn) return ""
        // Snap to the pixel grid — a fractional edge x/y makes the CurveRenderer
        // dither the stroke into a mottled/striped copper down that edge (bit the
        // right/bottom edges where the content extent landed off-grid).
        var x0 = Math.round(contentRect.x), y0 = Math.round(contentRect.y)
        var x1 = Math.round(contentRect.x + contentRect.width), y1 = Math.round(contentRect.y + contentRect.height)
        var c = Commons.Appearance.frameChamfer ? _cr : 0
        return "M " + (x0 + c) + " " + y0
             + " L " + (x1 - c) + " " + y0 + " L " + x1 + " " + (y0 + c)
             + " L " + x1 + " " + (y1 - c) + " L " + (x1 - c) + " " + y1
             + " L " + (x0 + c) + " " + y1 + " L " + x0 + " " + (y1 - c)
             + " L " + x0 + " " + (y0 + c) + " Z"
    }
    // Bar content edge only — carries the brass trim (the copper stays a thin line,
    // per the pack rules; the rails get the teal live-edge instead).
    readonly property string _barEdgePath: {
        if (!_bevOn) return ""
        var c = Commons.Appearance.frameChamfer ? _cr : 0
        return "M " + (contentRect.x + c) + " " + contentRect.y
             + " L " + (contentRect.x + contentRect.width - c) + " " + contentRect.y
    }
    Shape {
        visible: fx._bevOn
        anchors.fill: parent
        // GeometryRenderer, NOT CurveRenderer: the bezel is all straight lines, and
        // CurveRenderer dithered these thin axis-aligned copper strokes into a
        // mottled/dashed line (worst on the portrait output).
        preferredRendererType: Shape.GeometryRenderer
        asynchronous: false
        // Copper trim tracing the WHOLE content edge (teal live-edge dropped).
        // Body + lit highlight = the same brass the bar edge had, now all around.
        ShapePath {   // brass body
            fillColor: "transparent"; strokeColor: fx._cuMid
            strokeWidth: 2.4; joinStyle: ShapePath.MiterJoin; capStyle: ShapePath.FlatCap
            PathSvg { path: fx._bezelPath }
        }
        ShapePath {   // brass highlight
            fillColor: "transparent"; strokeColor: fx._cuHi
            strokeWidth: 1; joinStyle: ShapePath.MiterJoin; capStyle: ShapePath.FlatCap
            PathSvg { path: fx._bezelPath }
        }
    }
    // (Corner rivets are drawn as part of the corner bracket-plates above.)
    // (Removed: the "soft inner shadow" black border — it read as a black line all
    //  around the content window; the copper trim now carries the edge.)

    // ── Rivets (adr_027 / item_083: machined-panel studs) ───────────────────────
    // Bolt-heads run along the frame bands just outside the content edge — the
    // biggest "physical machined object" tell. fx.rivets = { enabled, color, size,
    // spacing, inset }. Marks flattened to avoid delegate context-prop clashes.
    readonly property var   _rv:        _fx.rivets || ({})
    readonly property bool  _rvOn:      !!_rv.enabled && _hasHole
    readonly property color _rvColor:   Commons.Appearance.fxColor(_rv.color, Commons.Appearance.colors.overlay1)
    readonly property int   _rvSize:    _rv.size    !== undefined ? _rv.size    : 4
    readonly property int   _rvSpacing: _rv.spacing !== undefined ? _rv.spacing : 44
    readonly property int   _rvInset:   _rv.inset   !== undefined ? _rv.inset   : 8
    readonly property var _rivetMarks: {
        var out = []
        if (!_rvOn) return out
        var cx0 = contentRect.x, cy0 = contentRect.y
        var cx1 = contentRect.x + contentRect.width, cy1 = contentRect.y + contentRect.height
        var sp = Math.max(14, _rvSpacing)
        // top + bottom rows (start/stop inset from corners so they don't crowd the ornament)
        for (var x = cx0 + sp; x < cx1 - sp * 0.5; x += sp) {
            out.push({ cx: x, cy: cy0 - _rvInset })
            out.push({ cx: x, cy: cy1 + _rvInset })
        }
        // left + right columns
        for (var y = cy0 + sp; y < cy1 - sp * 0.5; y += sp) {
            out.push({ cx: cx0 - _rvInset, cy: y })
            out.push({ cx: cx1 + _rvInset, cy: y })
        }
        return out
    }
    Repeater {
        model: fx._rivetMarks
        delegate: Item {
            Rectangle {   // bolt head
                width: fx._rvSize; height: fx._rvSize; radius: fx._rvSize / 2
                x: modelData.cx - fx._rvSize / 2
                y: modelData.cy - fx._rvSize / 2
                color: fx._rvColor
                antialiasing: true
                border.width: 1
                border.color: Qt.darker(fx._rvColor, 1.8)   // seated ring
            }
            Rectangle {   // top-left specular highlight → domed bolt, not a flat dot
                readonly property real _h: Math.max(1.5, fx._rvSize * 0.34)
                width: _h; height: _h; radius: _h / 2
                x: modelData.cx - fx._rvSize * 0.26
                y: modelData.cy - fx._rvSize * 0.26
                color: Qt.lighter(fx._rvColor, 1.6)
                antialiasing: true
            }
        }
    }

    // ── Plate seams (Legion register — segmented bolted armour rails) ─────────
    // Perpendicular seam ticks across the SIDE + BOTTOM bands at intervals, each
    // capped by a copper bolt-pair: the rails read as bolted steel plates, not
    // empty bands with a line. The TOP band is skipped (the bar owns its own
    // console). Off by default. fx.seams = { enabled, color, bolt, spacing }.
    // Shared domed-rivet image (baked highlight/shadow) for the frame fittings.
    readonly property string _rivetSrc: packDir === "" ? "" : ("file://" + packDir + "panels/rivet.png")
    readonly property var   _sm:        _fx.seams || ({})
    readonly property bool  _smOn:      !!_sm.enabled && _hasHole
    readonly property color _smColor:   Commons.Appearance.fxColor(_sm.color, Commons.Appearance.colors.overlay0)
    readonly property color _smBolt:    Commons.Appearance.fxColor(_sm.bolt,  Commons.Appearance.colors.accent)
    readonly property int   _smSpacing: _sm.spacing !== undefined ? _sm.spacing : 150
    readonly property var _seamMarks: {
        var out = []
        if (!_smOn) return out
        var cx0 = contentRect.x, cy0 = contentRect.y
        var cx1 = contentRect.x + contentRect.width, cy1 = contentRect.y + contentRect.height
        var sp = Math.max(60, _smSpacing)
        // horizontal seams spanning the left + right band widths
        for (var y = cy0 + sp; y < cy1 - sp * 0.4; y += sp) {
            if (cx0 > 3)         out.push({ lx: 0,   ly: y, lw: cx0,         lh: 1, bcx: cx0 / 2,             bcy: y })
            if (width - cx1 > 3) out.push({ lx: cx1, ly: y, lw: width - cx1, lh: 1, bcx: (cx1 + width) / 2,   bcy: y })
        }
        // vertical seams spanning the bottom band height
        for (var x = cx0 + sp; x < cx1 - sp * 0.4; x += sp) {
            if (height - cy1 > 3) out.push({ lx: x, ly: cy1, lw: 1, lh: height - cy1, bcx: x, bcy: (cy1 + height) / 2 })
        }
        return out
    }
    Repeater {                            // periodic rivet fittings along the strips
        model: fx._seamMarks              // (no seam grooves — barely visible on thin rails)
        delegate: Image {
            source: fx._rivetSrc; width: 8; height: 8; sourceSize: Qt.size(16, 16); smooth: true
            x: modelData.bcx - 4; y: modelData.bcy - 4
        }
    }

    // (Corner gussets removed — the chamfered corners + copper chamfer beads above
    // now form the structural corner join.)

    // ── Ornament overlay (adr_027 / item_083) ───────────────────────────────────
    // Pack-supplied SVG/PNG art (gothic filigree, sigils — non-IP / open assets)
    // placed at frame anchors. fx.ornaments = [{ source, anchor, size, opacity }].
    // anchor "corners" = all four content-hole corners, auto-rotated so art drawn
    // for the top-left hugs each corner; single-corner anchors also supported.
    // This is the engine capability WH40K needs beyond geometric primitives.
    readonly property var _orn: _fx.ornaments || []
    readonly property var _ornMarks: {
        var out = []
        if (!_hasHole || packDir === "" || _fx.ornamentsEnabled === false) return out
        var cx0 = contentRect.x, cy0 = contentRect.y
        var cx1 = contentRect.x + contentRect.width, cy1 = contentRect.y + contentRect.height
        for (var i = 0; i < _orn.length; i++) {
            var o = _orn[i]
            if (!o || !o.source) continue
            var src = "file://" + packDir + o.source
            var sz = o.size !== undefined ? o.size : 40
            var op = o.opacity !== undefined ? o.opacity : 1.0
            var a = o.anchor || "corners"
            var cells = []
            if (a === "corners")
                cells = [[cx0, cy0, 0], [cx1 - sz, cy0, 90], [cx1 - sz, cy1 - sz, 180], [cx0, cy1 - sz, 270]]
            else if (a === "top-left")     cells = [[cx0, cy0, 0]]
            else if (a === "top-right")    cells = [[cx1 - sz, cy0, 90]]
            else if (a === "bottom-right") cells = [[cx1 - sz, cy1 - sz, 180]]
            else if (a === "bottom-left")  cells = [[cx0, cy1 - sz, 270]]
            for (var j = 0; j < cells.length; j++)
                out.push({ source: src, x: cells[j][0], y: cells[j][1], size: sz, rot: cells[j][2], opacity: op })
        }
        return out
    }
    Repeater {
        model: fx._ornMarks
        delegate: Image {
            source: modelData.source
            x: modelData.x; y: modelData.y
            width: modelData.size; height: modelData.size
            sourceSize.width: modelData.size; sourceSize.height: modelData.size
            rotation: modelData.rot
            opacity: modelData.opacity
            smooth: true
            antialiasing: true
        }
    }

    // NB: HUD corner brackets moved out of FrameFx — they now draw per-WINDOW
    // (on each window's corners) in WindowBrackets.qml, driven by live client
    // geometry.
}
