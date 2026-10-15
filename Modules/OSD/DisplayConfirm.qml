import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../Commons" as Commons
import "../../Commons/Primitives"
import "../../Services/Hardware" as HardwareServices

// "Keep these display settings?" (item_135): after a risky display change
// (resolution, refresh, rotation, scale or a screen turned off) this card is
// shown centred on EVERY connected screen, so it is visible on whichever one
// still works. Keep confirms; Revert, or the countdown running out, restores
// the previous layout. One instance per screen (shell.qml Variants).
PanelWindow {
    id: win

    readonly property var _d: HardwareServices.Displays
    visible: _d.pendingConfirm
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:display-confirm"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // No anchors: the layer surface is centred on its output.
    implicitWidth: Math.max(col.implicitWidth, 360) + 4 * Commons.Appearance.spacing.s5
    implicitHeight: col.implicitHeight + 4 * Commons.Appearance.spacing.s5
    color: "transparent"

    Item {
        id: card
        anchors.fill: parent
        anchors.margins: Commons.Appearance.spacing.s5
        focus: true
        Keys.onReturnPressed: win._d.keep()
        Keys.onEscapePressed: win._d.revert()

        RectangularShadow {
            anchors.fill: bg
            radius: bg.radius
            blur:   Commons.Appearance.elevation.e4.blur
            offset: Qt.vector2d(0, Commons.Appearance.elevation.e4.y)
            spread: Commons.Appearance.elevation.e4.spread
            color:  Commons.Appearance.outerShadowColor(Commons.Appearance.elevation.e4)
        }
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Commons.Appearance.radius.lg
            color: Commons.Appearance.colors.glassBg
            border.width: 1
            border.color: Commons.Appearance.colors.accentBorder
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Commons.Appearance.spacing.s5
            spacing: Commons.Appearance.spacing.s2

            Text {
                text: "Keep these display settings?"
                color: Commons.Appearance.colors.textPrimary
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.weight: Commons.Appearance.font.weightMedium
            }
            Text {
                Layout.fillWidth: true
                text: "Reverting to the previous layout in " + win._d.confirmLeft + " s"
                color: Commons.Appearance.colors.textSecondary
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
            }
            // Countdown bar.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Commons.Appearance.spacing.s1
                radius: height / 2
                color: Commons.Appearance.colors.recessedTrack
                Rectangle {
                    width: parent.width * win._d.confirmLeft / win._d.confirmSeconds
                    height: parent.height
                    radius: height / 2
                    color: Commons.Appearance.colors.accent
                    // One tick of the countdown timer per step, linear.
                    Behavior on width { NumberAnimation { duration: win._d._countdown.interval } }
                }
            }
            Item { Layout.preferredHeight: Commons.Appearance.spacing.s2 }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Commons.Appearance.spacing.s2
                GlassButton { text: "Revert"; onClicked: win._d.revert() }
                GlassButton { text: "Keep"; active: true; onClicked: win._d.keep() }
            }
        }
    }
}
