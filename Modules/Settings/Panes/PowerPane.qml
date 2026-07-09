import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../Widgets"

Item {
    id: root

    // ── State ──────────────────────────────────────────────────────────────────
    property string powerProfile: "balanced"

    property bool dimEnabled:   true
    property int  dimTimeout:   600
    property bool lockEnabled:  true
    property int  lockTimeout:  1200
    property bool sleepEnabled: true
    property int  sleepTimeout: 1800

    Component.onCompleted: {
        profileReader.running    = true
        idleConfigReader.running = true
    }

    // ── Process helpers ────────────────────────────────────────────────────────
    Process {
        id: cmdRunner
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
    }
    function run(cmd) { cmdRunner.cmd = cmd; cmdRunner.running = true }

    Process {
        id: profileReader
        command: ["bash", "-c", "powerprofilesctl get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim()
                if (p === "performance" || p === "balanced" || p === "power-saver")
                    root.powerProfile = p
            }
        }
    }

    Process {
        id: idleConfigReader
        command: ["bash", "-c",
            "f=$HOME/.cache/swayidle.conf; " +
            "[ -f \"$f\" ] && cat \"$f\" || " +
            "echo 'DIM_ENABLED=true\nDIM_TIMEOUT=600\nLOCK_ENABLED=true\nLOCK_TIMEOUT=1200\nSLEEP_ENABLED=true\nSLEEP_TIMEOUT=1800'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var m
                if ((m = data.match(/^DIM_ENABLED=(true|false)/)))   root.dimEnabled   = m[1] === "true"
                if ((m = data.match(/^DIM_TIMEOUT=(\d+)/)))           root.dimTimeout   = parseInt(m[1])
                if ((m = data.match(/^LOCK_ENABLED=(true|false)/)))  root.lockEnabled  = m[1] === "true"
                if ((m = data.match(/^LOCK_TIMEOUT=(\d+)/)))          root.lockTimeout  = parseInt(m[1])
                if ((m = data.match(/^SLEEP_ENABLED=(true|false)/))) root.sleepEnabled = m[1] === "true"
                if ((m = data.match(/^SLEEP_TIMEOUT=(\d+)/)))         root.sleepTimeout = parseInt(m[1])
            }
        }
    }

    function applyIdleConfig() {
        var lines = [
            "DIM_ENABLED="   + root.dimEnabled,
            "DIM_TIMEOUT="   + root.dimTimeout,
            "LOCK_ENABLED="  + root.lockEnabled,
            "LOCK_TIMEOUT="  + root.lockTimeout,
            "SLEEP_ENABLED=" + root.sleepEnabled,
            "SLEEP_TIMEOUT=" + root.sleepTimeout,
        ]
        run("printf '%s\\n' " + lines.map(l => "'" + l + "'").join(" ") +
            " > $HOME/.cache/swayidle.conf && ~/.config/swayidle/config.sh &")
    }

    function _applyProfile(p) {
        root.powerProfile = p
        run("powerprofilesctl set " + p)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󱐋"
            title: "Power"
            description: "Power profile, idle behaviour, and lock timeouts"
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

                SectionLabel { text: "POWER PROFILE" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: ppCol.implicitHeight + 16

                    ColumnLayout {
                        id: ppCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16; topMargin: 8 }
                        spacing: 0

                        ButtonGroupRow {
                            label: "Mode"
                            description: "Balance battery life and performance"
                            options: [
                                { value: "power-saver", label: "Power Saver" },
                                { value: "balanced",    label: "Balanced"    },
                                { value: "performance", label: "Performance" }
                            ]
                            currentValue: root.powerProfile
                            onSelected: v => root._applyProfile(v)
                        }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "IDLE & SLEEP" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: idleCol.implicitHeight + 16

                    ColumnLayout {
                        id: idleCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16; topMargin: 8 }
                        spacing: 0

                        ToggleRow {
                            label: "Dim screen on idle"
                            description: "Reduce brightness when inactive"
                            checked: root.dimEnabled
                            onToggled: v => { root.dimEnabled = v; root.applyIdleConfig() }
                        }
                        ButtonGroupRow {
                            visible: root.dimEnabled
                            label: ""
                            description: ""
                            options: [
                                { value: "300",  label: "5 min"  },
                                { value: "600",  label: "10 min" },
                                { value: "900",  label: "15 min" },
                                { value: "1800", label: "30 min" }
                            ]
                            currentValue: root.dimTimeout + ""
                            onSelected: v => { root.dimTimeout = parseInt(v); root.applyIdleConfig() }
                        }

                        Item { implicitHeight: 8; Layout.fillWidth: true }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.base }
                        Item { implicitHeight: 8; Layout.fillWidth: true }

                        ToggleRow {
                            label: "Lock screen"
                            description: "Lock after inactivity"
                            checked: root.lockEnabled
                            onToggled: v => { root.lockEnabled = v; root.applyIdleConfig() }
                        }
                        ButtonGroupRow {
                            visible: root.lockEnabled
                            label: ""
                            description: ""
                            options: [
                                { value: "600",  label: "10 min" },
                                { value: "1200", label: "20 min" },
                                { value: "1800", label: "30 min" },
                                { value: "3600", label: "1 hr"   }
                            ]
                            currentValue: root.lockTimeout + ""
                            onSelected: v => { root.lockTimeout = parseInt(v); root.applyIdleConfig() }
                        }

                        Item { implicitHeight: 8; Layout.fillWidth: true }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.base }
                        Item { implicitHeight: 8; Layout.fillWidth: true }

                        ToggleRow {
                            label: "Sleep displays"
                            description: "Turn off displays after extended idle"
                            checked: root.sleepEnabled
                            onToggled: v => { root.sleepEnabled = v; root.applyIdleConfig() }
                        }
                        ButtonGroupRow {
                            visible: root.sleepEnabled
                            label: ""
                            description: ""
                            options: [
                                { value: "1200", label: "20 min" },
                                { value: "1800", label: "30 min" },
                                { value: "3600", label: "1 hr"   },
                                { value: "7200", label: "2 hr"   }
                            ]
                            currentValue: root.sleepTimeout + ""
                            onSelected: v => { root.sleepTimeout = parseInt(v); root.applyIdleConfig() }
                        }
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
