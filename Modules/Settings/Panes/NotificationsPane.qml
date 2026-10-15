import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../../../Services/Persistence" as Persistence
import "../../../Services/System" as SystemServices
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

        Divider { }   // frame separator under the pane header

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
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Commons.Appearance.spacing.s6; leftMargin: Commons.Appearance.spacing.s6; rightMargin: Commons.Appearance.spacing.s6 }
                width: root.width - 48
                spacing: Commons.Appearance.spacing.s2

                SectionLabel { text: "TOASTS" }

                SettingsCard {
                    SliderRow {
                        label: "Toast Duration"
                        configKey: "notifications.toastTimeout"
                        description: "How long notifications stay on screen"
                        from: 2000; to: 15000; stepSize: 500
                        value: Persistence.Config.get("notifications.toastTimeout")
                        format: v => (v / 1000).toFixed(1) + "s"
                        onMoved: Persistence.Config.set("notifications.toastTimeout", Math.round(value))
                    }
                    Divider { }
                    SliderRow {
                        label: "Max Visible Toasts"
                        configKey: "notifications.maxToasts"
                        description: "How many toasts can stack at once"
                        from: 1; to: 10; stepSize: 1
                        value: Persistence.Config.get("notifications.maxToasts")
                        format: v => Math.round(v) + ""
                        onMoved: Persistence.Config.set("notifications.maxToasts", Math.round(value))
                    }
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
                SectionLabel { text: "BEHAVIOUR" }

                SettingsCard {
                    ToggleRow {
                        label: "Show when fullscreen"
                        configKey: "notifications.showOnFullscreen"
                        description: "Display toasts over fullscreen applications"
                        checked: Persistence.Config.get("notifications.showOnFullscreen")
                        onToggled: value => Persistence.Config.set("notifications.showOnFullscreen", value)
                    }
                    Divider { }
                    ToggleRow {
                        label: "Persist Do Not Disturb"
                        configKey: "notifications.persistDnd"
                        description: "Remember DND state between sessions"
                        checked: Persistence.Config.get("notifications.persistDnd")
                        onToggled: value => {
                            Persistence.Config.set("notifications.persistDnd", value)
                            // Save the current state now, so turning this on while DND
                            // is already active keeps it across the next restart.
                            if (value) Persistence.Config.set("notifications.dnd", SystemServices.Notifications.dndEnabled)
                        }
                    }
                }
            }
        }
    }
}
