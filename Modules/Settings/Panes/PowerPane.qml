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

    // Backends these controls drive. A control whose backend is missing is shown
    // disabled with the reason, rather than silently doing nothing (design rule 6).
    // The idle script ships with the owner's dotfiles, not with the shell.
    property bool ppdAvailable:  false
    property bool idleAvailable: false

    Component.onCompleted: {
        backendProbe.running     = true
        profileReader.running    = true
        idleConfigReader.running = true
    }

    Process {
        id: backendProbe
        command: ["bash", "-c",
            "command -v powerprofilesctl >/dev/null 2>&1 && echo ppd; " +
            "[ -x \"$HOME/.config/swayidle/config.sh\" ] && command -v swayidle >/dev/null 2>&1 && echo idle; true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "ppd")  root.ppdAvailable  = true
                if (data.trim() === "idle") root.idleAvailable = true
            }
        }
    }

    // ── Process helpers ────────────────────────────────────────────────────────
    Commons.CommandRunner { id: cmdRunner }
    function run(cmd) { cmdRunner.runShell(cmd) }

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
                UnavailableNote {
                    visible: !root.ppdAvailable
                    text: "power-profiles-daemon (powerprofilesctl) is not installed."
                }

                SettingsCard {
                    enabled: root.ppdAvailable
                    opacity: enabled ? 1.0 : 0.45
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

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "IDLE & SLEEP" }
                UnavailableNote {
                    visible: !root.idleAvailable
                    text: "Idle control needs swayidle and an executable ~/.config/swayidle/config.sh."
                }

                SettingsCard {
                    enabled: root.idleAvailable
                    opacity: enabled ? 1.0 : 0.45
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
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
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
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
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

    // One-line reason shown above a section whose backend is missing.
    component UnavailableNote: Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        wrapMode: Text.WordWrap
        color: Commons.Appearance.colors.yellow
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeSm
    }
}
