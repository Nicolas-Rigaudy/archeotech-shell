import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../../../Services/Shell" as ShellServices
import "../../../Services/Persistence" as Persistence

DashCard {
    id: root
    title: "ACTIVE PROJECTS"

    property var projects: []
    readonly property int _rowH: 28

    // Scan once config.json has loaded (before that, get() gives the default roots).
    Component.onCompleted: if (Persistence.Config.ready) _refresh()
    Connections {
        target: Persistence.Config
        function onReadyChanged() { if (Persistence.Config.ready) root._refresh() }
    }

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            if (ShellServices.ShellState.isOpenAnywhere("dashboard")) root._refresh()
        }
    }

    // Scan roots are config-driven (Persistence.Config "dashboard.scanRoots",
    // Settings → Shell → Dashboard); a change rescans at once.
    readonly property var _roots: Persistence.Config.get("dashboard.scanRoots", ["~/Projects"])
    on_RootsChanged: if (Persistence.Config.ready) _refresh()

    // Roots go to bash as arguments ("$@"), never into the script text, so a
    // folder name typed in Settings cannot run as shell code. "~/" expands here.
    function _refresh() {
        root.projects = []
        var roots = (root._roots || []).map(function (r) {
            return String(r).replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
        })
        projectsProc.command = ["bash", "-c",
            "for r in \"$@\"; do [ -d \"$r\" ] || continue; for d in \"$r\"/*/; do [ -d \"$d/.git\" ] || continue; " +
            "n=$(basename \"$d\"); b=$(git -C \"$d\" branch --show-current 2>/dev/null||echo '?'); " +
            "x=$(git -C \"$d\" status --short 2>/dev/null|wc -l|tr -d ' '); " +
            "echo \"$n|${b:-detached}|$x|$d\"; done; done", "scan"].concat(roots)
        // A scan already running finishes first, then this one runs.
        if (projectsProc.running) projectsProc._again = true
        else projectsProc.running = true
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
        property bool _again: false
        onRunningChanged: if (running) _buf = []

        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|")
                if (p.length >= 4)
                    projectsProc._buf = projectsProc._buf.concat([{ name: p[0], branch: p[1], dirty: parseInt(p[2]) || 0, path: p[3] }])
            }
        }
        onExited: {
            // A queued rescan replaces this (stale) result instead of flashing it.
            if (projectsProc._again) { projectsProc._again = false; projectsProc.running = true }
            else root.projects = projectsProc._buf
        }
    }

    Text {
        visible: root.projects.length === 0
        Layout.fillWidth: true
        text: projectsProc.running ? "scanning…" : "no repositories found"
        color: Commons.Appearance.colors.textMuted
        font.family: Commons.Appearance.font.family
        font.pixelSize: Commons.Appearance.font.sizeBase
        font.italic: true
    }

    // Capped at 4 visible rows; scrolls inside the card when there are more.
    ListView {
        Layout.fillWidth: true
        // Bleed 8px into the card padding on each side so the full-row hover
        // highlight is wider than the text (doesn't clip at the content edges).
        // Row content is re-padded to stay flush at 16px like the other cards.
        Layout.leftMargin:  -Commons.Appearance.spacing.s2
        Layout.rightMargin: -Commons.Appearance.spacing.s2
        Layout.preferredHeight: Math.min(root.projects.length, 4) * root._rowH
        visible: root.projects.length > 0
        clip: true
        interactive: root.projects.length > 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.projects
        spacing: 0

        // Thin scrollbar tucked into the card's edge margin so it never sits on
        // top of the row items. -6 pushes it past the list's 8px bleed to the edge.
        ScrollBar.vertical: ScrollBar {
            id: projScroll
            policy: ScrollBar.AsNeeded
            implicitWidth: 8
            anchors.rightMargin: -Commons.Appearance.spacing.s2
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Commons.Appearance.colors.overlay0
                opacity: projScroll.pressed ? 0.9 : 0.45
                Behavior on opacity { Commons.ColorAnim {} }
            }
        }

        delegate: Rectangle {
            id: projRow
            required property var modelData
            width: ListView.view.width
            height: root._rowH
            radius: Commons.Appearance.radius.sm
            color: "transparent"
            Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }

            Rectangle {
                width: 7; height: 7; radius: 4
                // +8 re-pad to sit flush at 16px from the card edge (list bleeds 8).
                anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s2; verticalCenter: parent.verticalCenter }
                color: modelData.dirty > 0 ? Commons.Appearance.colors.peach : Commons.Appearance.colors.green
            }
            Text {
                id: nameLbl
                text: modelData.name
                color: Commons.Appearance.colors.textPrimary
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s6; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                width: parent.width * 0.48
            }
            Text {
                text: modelData.branch
                color: Commons.Appearance.colors.textSecondary
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                anchors { left: nameLbl.right; leftMargin: Commons.Appearance.spacing.s2; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                width: parent.width * 0.28
            }
            Text {
                text: modelData.dirty > 0 ? "+" + modelData.dirty : "✔"
                color: modelData.dirty > 0 ? Commons.Appearance.colors.peach : Commons.Appearance.colors.green
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeBase
                // +8 re-pad to sit flush at 16px from the card edge (list bleeds 8).
                anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s2; verticalCenter: parent.verticalCenter }
            }

            StateLayer {
                anchors.fill: parent
                hoverScale: 1.0
                pressScale: 0.98
                onClicked: root.openProject(projRow.modelData.path)
            }
        }
    }
}
