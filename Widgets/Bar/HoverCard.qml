import QtQuick
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
    height: _popupCol.implicitHeight + (Commons.Appearance.spacing.md * 2 + Commons.Appearance.popupSurface.padTop)

    transformOrigin: Item.Top
    scale:   (holderRoot && holderRoot._popupVisible) ? 1.0 : 0.85
    opacity: (holderRoot && holderRoot._popupVisible) ? 1.0 : 0.0
    visible: holderRoot && holderRoot.side === "top" && opacity > 0.01

    Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { enabled: Commons.Appearance.glassFades; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    PopupSurface {
        r: card._r; rb: card._rb; bw: card._bw
        winY: card._winY; winH: card._winH
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
        x: card._r + 14; y: Commons.Appearance.spacing.md + Commons.Appearance.popupSurface.padTop
        spacing: 3

        Text {
            visible: !!(card.holderRoot && card.holderRoot._popupLabel.length > 0)
            text: card.holderRoot ? card.holderRoot._popupLabel : ""
            color: Commons.Appearance.colors.accent
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.display
            font.letterSpacing: Commons.Appearance.font.trackingWide
            font.weight: Commons.Appearance.font.weightSemibold
        }
        Text {
            text: card.holderRoot ? card.holderRoot._popupPrimary : ""
            color: Commons.Appearance.colors.textPrimary
            font.pixelSize: Commons.Appearance.font.sizeLg
            font.family: Commons.Appearance.font.family
            font.weight: Commons.Appearance.font.weightMedium
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
            font.pixelSize: Commons.Appearance.font.size2xs
            font.family: Commons.Appearance.font.family
        }
    }
}
