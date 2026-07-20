import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices
import "../../../Services/Persistence" as Persistence

DashCard {
    id: root
    title: "ACTIVE PROJECTS"

    property var projects: []
    readonly property int _rowH: 28

    Component.onCompleted: _refresh()

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            if (ShellServices.ShellState.isOpenAnywhere("dashboard")) root._refresh()
        }
    }

    // Scan roots are config-driven (Persistence.Config "dashboard.scanRoots").
    function _refresh() {
        root.projects = []
        var roots = Persistence.Config.get("dashboard.scanRoots", ["~/Projects"])
        var scans = roots.map(function (r) {
            return "scan \"" + String(r).replace(/^~\//, "$HOME/") + "\""
        }).join("; ")
        projectsProc.command = ["bash", "-c",
            "scan(){ [ -d \"$1\" ] || return; for d in \"$1\"/*/; do [ -d \"$d/.git\" ] || continue; " +
            "n=$(basename \"$d\"); b=$(git -C \"$d\" branch --show-current 2>/dev/null||echo '?'); " +
            "x=$(git -C \"$d\" status --short 2>/dev/null|wc -l|tr -d ' '); " +
            "echo \"$n|${b:-detached}|$x|$d\"; done; }; " + scans
        ]
        if (!projectsProc.running) projectsProc.running = true
    }

    Process {
        id: launchProc
        running: false
        command: ["bash", "-c", ""]
        onExited: command = ["bash", "-c", ""]
    }

    function openProject(path) {
        var p = JSON.stringify(path.trim())
        launchProc.command = ["bash", "-c",
            "setsid code " + p + " >/dev/null 2>&1 & " +
            "setsid kitty --directory " + p + " >/dev/null 2>&1 &"
        ]
        launchProc.running = true
        ShellServices.ShellState.closeAllAcross()
    }

    Process {
        id: projectsProc
        running: false
        command: ["bash", "-c", ""]

        property var _buf: []
        onRunningChanged: if (running) _buf = []

        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|")
                if (p.length >= 4)
                    projectsProc._buf = projectsProc._buf.concat([{ name: p[0], branch: p[1], dirty: parseInt(p[2]) || 0, path: p[3] }])
            }
        }
        onExited: root.projects = projectsProc._buf
    }

    Text {
        visible: root.projects.length === 0
        Layout.fillWidth: true
        text: projectsProc.running ? "scanning…" : "no repositories found"
        color: Commons.Appearance.colors.overlay1
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeBase
        font.italic: true
    }

    // Capped at 4 visible rows; scrolls inside the card when there are more.
    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.projects.length, 4) * root._rowH
        visible: root.projects.length > 0
        clip: true
        interactive: root.projects.length > 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.projects
        spacing: 0

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: root._rowH
            radius: Commons.Appearance.radius.sm
            color: rowHov.containsMouse ? Commons.Appearance.colors.accentAlpha : "transparent"
            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

            Rectangle {
                width: 7; height: 7; radius: 4
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                color: modelData.dirty > 0 ? Commons.Appearance.colors.peach : Commons.Appearance.colors.green
            }
            Text {
                id: nameLbl
                text: modelData.name
                color: Commons.Appearance.colors.text
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                anchors { left: parent.left; leftMargin: 21; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                width: parent.width * 0.48
            }
            Text {
                text: modelData.branch
                color: Commons.Appearance.colors.subtext0
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                anchors { left: nameLbl.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                width: parent.width * 0.28
            }
            Text {
                text: modelData.dirty > 0 ? "+" + modelData.dirty : "✔"
                color: modelData.dirty > 0 ? Commons.Appearance.colors.peach : Commons.Appearance.colors.green
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            }

            HoverHandler { id: rowHov }
            TapHandler { onTapped: root.openProject(modelData.path) }
        }
    }
}
