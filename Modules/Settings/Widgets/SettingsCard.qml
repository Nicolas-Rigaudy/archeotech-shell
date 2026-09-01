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
        blur:   16
        offset: Qt.vector2d(0, 4)
        spread: 0
        color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
    }

    Prim.MetalSurface {
        id: bg
        anchors.fill: parent
        radius: Commons.Appearance.radius.md
        color:  Commons.Appearance.colors.surfaceCard
        implicitHeight: inner.implicitHeight + 12

        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16; topMargin: 6 }
            spacing: 0
        }
    }
}
