import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../../../Commons" as Commons
import "../../../../Commons/Primitives"
import "../../../../Services/System" as SystemServices

// NotificationCenter UI. Panel.qml provides chrome + slide-from-edge anim +
// focus/Esc/click-outside; this file is the inner content only. `panelRoot`
// is injected by Panel.qml's Loader.onLoaded — call `panelRoot.close()` to
// dismiss.
//
// Sprint 20: exposes `implicitAxis` (used by Strip when axisSize == "auto")
// so the panel sizes to actual content height + chrome instead of growing
// to the full screen.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    // Strip.qml reads this to drive axisSize:"auto". Floor keeps the empty
    // state visible without collapsing to header-only; cap is enforced by
    // Strip against the screen axis.
    readonly property real implicitAxis:
        Math.max(220, contentColumn.implicitHeight + Commons.Appearance.spacing.xl * 2)

    Item {
        id: panel
        anchors.fill: parent
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 24
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: contentColumn
                anchors {
                    top: parent.top; left: parent.left; right: parent.right
                    margins: Commons.Appearance.spacing.xl
                    topMargin: 14
                }
                width: flick.width - Commons.Appearance.spacing.xl * 2
                spacing: Commons.Appearance.spacing.lg

                // ── Header ────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {                          // icon on the icon font
                        text: "󰂚"
                        color: Commons.Appearance.colors.text
                        font.pixelSize: Commons.Appearance.font.sizeLg
                        font.family: Commons.Appearance.font.family
                    }
                    Text {                          // label = display face (Cinzel under the pack)
                        text: "Notifications"
                        color: Commons.Appearance.colors.text
                        font.pixelSize: Commons.Appearance.font.sizeLg
                        font.family: Commons.Appearance.font.display
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    // Clear all — compact trash-can icon, only when there are notifications.
                    Rectangle {
                        id: _clearBtn
                        visible: SystemServices.Notifications.count > 0
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Commons.Appearance.radius.base
                        color: "transparent"
                        Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰩺"
                            color: _clearLayer.hovered ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                            font.pixelSize: 15; font.family: Commons.Appearance.font.family
                            Behavior on color { Commons.ColorAnim {} }
                        }
                        StateLayer {
                            id: _clearLayer
                            anchors.fill: parent
                            onClicked: SystemServices.Notifications.clearAll()
                        }
                    }
                    // Do Not Disturb — compact icon toggle (moved here from the old CC).
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Commons.Appearance.radius.base
                        color: SystemServices.Notifications.dndEnabled
                            ? Commons.Appearance.colors.accentAlpha : "transparent"
                        Behavior on color { Commons.ColorAnim {} }
                        Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                        Text {
                            anchors.centerIn: parent
                            text: SystemServices.Notifications.dndEnabled ? "󰂛" : "󰂚"
                            color: SystemServices.Notifications.dndEnabled
                                ? Commons.Appearance.colors.accent
                                : (_dndLayer.hovered ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0)
                            font.pixelSize: 15; font.family: Commons.Appearance.font.family
                            Behavior on color { Commons.ColorAnim {} }
                        }
                        StateLayer {
                            id: _dndLayer
                            anchors.fill: parent
                            onClicked: SystemServices.Notifications.dndEnabled = !SystemServices.Notifications.dndEnabled
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Commons.Appearance.radius.base
                        color: "transparent"
                        Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: _closeLayer.hovered ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                            Behavior on color { Commons.ColorAnim {} }
                        }
                        StateLayer {
                            id: _closeLayer
                            anchors.fill: parent
                            onClicked: if (root.panelRoot) root.panelRoot.close()
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

                // ── Empty state ───────────────────────────────────────────────
                EmptyState {
                    Layout.fillWidth: true
                    visible: SystemServices.Notifications.count === 0
                    icon:  "󰂚"
                    title: "No notifications"
                    hint:  "You're all caught up"
                }

                // ── Notification list ─────────────────────────────────────────
                Column {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: SystemServices.Notifications.count > 0

                    Repeater {
                        model: SystemServices.Notifications.history
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: _itemBg.height

                            // Same elevated card shell as the dashboard cards:
                            // translucent surfaceCard + soft drop shadow.
                            RectangularShadow {
                                anchors.fill: _itemBg
                                radius: _itemBg.radius
                                blur:   16
                                offset: Qt.vector2d(0, 4)
                                spread: 0
                                color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
                            }

                            Rectangle {
                                id: _itemBg
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                height: _itemContent.implicitHeight + 24
                                radius: Commons.Appearance.radius.md
                                color: Commons.Appearance.colors.surfaceCard
                                border.color: modelData.urgency === 2
                                    ? Commons.Appearance.colors.red
                                    : "transparent"
                                border.width: 1

                            RowLayout {
                                id: _itemContent
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 10

                                // App icon — top-aligned so it spans the two text lines.
                                Item {
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                    Layout.alignment: Qt.AlignTop
                                    Image {
                                        id: _ncIcon
                                        anchors.fill: parent
                                        source: modelData.appIcon
                                            ? (modelData.appIcon.startsWith("/")
                                                ? modelData.appIcon
                                                : "image://icon/" + modelData.appIcon)
                                            : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        visible: source !== "" && status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !_ncIcon.visible
                                        text: "󰂚"
                                        color: Commons.Appearance.colors.overlay1
                                        font.pixelSize: 16
                                        font.family: Commons.Appearance.font.family
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: modelData.appName || "Notification"
                                            color: Commons.Appearance.colors.overlay1
                                            font.pixelSize: Commons.Appearance.font.sizeSm
                                            font.family: Commons.Appearance.font.family
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.timestamp || ""
                                            color: Commons.Appearance.colors.overlay0
                                            font.pixelSize: Commons.Appearance.font.sizeSm - 1
                                            font.family: Commons.Appearance.font.family
                                        }
                                        // Dismiss — StateLayer hit target.
                                        Rectangle {
                                            Layout.preferredWidth: 22; Layout.preferredHeight: 22
                                            radius: Commons.Appearance.radius.sm
                                            color: "transparent"
                                            Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅖"
                                                color: _dismissLayer.hovered ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                                                font.pixelSize: 13; font.family: Commons.Appearance.font.family
                                                Behavior on color { Commons.ColorAnim {} }
                                            }
                                            StateLayer {
                                                id: _dismissLayer
                                                anchors.fill: parent
                                                onClicked: SystemServices.Notifications.dismiss(index)
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.summary || ""
                                        visible: text.length > 0
                                        color: Commons.Appearance.colors.text
                                        font.pixelSize: Commons.Appearance.font.sizeMd
                                        font.family: Commons.Appearance.font.family
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        text: modelData.body || ""
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
                    }
                }

                Item { height: 2 }
            }
        }
    }
}
