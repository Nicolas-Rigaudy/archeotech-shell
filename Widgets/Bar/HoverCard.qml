import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Commons/Primitives"

// Hover info popup. Top edge wider than body; CCW arcs curve inward to body
// width; rounded bottom corners. Position + content driven by holderRoot state
// (set by widgets via holderRoot.showPopup).
Item {
    id: card
    required property var holderRoot

    property real _r:  Commons.Appearance.radius.xl
    property real _rb: Commons.Appearance.radius.md
    property real _bw: _popupCol.implicitWidth + 28

    // Screen-space sheen (matches the frame/strips) — a slice of the one global
    // top-lit gradient, not a harsh ramp restarting inside this little card.
    readonly property real _winY: { var _t = card.y + card.height; return card.mapToItem(null, 0, 0).y }
    readonly property real _winH: (holderRoot && holderRoot.screen) ? holderRoot.screen.height : 1080

    x: Math.min(
           Math.max((holderRoot ? holderRoot._popupAnchorX : 0) - width / 2,
                    Commons.Appearance.bar.marginSide + 4),
           (holderRoot ? holderRoot.width : 0) - width - Commons.Appearance.bar.marginSide - 4
       )
    y: Commons.Appearance.bar.marginTop + Commons.Appearance.bar.height
    width:  _bw + _r * 2
    height: _popupCol.implicitHeight + (Commons.Appearance.frameChamfer ? Commons.Appearance.spacing.md * 2 + 10 : Commons.Appearance.spacing.md * 2)

    transformOrigin: Item.Top
    scale:   (holderRoot && holderRoot._popupVisible) ? 1.0 : 0.85
    opacity: (holderRoot && holderRoot._popupVisible) ? 1.0 : 0.0
    visible: holderRoot && holderRoot.side === "top" && opacity > 0.01

    Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Soft downward lift — shared neck-panel shadow (top-attached).
    PanelShadow { side: "top"; perpInset: card._r; cornerRadius: card._rb }

    Shape {
        id: cardShape
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 8

        ShapePath {
            fillGradient: LinearGradient {
                x1: 0; y1: Commons.Appearance.frameChamfer ? 0 : -card._winY
                x2: 0; y2: Commons.Appearance.frameChamfer ? card.height : (card._winH - card._winY)
                GradientStop { position: 0.0; color: Commons.Appearance.frameChamfer ? Commons.Appearance.steel.hi : Commons.Appearance.colors.glassSheenTop }
                GradientStop { position: Commons.Appearance.frameChamfer ? 0.30 : 1.0; color: Commons.Appearance.frameChamfer ? Commons.Appearance.steel.md : Commons.Appearance.colors.glassSheenBot }
                GradientStop { position: 1.0; color: Commons.Appearance.frameChamfer ? Commons.Appearance.steel.lo : Commons.Appearance.colors.glassSheenBot }
            }
            strokeWidth: Commons.Appearance.frameChamfer ? 1.4 : 0
            strokeColor: Commons.Appearance.frameChamfer ? Commons.Appearance.colors.copperLit : "transparent"

            startX: 0; startY: 0
            PathLine { x: card._bw + card._r * 2; y: 0 }
            PathArc  { x: card._bw + card._r; y: card._r
                       radiusX: card._r; radiusY: card._r
                       direction: PathArc.Counterclockwise }
            PathLine { x: card._bw + card._r; y: card.height - card._rb }
            PathArc  { x: card._bw + card._r - card._rb; y: card.height
                       radiusX: card._rb; radiusY: card._rb
                       direction: PathArc.Clockwise }
            PathLine { x: card._r + card._rb; y: card.height }
            PathArc  { x: card._r; y: card.height - card._rb
                       radiusX: card._rb; radiusY: card._rb
                       direction: PathArc.Clockwise }
            PathLine { x: card._r; y: card._r }
            PathArc  { x: 0; y: 0
                       radiusX: card._r; radiusY: card._r
                       direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: 0 }
        }
    }

    ConsoleChrome {                              // bolted-collar connection to the bar (steel pack)
        anchors.fill: parent
        visible: Commons.Appearance.frameChamfer
        attachSide: "top"; showTrim: false; showGussets: false
        radius: card._rb
    }

    // Keep popup alive when cursor drifts onto it.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (card.holderRoot) card.holderRoot.keepPopupsAlive()
        onExited: if (card.holderRoot && Date.now() - card.holderRoot._lastShowTime > 200)
            card.holderRoot.hidePopup()
    }

    Column {
        id: _popupCol
        x: card._r + 14; y: Commons.Appearance.frameChamfer ? Commons.Appearance.spacing.md + 10 : Commons.Appearance.spacing.md
        spacing: 3

        Text {
            visible: !!(card.holderRoot && card.holderRoot._popupLabel.length > 0)
            text: card.holderRoot ? card.holderRoot._popupLabel : ""
            color: Commons.Appearance.colors.accent
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.display
            font.letterSpacing: 1.2
            font.weight: Font.DemiBold
        }
        Text {
            text: card.holderRoot ? card.holderRoot._popupPrimary : ""
            color: Commons.Appearance.colors.textPrimary
            font.pixelSize: Commons.Appearance.font.sizeLg
            font.family: Commons.Appearance.font.family
            font.weight: Font.Medium
        }
        Text {
            visible: !!(card.holderRoot && card.holderRoot._popupSecondary.length > 0)
            text: card.holderRoot ? card.holderRoot._popupSecondary : ""
            color: Commons.Appearance.colors.textSecondary
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
        }
        Text {
            visible: !!(card.holderRoot && card.holderRoot._popupHint.length > 0)
            text: card.holderRoot ? card.holderRoot._popupHint : ""
            color: Commons.Appearance.colors.textMuted
            font.pixelSize: Commons.Appearance.font.sizeSm - 1
            font.family: Commons.Appearance.font.family
        }
    }
}
