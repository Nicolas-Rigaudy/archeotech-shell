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

    // Idle defaults, declared once: the state until ~/.cache/swayidle.conf is
    // read (or when it does not exist) and each row's reset to default (item_138).
    readonly property var idleDefaults: ({
        dim:   { enabled: true, timeout: 600  },
        lock:  { enabled: true, timeout: 1200 },
        sleep: { enabled: true, timeout: 1800 }
    })
    property bool dimEnabled:   idleDefaults.dim.enabled
    property int  dimTimeout:   idleDefaults.dim.timeout
    property bool lockEnabled:  idleDefaults.lock.enabled
    property int  lockTimeout:  idleDefaults.lock.timeout
    property bool sleepEnabled: idleDefaults.sleep.enabled
    property int  sleepTimeout: idleDefaults.sleep.timeout

    function _idleModified(kind) {
        var d = idleDefaults[kind]
        return root[kind + "Enabled"] !== d.enabled || root[kind + "Timeout"] !== d.timeout
    }
    function _idleReset(kind) {
        root[kind + "Enabled"] = idleDefaults[kind].enabled
        root[kind + "Timeout"] = idleDefaults[kind].timeout
        root.applyIdleConfig()
    }
    function _idleHint(kind) {
        var t = idleDefaults[kind].timeout
        return "Reset to on, " + (t >= 3600 ? (t / 3600) + " hr" : (t / 60) + " min")
    }

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
            // No saved conf: the properties keep idleDefaults.
            "f=$HOME/.cache/swayidle.conf; [ -f \"$f\" ] && cat \"$f\"; true"]
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
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Commons.Appearance.spacing.s6; leftMargin: Commons.Appearance.spacing.s6; rightMargin: Commons.Appearance.spacing.s6 }
                width: root.width - 48
                spacing: Commons.Appearance.spacing.s2

                SectionLabel { text: "POWER PROFILE"; SearchTarget { key: "power.profile"; target: profileCard } }
                UnavailableNote {
                    visible: !root.ppdAvailable
                    text: "power-profiles-daemon (powerprofilesctl) is not installed."
                }

                SettingsCard {
                    id: profileCard
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

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
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
                        searchKey: "power.dim"
                        modified: root._idleModified("dim")
                        resetHint: root._idleHint("dim")
                        onReset: root._idleReset("dim")
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

                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }

                    ToggleRow {
                        label: "Lock screen"
                        searchKey: "power.lock"
                        modified: root._idleModified("lock")
                        resetHint: root._idleHint("lock")
                        onReset: root._idleReset("lock")
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

                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }

                    ToggleRow {
                        label: "Sleep displays"
                        searchKey: "power.sleep"
                        modified: root._idleModified("sleep")
                        resetHint: root._idleHint("sleep")
                        onReset: root._idleReset("sleep")
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
        Layout.bottomMargin: Commons.Appearance.spacing.s1
        wrapMode: Text.WordWrap
        color: Commons.Appearance.colors.yellow
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeSm
    }
}
