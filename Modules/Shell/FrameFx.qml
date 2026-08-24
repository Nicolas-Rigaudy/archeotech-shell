import QtQuick
import "../../Commons" as Commons

// Decorator/FX overlay for the shell frame (adr_027 Wave 2, Layer B).
//
// ADDITIVE, pack-gated chrome mounted once over the FrameBackground (never
// per-widget). A theme pack's `fx` block drives it; with no pack (or no fx) the
// object is empty and NOTHING draws — the base look is untouched. Anchors to the
// content-hole geometry the frame publishes, so effects sit on the exact corners
// the frame draws. Purely decorative: it never adds to the input mask, so the
// content hole stays click-through.
//
// Supported effects (each optional, all off by default):
//   fx.brackets { enabled, color, length, thickness, inset } — HUD corner brackets
//   (glow + texture: added in later Wave-2 slices)
Item {
    id: fx

    // Content-hole rect + inner corner radius (from FrameBackground).
    property rect contentRect: Qt.rect(0, 0, 0, 0)
    property int  cornerRadius: 0
    property string packDir: ""            // active pack dir (texture source base)

    readonly property var _fx: Commons.Appearance.fx

    // ── HUD corner brackets ──────────────────────────────────────────────────
    readonly property var   _br:      _fx.brackets || ({})
    readonly property bool  _brOn:    !!_br.enabled && contentRect.width > 0
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
