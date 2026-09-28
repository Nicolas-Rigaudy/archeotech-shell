import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../../Commons/Primitives" as Prim
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

    // axisSize:"auto" — along-strip extent. The COMPACT face wants a smaller panel,
    // so shrink the extent when it's active → switching face is a real footprint
    // change, not just an internal layout swap. (Animated so the strip resizes
    // smoothly.) Falls back to the full size until the FaceHost exists.
    property real implicitAxis: {
        if (!root._available) return (panelRoot && !panelRoot._horizontal) ? 300 : 440   // idle card
        var compact = mediaFaces && mediaFaces.face === "compact"
        if (panelRoot && !panelRoot._horizontal) return compact ? 210 : 300   // vertical strip
        return compact ? 360 : 520                                            // horizontal strip
    }
    Behavior on implicitAxis { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }

    // CROSS-axis DEPTH per face (only on a horizontal strip, where the cross axis is
    // the panel HEIGHT) — declared per face (like implicitAxis), NOT measured, so
    // there's no layout-measurement loop. Compact → short; full → the tuned height.
    // 0 on a vertical strip → keep the fixed panelSize there.
    property real implicitPerp: (panelRoot && panelRoot._horizontal)
        ? (!root._available ? 296 : mediaFaces && mediaFaces.face === "compact" ? 224 : 296)
        : 0
    Behavior on implicitPerp { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }

    // Responsive: faces key on this to stack when narrow (vertical side strip).
    readonly property bool _narrow: width < 360

    Commons.CommandRunner { id: cmdRunner }
    function run(cmd) { cmdRunner.runShell(cmd) }

    // Idle state: offer the media players that are actually installed (checked
    // once at load) instead of a hard-coded Spotify chip a stranger may not have.
    readonly property var _playerCandidates: [
        { bin: "spotify-launcher", name: "Spotify",       icon: "󰓇" },
        { bin: "spotify",          name: "Spotify",       icon: "󰓇" },
        { bin: "youtube-music",    name: "YouTube Music", icon: "󰗃" },
        { bin: "tidal-hifi",       name: "Tidal",         icon: "󰝚" },
        { bin: "strawberry",       name: "Strawberry",    icon: "󰝚" },
        { bin: "elisa",            name: "Elisa",         icon: "󰝚" },
        { bin: "rhythmbox",        name: "Rhythmbox",     icon: "󰝚" },
        { bin: "amberol",          name: "Amberol",       icon: "󰝚" }
    ]
    property var installedPlayers: []
    Process {
        running: true
        command: ["bash", "-c", "for c in \"$@\"; do command -v \"$c\" >/dev/null && echo \"$c\"; done", "_"]
                 .concat(root._playerCandidates.map(function(c) { return c.bin }))
        stdout: StdioCollector {
            onStreamFinished: {
                var found = text.split("\n"), out = [], names = {}
                for (var i = 0; i < root._playerCandidates.length; i++) {
                    var c = root._playerCandidates[i]
                    if (found.indexOf(c.bin) !== -1 && !names[c.name]) { names[c.name] = 1; out.push(c) }
                }
                root.installedPlayers = out
            }
        }
    }

    function formatTime(secs) {
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Commons.Appearance.spacing.xl   // shared panel padding
        spacing: Commons.Appearance.spacing.xl            // shared inter-item gap

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

        // Nothing playing — a designed empty state: glyph, title, a hint and one
        // launch button per installed player (wraps when narrow).
        ColumnLayout {
            visible: !root._available
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Commons.Appearance.spacing.sm

            Item { Layout.fillHeight: true }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰝚"
                color: Commons.Appearance.colors.accent
                font.pixelSize: 34
                font.family: Commons.Appearance.font.family
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing playing"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.family: Commons.Appearance.font.family
                font.weight: Font.Medium
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.installedPlayers.length > 0
                    ? "Start something and it shows up here"
                    : "No media player found; anything that speaks MPRIS shows up here"
                color: Commons.Appearance.colors.subtext0
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
            }
            Flow {
                visible: root.installedPlayers.length > 0
                // Full width so wrapping is guaranteed; children centre via the
                // per-row padding below.
                Layout.fillWidth: true
                Layout.topMargin: Commons.Appearance.spacing.sm
                spacing: Commons.Appearance.spacing.sm
                leftPadding: Math.max(0, (width - _rowW) / 2)
                // Width of the first row when everything fits on one line; when it
                // wraps, left-align (padding 0) rather than guess per-row widths.
                readonly property real _rowW: {
                    var w = 0
                    for (var i = 0; i < children.length; i++)
                        if (children[i].visible && children[i].width > 0) w += children[i].width + (w > 0 ? spacing : 0)
                    return w <= width ? w : width
                }
                Repeater {
                    model: root.installedPlayers
                    delegate: Prim.GlassButton {
                        id: playerBtn
                        required property var modelData
                        text: playerBtn.modelData.icon + "  " + playerBtn.modelData.name
                        onClicked: {
                            Quickshell.execDetached([playerBtn.modelData.bin])
                            if (root.panelRoot) root.panelRoot.close()
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // Player faces — full / compact, switchable + persisted.
        ShellUI.FaceHost {
            id: mediaFaces
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
