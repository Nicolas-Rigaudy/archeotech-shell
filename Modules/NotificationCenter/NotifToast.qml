import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Commons/Primitives"
import "../../Services/System" as SystemServices

Item {
    id: root

    property var notification

    signal dismissClicked()
    signal timedOut()

    width: 316
    height: card.height

    // Enter/exit: fade + shift, decel in (~400) / accel out (~200). The host
    // (shell.qml) removes us from its array on dismiss/timeout, which would
    // destroy the delegate instantly — so we animate _progress → 0 first and
    // only emit the removal signal once it lands (see _close / on_ProgressChanged).
    property real _progress: 0
    property bool _closing: false
    property bool _timedOut: false
    opacity: _progress
    transform: Translate { y: (1 - root._progress) * 10 }

    Behavior on _progress { Commons.Anim { exit: root._closing } }
    Component.onCompleted: _progress = 1

    function _close(viaTimeout) {
        if (root._closing) return
        root._timedOut = viaTimeout
        root._closing = true
        root._progress = 0
    }
    on_ProgressChanged: if (root._closing && root._progress <= 0.01) {
        if (root._timedOut) root.timedOut(); else root.dismissClicked()
    }

    // Screen-space sheen: like the strip cards, sample the ONE top-lit screen
    // gradient at this toast's on-screen Y instead of restarting a dark-bottomed
    // gradient inside the card — so a toast near the top reads light, matching
    // the bar/frame next to it. `_d` refs animating geometry to force re-eval.
    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }
    readonly property real _winH: Screen.height > 0 ? Screen.height : 1080
    readonly property real _winY: { var _d = root.y + root._progress; return root.mapToItem(null, 0, 0).y }
    readonly property real _fTop: Math.max(0, Math.min(1, _winY / _winH))
    readonly property real _fBot: Math.max(0, Math.min(1, (_winY + card.height) / _winH))

    Timer {
        property int ms: {
            if (!root.notification) return 0
            if (root.notification.urgency === 2) return 0  // critical: never auto-dismiss
            var t = root.notification.expireTimeout
            return (t > 0) ? Math.max(t, 3000) : 5000
        }
        interval: ms
        running: ms > 0
        onTriggered: root._close(true)
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        blur:   16
        offset: Qt.vector2d(0, 4)
        spread: 0
        color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
    }

    Rectangle {
        id: card
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: cardContent.implicitHeight + 20
        radius: Commons.Appearance.radius.md
        antialiasing: true
        // Liquid-glass sheen — top-lit gradient (same tokens as the chrome),
        // sampled at this toast's screen position (see root._fTop/_fBot).
        gradient: Gradient {
            GradientStop { position: 0.0; color: root._mix(Commons.Appearance.colors.glassSheenTop, Commons.Appearance.colors.glassSheenBot, root._fTop) }
            GradientStop { position: 1.0; color: root._mix(Commons.Appearance.colors.glassSheenTop, Commons.Appearance.colors.glassSheenBot, root._fBot) }
        }
        border.color: (root.notification && root.notification.urgency === 2)
            ? Commons.Appearance.colors.red
            : Commons.Appearance.colors.glassBorder
        border.width: 1

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root._close(false)
        }

        RowLayout {
            id: cardContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            // App icon — top-aligned so it spans the two text lines (matches the
            // notification-center history rows).
            Item {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignTop
                Image {
                    id: _toastIcon
                    anchors.fill: parent
                    source: (root.notification && root.notification.appIcon)
                        ? (root.notification.appIcon.startsWith("/")
                            ? root.notification.appIcon
                            : "image://icon/" + root.notification.appIcon)
                        : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source !== "" && status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !_toastIcon.visible
                    text: "󰂚"
                    color: Commons.Appearance.colors.overlay1
                    font.pixelSize: 16
                    font.family: Commons.Appearance.font.family
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: (root.notification && root.notification.appName) ? root.notification.appName : "Notification"
                        color: Commons.Appearance.colors.overlay1
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    // Close — StateLayer hit target.
                    Rectangle {
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                        radius: Commons.Appearance.radius.sm
                        color: "transparent"
                        Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: _xLayer.hovered ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                            font.pixelSize: 13; font.family: Commons.Appearance.font.family
                            Behavior on color { Commons.ColorAnim {} }
                        }
                        StateLayer {
                            id: _xLayer
                            anchors.fill: parent
                            onClicked: root._close(false)
                        }
                    }
                }

                Text {
                    text: (root.notification && root.notification.summary) ? root.notification.summary : ""
                    visible: text.length > 0
                    color: Commons.Appearance.colors.text
                    font.pixelSize: Commons.Appearance.font.sizeMd
                    font.family: Commons.Appearance.font.family
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: (root.notification && root.notification.body) ? root.notification.body : ""
                    visible: text.length > 0
                    color: Commons.Appearance.colors.subtext1
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
        }
    }
}
