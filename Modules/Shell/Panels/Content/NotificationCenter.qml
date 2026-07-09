import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
                    Text {
                        text: "󰂚  Notifications"
                        color: Commons.Appearance.colors.text
                        font.pixelSize: Commons.Appearance.font.sizeLg
                        font.family: Commons.Appearance.font.family
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    // Clear all (text pill) — only when there are notifications.
                    Rectangle {
                        visible: SystemServices.Notifications.count > 0
                        Layout.preferredWidth:  _clearLabel.implicitWidth + 16
                        Layout.preferredHeight: 28
                        radius: Commons.Appearance.radius.base
                        color:  _clearArea.containsMouse ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.base
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        Text {
                            id: _clearLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: Commons.Appearance.colors.subtext0
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                        }
                        MouseArea {
                            id: _clearArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: SystemServices.Notifications.clearAll()
                        }
                    }
                    // Do Not Disturb — compact icon toggle (moved here from the old CC).
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Commons.Appearance.radius.base
                        color: SystemServices.Notifications.dndEnabled
                            ? Commons.Appearance.colors.accentAlpha
                            : (_dndArea.containsMouse ? Commons.Appearance.colors.surface0 : "transparent")
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        Text {
                            anchors.centerIn: parent
                            text: SystemServices.Notifications.dndEnabled ? "󰂛" : "󰂚"
                            color: SystemServices.Notifications.dndEnabled
                                ? Commons.Appearance.colors.accent
                                : (_dndArea.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0)
                            font.pixelSize: 15; font.family: Commons.Appearance.font.family
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        }
                        MouseArea {
                            id: _dndArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SystemServices.Notifications.dndEnabled = !SystemServices.Notifications.dndEnabled
                        }

                        ToolTip {
                            visible: _dndArea.containsMouse
                            delay: 400
                            text: SystemServices.Notifications.dndEnabled
                                ? "Do Not Disturb: on" : "Do Not Disturb: off"
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Commons.Appearance.radius.base
                        color: _closeArea.containsMouse ? Commons.Appearance.colors.surface0 : "transparent"
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: _closeArea.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        }
                        MouseArea {
                            id: _closeArea; anchors.fill: parent; hoverEnabled: true
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
                }

                // ── Notification list ─────────────────────────────────────────
                Column {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: SystemServices.Notifications.count > 0

                    Repeater {
                        model: SystemServices.Notifications.history
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: _itemContent.implicitHeight + 20
                            radius: Commons.Appearance.radius.md
                            color: Commons.Appearance.colors.base
                            border.color: modelData.urgency === 2
                                ? Commons.Appearance.colors.red
                                : Commons.Appearance.colors.surface0
                            border.width: 1

                            ColumnLayout {
                                id: _itemContent
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    // App icon
                                    Item {
                                        width: 14; height: 14
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
                                            font.pixelSize: 11
                                            font.family: Commons.Appearance.font.family
                                        }
                                    }

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
                                    Text {
                                        text: "󰅖"
                                        color: _dismissArea.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                                        font.pixelSize: 13; font.family: Commons.Appearance.font.family
                                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        MouseArea {
                                            id: _dismissArea
                                            anchors.fill: parent; anchors.margins: -4
                                            hoverEnabled: true
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

                Item { height: 2 }
            }
        }
    }
}
