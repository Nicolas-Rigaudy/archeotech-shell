import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../Commons" as Commons
import "../../Services/Media" as MediaServices
import "../../Services/Hardware" as HardwareServices
import "../../Services/Compositor" as CompositorServices

PanelWindow {
    id: osdWindow

    visible: shown && (CompositorServices.MangoWC.focusedOutput === "" || screen.name === CompositorServices.MangoWC.focusedOutput)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { bottom: true; left: true; right: true }
    implicitHeight: 80
    color: "transparent"

    // ── Public API ─────────────────────────────────────────────────────────────
    property bool   shown:   false
    property string osdType: "volume"

    function show(type) {
        osdType = type
        shown   = true
        hideTimer.restart()
    }

    // ── Derived values ─────────────────────────────────────────────────────────
    property int  osdValue: osdType === "brightness" ? HardwareServices.Brightness.percent : MediaServices.Audio.volume
    property bool osdMuted: osdType === "volume" && MediaServices.Audio.muted

    property string osdIcon: {
        if (osdType === "brightness")
            return osdValue >= 75 ? "󰃠" : osdValue >= 40 ? "󰃟" : "󰃞"
        if (osdMuted)      return "󰖁"
        if (osdValue > 66) return "󰕾"
        if (osdValue > 33) return "󰖀"
        return "󰕿"
    }

    property color osdColor: osdType === "brightness"
        ? Commons.Appearance.colors.yellow
        : (osdMuted ? Commons.Appearance.colors.overlay0 : Commons.Appearance.colors.accent)

    // ── Auto-hide ──────────────────────────────────────────────────────────────
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osdWindow.shown = false
    }

    // ── Pill (opacity-animated, window itself stays mapped) ────────────────────
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: 220
        height: 46

        Rectangle {
            id: pill
            anchors.fill: parent
            radius: Commons.Appearance.radius.xl
            antialiasing: true
            color: Commons.Appearance.colors.glassBg
            opacity: osdWindow.shown ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: osdWindow.osdIcon
                    color: osdWindow.osdColor
                    font.pixelSize: 20
                    font.family: Commons.Appearance.font.family
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 4; radius: 2
                    color: Commons.Appearance.colors.surface0
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: parent.width * (osdWindow.osdMuted ? 0 : Math.min(osdWindow.osdValue / 100, 1))
                        height: parent.height; radius: 2
                        color: osdWindow.osdColor
                        Behavior on width { NumberAnimation { duration: Commons.Appearance.anim.fast; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                }

                Text {
                    text: osdWindow.osdMuted ? "Muted" : osdWindow.osdValue + "%"
                    color: Commons.Appearance.colors.subtext0
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: 38
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
