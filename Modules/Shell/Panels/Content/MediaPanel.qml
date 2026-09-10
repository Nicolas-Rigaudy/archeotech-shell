import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../../Services/Media" as MediaServices
import "../.." as ShellUI

// Standalone media player panel (Sprint 24) — extracted from the old Control
// Center MEDIA section. Lives on the bottom strip next to Dashboard + Wallpaper.
// Bound to MprisService; the bar media-marquee click opens it.
//
// Player presentation is delegated to swappable FACES (req_003 / task_030) via
// the shared FaceHost: `full` (art + info + seek + transport) and `compact`
// (small art + title + inline transport). Switch by two-finger vertical scroll,
// drag-swipe, or tapping a page-dot; the choice persists under "media.face".
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    readonly property bool _available: MediaServices.MprisService.available

    // axisSize:"auto" — along-strip extent. Wide (520) horizontal so a face can
    // put art beside info; short (300) vertical so the player stacks.
    readonly property real implicitAxis: (panelRoot && !panelRoot._horizontal) ? 300 : 520

    // Responsive: faces key on this to stack when narrow (vertical side strip).
    readonly property bool _narrow: width < 360

    Process {
        id: cmdRunner
        running: false
        property string cmd: ""
        command: ["bash", "-c", cmd]
    }
    function run(cmd) { cmdRunner.cmd = cmd; cmdRunner.running = true }

    function formatTime(secs) {
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Commons.Appearance.spacing.lg
        spacing: Commons.Appearance.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "󰝚"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.family: Commons.Appearance.font.family
            }
            Text {
                text: "Media"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.family: Commons.Appearance.font.display
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0; opacity: 0.5 }

        // Nothing playing — launch shortcut (wraps to a column when narrow).
        GridLayout {
            Layout.fillWidth: true
            visible: !root._available
            columns: root._narrow ? 1 : 2
            columnSpacing: 10
            rowSpacing: 8
            Text {
                text: "󰝚  Nothing playing"
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.preferredWidth: 100; Layout.preferredHeight: 30
                Layout.alignment: root._narrow ? Qt.AlignLeft : Qt.AlignRight
                radius: Commons.Appearance.radius.base
                color: spotifyArea.containsMouse ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.base
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                Text {
                    anchors.centerIn: parent
                    text: "󰓇  Spotify"
                    color: Commons.Appearance.colors.subtext1
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                }
                MouseArea {
                    id: spotifyArea; anchors.fill: parent; hoverEnabled: true
                    onClicked: { root.run("spotify-launcher &"); if (root.panelRoot) root.panelRoot.close() }
                }
            }
        }

        // Player faces — full / compact, switchable + persisted.
        ShellUI.FaceHost {
            visible: root._available
            Layout.fillWidth: true
            Layout.fillHeight: true
            faces: [
                { id: "full",    label: "Full",    file: Qt.resolvedUrl("faces/MediaFull.qml") },
                { id: "compact", label: "Compact", file: Qt.resolvedUrl("faces/MediaCompact.qml") }
            ]
            face: "full"
            configPath: "media.face"
            context: root
        }
    }
}
