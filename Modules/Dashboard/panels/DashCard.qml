import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Commons" as Commons

// Shared dashboard card shell (2026-07-20 rework). Elevated `surfaceCard` with a
// soft drop shadow (like the launcher tiles), an optional section title +
// divider, and a content slot. Cards declare their properties/Process/Timers as
// usual and put their visual rows as direct children — those land in `inner`.
//
// Non-visual children (Process/Timer/Connections) also route into `inner` via
// the default alias; a ColumnLayout ignores them for layout, so that's harmless.
Item {
    id: card
    default property alias _content: inner.data
    property string title: ""

    implicitHeight: bg.implicitHeight

    RectangularShadow {
        anchors.fill: bg
        radius: bg.radius
        blur:   16
        offset: Qt.vector2d(0, 4)
        spread: 0
        color:  Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Commons.Appearance.radius.md
        color:  Commons.Appearance.colors.surfaceCard
        implicitHeight: outer.implicitHeight + 24

        ColumnLayout {
            id: outer
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            Text {
                visible: card.title.length > 0
                text: card.title
                color: Commons.Appearance.colors.accent
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.letterSpacing: 1.5
                opacity: 0.85
            }
            Rectangle {
                visible: card.title.length > 0
                Layout.fillWidth: true
                height: 1
                color: Commons.Appearance.colors.surface0
            }

            ColumnLayout {
                id: inner
                Layout.fillWidth: true
                spacing: 8
            }
        }
    }
}
