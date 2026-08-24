import QtQuick
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

    // ── Bevel (adr_027 / item_083: depth) ───────────────────────────────────────
    // A thin machined "lip" tracing the content-hole edge — reads as the metal
    // bezel of a recessed screen, restoring dimension a flat matte fill loses.
    // fx.bevel = { enabled, color, width }.
    readonly property var   _bev:      _fx.bevel || ({})
    readonly property bool  _bevOn:    !!_bev.enabled && _hasHole
    readonly property color _bevColor: Commons.Appearance.fxColor(_bev.color, Commons.Appearance.colors.overlay1)
    readonly property int   _bevW:     _bev.width !== undefined ? _bev.width : 2
    Rectangle {
        visible: fx._bevOn
        x: fx.contentRect.x; y: fx.contentRect.y
        width: fx.contentRect.width; height: fx.contentRect.height
        radius: fx.cornerRadius
        color: "transparent"
        antialiasing: true
        border.width: fx._bevW
        border.color: fx._bevColor
    }
    // Soft inner shadow just inside the lip → the screen reads as recessed.
    Rectangle {
        visible: fx._bevOn
        x: fx.contentRect.x + fx._bevW; y: fx.contentRect.y + fx._bevW
        width:  fx.contentRect.width  - 2 * fx._bevW
        height: fx.contentRect.height - 2 * fx._bevW
        radius: Math.max(0, fx.cornerRadius - fx._bevW)
        color: "transparent"
        antialiasing: true
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.5)
    }

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
        delegate: Rectangle {
            width: fx._rvSize; height: fx._rvSize; radius: fx._rvSize / 2
            x: modelData.cx - fx._rvSize / 2
            y: modelData.cy - fx._rvSize / 2
            color: fx._rvColor
            antialiasing: true
            border.width: 1
            border.color: Qt.darker(fx._rvColor, 1.6)   // bolt-head ring
        }
    }

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
