import QtQuick
import ".." as Commons

// Keyboard focus ring (item_113): an accent outline hugging the host, with a gap so
// it reads on glass, flat and light surfaces alike. Drop it in as the last child of
// an interactive primitive and bind `shown` to the host's activeFocus. Mouse clicks
// never focus these controls, so the ring only appears for keyboard (Tab) focus.
// Width, gap and colour are Appearance.focusRing tokens (pack-overridable).
//
//   FocusRing { shown: root.activeFocus; cornerRadius: Commons.Appearance.radius.base }
Rectangle {
    property bool shown: false
    property real cornerRadius: 0

    readonly property real _out: Commons.Appearance.focusRing.gap + Commons.Appearance.focusRing.width

    visible: shown
    z: 10
    anchors.fill: parent
    anchors.margins: -_out
    radius: cornerRadius + _out
    color: "transparent"
    border.width: Commons.Appearance.focusRing.width
    border.color: Commons.Appearance.focusRing.color
    antialiasing: true
}
