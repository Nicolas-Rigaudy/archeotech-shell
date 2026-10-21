import QtQuick
import ".." as Commons

// Busy indicator: the rotating-arrows glyph, spinning while `running` and hidden
// otherwise. One copy for every "working..." affordance (Wi-Fi/Bluetooth scan,
// pair, remove). Unscaled by the animation settings (see Commons.Spin).
//
//   Spinner { running: busy; anchors.centerIn: parent; size: Commons.Appearance.font.sizeLg }
Text {
    id: spin
    property bool running: true
    property color tint: Commons.Appearance.colors.accent
    property int size: Commons.Appearance.font.sizeBase

    visible: running
    text: "󰑙"
    color: tint
    font.pixelSize: size
    font.family: Commons.Appearance.font.family

    Commons.Spin { target: spin; running: spin.running }
}
