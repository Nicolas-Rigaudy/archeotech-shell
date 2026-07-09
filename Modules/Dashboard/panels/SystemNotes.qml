import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

Rectangle {
    id: root
    implicitHeight: noteCol.implicitHeight + 24
    color: Commons.Appearance.colors.mantle
    border.color: Commons.Appearance.colors.surface0
    border.width: 1
    radius: Commons.Appearance.radius.md

    property string snap:    "…"
    property string updates: "…"
    property string aur:     "0"
    property string vpn:     "…"
    property string aws:     "…"

    Component.onCompleted: _refresh()

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            if (ShellServices.ShellState.isOpenAnywhere("dashboard")) root._refresh()
        }
    }

    function _refresh() {
        if (!notesProc.running) notesProc.running = true
    }

    Process {
        id: notesProc
        running: false
        // checkupdates (pacman-contrib) syncs to a temp DB without touching
        // /var/lib/pacman/sync, so the count is always fresh — unlike plain
        // `pacman -Qu` which only sees updates after a real `pacman -Sy`.
        // `paru -Qua` queries AUR directly (no sync needed).
        // Both fall back to `pacman -Qu` if their helper isn't installed.
        command: ["bash", "-c",
            "snap=$(snapper -c root list 2>/dev/null | awk -F'│' " +
            "'NR>2 && NF>1 && length($4)>4 {gsub(/^[[:space:]]+|[[:space:]]+$/,\"\",$(4)); last=$(4)} " +
            "END{print length(last)>0 ? last : \"N/A\"}'); echo snap:${snap:-N/A}; " +
            "if command -v checkupdates >/dev/null 2>&1; then " +
            "  upd=$(checkupdates 2>/dev/null | wc -l | tr -d ' '); " +
            "else " +
            "  upd=$(pacman -Qu 2>/dev/null | wc -l | tr -d ' '); " +
            "fi; echo updates:${upd:-0}; " +
            "if command -v paru >/dev/null 2>&1; then " +
            "  aur=$(paru -Qua 2>/dev/null | wc -l | tr -d ' '); " +
            "else aur=0; fi; echo aur:${aur:-0}; " +
            "vpn=$(nmcli con show --active 2>/dev/null | awk '/vpn/{print $1;exit}'); " +
            "echo vpn:${vpn:-inactive}; " +
            "echo aws:${AWS_PROFILE:-unset}"
        ]
        stdout: SplitParser {
            onRead: line => {
                var sep = line.indexOf(":")
                if (sep < 0) return
                var key = line.slice(0, sep), val = line.slice(sep + 1)
                if (key === "snap")    root.snap    = val
                if (key === "updates") root.updates = val
                if (key === "aur")     root.aur     = val
                if (key === "vpn")     root.vpn     = val
                if (key === "aws")     root.aws     = val
            }
        }
    }

    component NoteRow: Item {
        required property string label
        required property string value
        required property color  valueColor
        Layout.fillWidth: true
        height: 22

        Text {
            text: label
            color: Commons.Appearance.colors.subtext0
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 120
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: value
            color: valueColor
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            anchors { left: parent.left; leftMargin: 124; right: parent.right; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        id: noteCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        Text {
            text: "SYSTEM NOTES"
            color: Commons.Appearance.colors.accent
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.letterSpacing: 1.5
            opacity: 0.85
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

        NoteRow {
            label: "Last snapshot"
            value: root.snap
            valueColor: Commons.Appearance.colors.text
        }
        NoteRow {
            label: "Pending updates"
            value: {
                var u = parseInt(root.updates) || 0
                var a = parseInt(root.aur)     || 0
                if (u === 0 && a === 0) return "up to date"
                if (u === 0)            return a + " AUR"
                if (a === 0)            return u + " packages"
                return u + " + " + a + " AUR"
            }
            valueColor: (root.updates === "0" && root.aur === "0")
                ? Commons.Appearance.colors.green
                : Commons.Appearance.colors.yellow
        }
        NoteRow {
            label: "VPN"
            value: root.vpn
            valueColor: root.vpn === "inactive" ? Commons.Appearance.colors.overlay1 : Commons.Appearance.colors.green
        }
        NoteRow {
            label: "AWS profile"
            value: root.aws
            valueColor: root.aws === "unset" ? Commons.Appearance.colors.overlay1 : Commons.Appearance.colors.blue
        }

    }
}
