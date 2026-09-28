import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../Widgets"

Item {
    id: root

    // ── State ──────────────────────────────────────────────────────────────────
    property string displayLayout:  "extend"
    property string nightLightMode: "off"

    Component.onCompleted: nightLightReader.running = true

    // ── Process helpers ────────────────────────────────────────────────────────
    Commons.CommandRunner { id: cmdRunner }
    function run(cmd) { cmdRunner.runShell(cmd) }

    Process {
        id: nightLightReader
        command: ["bash", "-c",
            "[ -f $HOME/.cache/wlsunset.pid ] && kill -0 $(cat $HOME/.cache/wlsunset.pid) 2>/dev/null " +
            "&& grep -oP '(?<=-t )\\d+' /proc/$(cat $HOME/.cache/wlsunset.pid)/cmdline 2>/dev/null " +
            "|| echo off"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var t = data.trim()
                root.nightLightMode = (t === "4500" || t === "3500" || t === "2700") ? t : "off"
            }
        }
    }

    // Detect the internal panel by connector prefix (eDP/LVDS/DSI on laptops),
    // falling back to the first output — no hardcoded connector name. `$int` is
    // the internal display, `$ext` the newline-separated list of the rest.
    readonly property string _outputsPrelude:
        "outs=$(wlr-randr 2>/dev/null | grep '^[^ ]' | awk '{print $1}'); " +
        "int=$(printf '%s\\n' \"$outs\" | grep -iE '^(eDP|LVDS|DSI)' | head -1); " +
        "[ -z \"$int\" ] && int=$(printf '%s\\n' \"$outs\" | head -1); " +
        "ext=$(printf '%s\\n' \"$outs\" | grep -vx \"$int\"); "

    function _applyDisplay(mode) {
        root.displayLayout = mode
        if (mode === "extend") {
            run(_outputsPrelude + "wlr-randr --output \"$int\" --on --pos 0,0; for e in $ext; do wlr-randr --output \"$e\" --on --pos 1920,0; done")
        } else if (mode === "mirror") {
            run(_outputsPrelude + "wlr-randr --output \"$int\" --on --pos 0,0; for e in $ext; do wlr-randr --output \"$e\" --on --pos 0,0; done")
        } else if (mode === "laptop") {
            run(_outputsPrelude + "wlr-randr --output \"$int\" --on; for e in $ext; do wlr-randr --output \"$e\" --off; done")
        } else if (mode === "external") {
            run(_outputsPrelude + "wlr-randr --output \"$int\" --off; for e in $ext; do wlr-randr --output \"$e\" --on --pos 0,0; done")
        }
    }

    function _applyNightLight(mode) {
        root.nightLightMode = mode
        if (mode === "off") {
            run("pkill -x wlsunset 2>/dev/null; rm -f $HOME/.cache/wlsunset.pid || true")
        } else {
            run("pkill -x wlsunset 2>/dev/null; rm -f $HOME/.cache/wlsunset.pid; " +
                "wlsunset -T 6500 -t " + mode + " & echo $! > $HOME/.cache/wlsunset.pid")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󱄅"
            title: "Display"
            description: "Monitor layout and color temperature"
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

                SectionLabel { text: "MONITOR LAYOUT" }

                SettingsCard {
                        ButtonGroupRow {
                            label: "Layout"
                            description: "Switch how your monitors are arranged"
                            options: [
                                { value: "extend",   label: "Extend"   },
                                { value: "mirror",   label: "Mirror"   },
                                { value: "laptop",   label: "Laptop"   },
                                { value: "external", label: "External" }
                            ]
                            currentValue: root.displayLayout
                            onSelected: v => root._applyDisplay(v)
                        }
                        Item { implicitHeight: 8; Layout.fillWidth: true }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                        Item { implicitHeight: 8; Layout.fillWidth: true }
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Adjust manually"; color: Commons.Appearance.colors.text; font.pixelSize: Commons.Appearance.font.sizeBase; font.family: Commons.Appearance.font.family }
                                Text { text: "Open wdisplays for per-monitor tweaks"; color: Commons.Appearance.colors.overlay0; font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family }
                            }
                            GlassButton {
                                text: "Open"
                                onClicked: root.run("wdisplays &")
                            }
                        }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "NIGHT LIGHT" }

                SettingsCard {
                    ButtonGroupRow {
                        label: "Color temperature"
                        description: "Reduce blue light during evening hours"
                        options: [
                            { value: "off",  label: "Off"   },
                            { value: "4500", label: "4500K" },
                            { value: "3500", label: "3500K" },
                            { value: "2700", label: "2700K" }
                        ]
                        currentValue: root.nightLightMode
                        onSelected: v => root._applyNightLight(v)
                    }
                }
            }
        }
    }
}
