import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Persistence" as Persistence
import "../Widgets"

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰂚"
            title: "Notifications"
            description: "Configure toast appearance, timing, and do-not-disturb behaviour"
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: col.implicitHeight + 32
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: col
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 24; leftMargin: 24; rightMargin: 24 }
                width: root.width - 48
                spacing: 6

                SectionLabel { text: "TOASTS" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: toastCol.implicitHeight

                    ColumnLayout {
                        id: toastCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0

                        Item { implicitHeight: 4; Layout.fillWidth: true }
                        SliderRow {
                            label: "Toast Duration"
                            description: "How long notifications stay on screen"
                            from: 2000; to: 15000; stepSize: 500
                            value: Persistence.Config.get("notifications.toastTimeout", 5000)
                            valueDisplay: (value / 1000).toFixed(1) + "s"
                            onMoved: Persistence.Config.set("notifications.toastTimeout", Math.round(value))
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.base }
                        SliderRow {
                            label: "Max Visible Toasts"
                            description: "How many toasts can stack at once"
                            from: 1; to: 10; stepSize: 1
                            value: Persistence.Config.get("notifications.maxToasts", 5)
                            valueDisplay: Math.round(value) + ""
                            onMoved: Persistence.Config.set("notifications.maxToasts", Math.round(value))
                        }
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "BEHAVIOUR" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: behavCol.implicitHeight

                    ColumnLayout {
                        id: behavCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0

                        Item { implicitHeight: 4; Layout.fillWidth: true }
                        ToggleRow {
                            label: "Show when fullscreen"
                            description: "Display toasts over fullscreen applications"
                            checked: Persistence.Config.get("notifications.showOnFullscreen", false)
                            onToggled: value => Persistence.Config.set("notifications.showOnFullscreen", value)
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.base }
                        ToggleRow {
                            label: "Persist Do Not Disturb"
                            description: "Remember DND state between sessions"
                            checked: Persistence.Config.get("notifications.persistDnd", false)
                            onToggled: value => Persistence.Config.set("notifications.persistDnd", value)
                        }
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        color: Commons.Appearance.colors.overlay0
        font.pixelSize: 10
        font.family: Commons.Appearance.font.family
        font.weight: Font.Medium
        font.letterSpacing: 1.5
    }
}
