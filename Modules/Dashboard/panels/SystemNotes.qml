import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

DashCard {
    id: root
    title: "SYSTEM NOTES"

    property string snap:    "…"
    property string updates: "…"
    property string aur:     "0"
    property string vpn:     "…"
    property string aws:     "…"
    property string uptime:  "…"
    property string kernel:  "…"
    property string host:    "…"
    property string ip:      "…"

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
        // /var/lib/pacman/sync, so the count is always fresh. `paru -Qua` queries
        // AUR directly. Both fall back to `pacman -Qu` if the helper is missing.
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
            // AWS profile a NEW terminal gets: the shell's own $AWS_PROFILE is
            // meaningless (set per terminal), so read the login shell's startup
            // value (fish universal/config vars), falling back to [default] if
            // ~/.aws/config defines it — the AWS CLI's own fallback.
            "p=''; if command -v fish >/dev/null 2>&1; then p=$(timeout 1 fish -c 'printf %s \"$AWS_PROFILE\"' 2>/dev/null); fi; " +
            "if [ -z \"$p\" ] && grep -q '^\\[default\\]' \"$HOME/.aws/config\" 2>/dev/null; then p=default; fi; " +
            "echo aws:${p:-none}; " +
            "echo up:$(awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60); " +
            "if(d>0)printf \"%dd %dh\",d,h; else if(h>0)printf \"%dh %dm\",h,m; else printf \"%dm\",m}' /proc/uptime); " +
            "echo kern:$(uname -r); " +
            "echo host:$(cat /etc/hostname 2>/dev/null || hostname); " +
            "echo ip:$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\"){print $(i+1);exit}}')"
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
                if (key === "up")      root.uptime  = val || "N/A"
                if (key === "kern")    root.kernel  = val || "N/A"
                if (key === "host")    root.host    = val || "N/A"
                if (key === "ip")      root.ip      = val || "offline"
            }
        }
    }

    component NoteRow: Item {
        required property string label
        required property string value
        required property color  valueColor
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 22

        Text {
            id: noteLbl
            text: label
            color: Commons.Appearance.colors.subtext0
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 74
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: value
            color: valueColor
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            anchors { left: noteLbl.right; leftMargin: 6; right: parent.right; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    // 2-column key/value grid.
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 20
        rowSpacing: 4

        NoteRow {
            label: "Snapshot"
            value: root.snap
            valueColor: Commons.Appearance.colors.text
        }
        NoteRow {
            label: "Uptime"
            value: root.uptime
            valueColor: Commons.Appearance.colors.text
        }
        NoteRow {
            label: "Updates"
            value: {
                var u = parseInt(root.updates) || 0
                var a = parseInt(root.aur)     || 0
                if (u === 0 && a === 0) return "up to date"
                if (u === 0)            return a + " AUR"
                if (a === 0)            return u + " pkgs"
                return u + " + " + a + " AUR"
            }
            valueColor: (root.updates === "0" && root.aur === "0")
                ? Commons.Appearance.colors.green
                : Commons.Appearance.colors.yellow
        }
        NoteRow {
            label: "Kernel"
            value: root.kernel
            valueColor: Commons.Appearance.colors.subtext1
        }
        NoteRow {
            label: "VPN"
            value: root.vpn
            valueColor: root.vpn === "inactive" ? Commons.Appearance.colors.overlay1 : Commons.Appearance.colors.green
        }
        NoteRow {
            label: "Host"
            value: root.host
            valueColor: Commons.Appearance.colors.subtext1
        }
        NoteRow {
            label: "AWS"
            value: root.aws
            valueColor: root.aws === "none" ? Commons.Appearance.colors.overlay1 : Commons.Appearance.colors.blue
        }
        NoteRow {
            label: "IP"
            value: root.ip
            valueColor: root.ip === "offline" ? Commons.Appearance.colors.overlay1 : Commons.Appearance.colors.blue
        }
    }
}
