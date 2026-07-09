import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices
import "../../../Services/Persistence" as Persistence

Rectangle {
    id: root
    implicitHeight: col.implicitHeight + 24
    color: Commons.Appearance.colors.mantle
    border.color: Commons.Appearance.colors.surface0
    border.width: 1
    radius: Commons.Appearance.radius.md

    property var projects: []

    Component.onCompleted: _refresh()

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            if (ShellServices.ShellState.isOpenAnywhere("dashboard")) root._refresh()
        }
    }

    // Scan roots are config-driven (Persistence.Config "dashboard.scanRoots",
    // an array of dirs; "~/" expands to $HOME). Default: ~/Projects. Add more
    // (e.g. work repos) via config without editing the shell.
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
        command: ["bash", "-c", ""]   // built per-run from config in _refresh()

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

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        Text {
            text: "ACTIVE PROJECTS"
            color: Commons.Appearance.colors.accent
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.letterSpacing: 1.5
            opacity: 0.85
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

        Text {
            visible: root.projects.length === 0
            text: projectsProc.running ? "scanning…" : "no repositories found"
            color: Commons.Appearance.colors.overlay1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.italic: true
        }

        Repeater {
            model: root.projects.slice(0, 8)
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: 24
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
                    width: parent.width * 0.50
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
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                }

                HoverHandler { id: rowHov }
                TapHandler { onTapped: root.openProject(modelData.path) }
            }
        }
    }
}
