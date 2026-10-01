import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Commons" as Commons
import "../../../Commons/Primitives" as Prim

// Shared settings group card — same elevated language as the dashboard DashCard:
// translucent surfaceCard + soft drop shadow. Rows (ToggleRow/SliderRow/…) and
// their dividers go in as direct children; they land in the padded `inner`.
Item {
    id: card
    default property alias _content: inner.data

    Layout.fillWidth: true
    implicitHeight: bg.implicitHeight

    RectangularShadow {
        anchors.fill: bg
        radius: bg.radius
        blur:   Commons.Appearance.elevation.e3.blur
        offset: Qt.vector2d(0, Commons.Appearance.elevation.e3.y)
        spread: Commons.Appearance.elevation.e3.spread
        color:  Commons.Appearance.elevation.e3.color
    }

    Prim.MetalSurface {
        id: bg
        anchors.fill: parent
        radius: Commons.Appearance.radius.md
        color:  Commons.Appearance.colors.surfaceCard
        implicitHeight: inner.implicitHeight + 12

        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Commons.Appearance.spacing.s4; rightMargin: Commons.Appearance.spacing.s4; topMargin: Commons.Appearance.spacing.s2 }
            spacing: 0
        }
    }
}
