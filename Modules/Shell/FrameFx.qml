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

    // NB: HUD corner brackets moved out of FrameFx — they now draw per-WINDOW
    // (on each window's corners) in WindowBrackets.qml, driven by live client
    // geometry. FrameFx keeps only the frame-scoped effects (texture, glow).
}
