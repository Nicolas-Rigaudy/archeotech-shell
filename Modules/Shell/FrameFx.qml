import QtQuick
import QtQuick.Effects
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
// Supported effects (each optional, all off by default):
//   fx.texture  { source, opacity }               — tiled texture over the frame chrome
//   fx.glow     { enabled, color, strength, size } — accent rim glow along the hole edge
//   fx.brackets { enabled, color, length, thickness, inset } — HUD corner brackets
//
// Paint order (declaration order at equal z): texture ▸ glow ▸ brackets.
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

    Item {
        visible: fx._glOn
        x: fx.contentRect.x - fx._glSize
        y: fx.contentRect.y - fx._glSize
        width:  fx.contentRect.width  + 2 * fx._glSize
        height: fx.contentRect.height + 2 * fx._glSize
        layer.enabled: fx._glOn
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: fx._glSize
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: fx._glSize        // inner rect == the content hole
            radius: fx.cornerRadius            // follow the frame's rounded corner
            color: "transparent"
            border.color: fx._glEdge
            border.width: Math.max(2, Math.round(fx._glSize / 5))
        }
    }

    // ── HUD corner brackets ──────────────────────────────────────────────────
    readonly property var   _br:      _fx.brackets || ({})
    readonly property bool  _brOn:    !!_br.enabled && _hasHole
    readonly property int   _brLen:   _br.length    !== undefined ? _br.length    : 18
    readonly property int   _brThick: _br.thickness !== undefined ? _br.thickness : 2
    readonly property int   _brInset: _br.inset     !== undefined ? _br.inset     : 6
    readonly property color _brColor: Commons.Appearance.fxColor(_br.color, Commons.Appearance.colors.accent)

    // Four corners: {left, top} flags picking which hole corner each bracket hugs.
    readonly property var _corners: [
        { left: true,  top: true  }, { left: false, top: true  },
        { left: false, top: false }, { left: true,  top: false }
    ]
    Repeater {
        model: fx._brOn ? fx._corners : []
        // Delegate carries NO custom properties (Quickshell marks delegate
        // context props FINAL); arm positions compute inline from modelData.
        // Corner anchor = the hole corner inset inward; each arm grows away from it.
        delegate: Item {
            Rectangle {   // horizontal arm
                color:  fx._brColor
                width:  fx._brLen; height: fx._brThick
                x: fx.contentRect.x + (modelData.left ? fx._brInset : fx.contentRect.width  - fx._brInset - width)
                y: fx.contentRect.y + (modelData.top  ? fx._brInset : fx.contentRect.height - fx._brInset - height)
            }
            Rectangle {   // vertical arm
                color:  fx._brColor
                width:  fx._brThick; height: fx._brLen
                x: fx.contentRect.x + (modelData.left ? fx._brInset : fx.contentRect.width  - fx._brInset - width)
                y: fx.contentRect.y + (modelData.top  ? fx._brInset : fx.contentRect.height - fx._brInset - height)
            }
        }
    }
}
