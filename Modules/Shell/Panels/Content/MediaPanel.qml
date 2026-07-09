import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../../Commons" as Commons
import "../../../../Services/Media" as MediaServices

// Standalone media player panel (Sprint 24) — extracted from the old Control
// Center MEDIA section. Lives on the bottom strip next to Dashboard +
// Wallpaper (Caelestia-style). Bound to MprisService; the bar media-marquee
// click opens it. Reports implicitAxis so the strip sizes to content.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    readonly property bool _available: MediaServices.MprisService.available

    // axisSize:"auto" — along-strip extent. Wide (520) on a horizontal strip so
    // art + info sit side-by-side; short (300) on a vertical strip where the
    // player stacks, so it doesn't leave a tall empty gap. (S26-C)
    readonly property real implicitAxis: (panelRoot && !panelRoot._horizontal) ? 300 : 520

    // Responsive: art beside info when wide (bottom strip), stacked above when
    // narrow (vertical side strip). Keys on measured width. (S26-C)
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

        Text {
            text: "󰝚  Media"
            color: Commons.Appearance.colors.text
            font.pixelSize: Commons.Appearance.font.sizeLg
            font.family: Commons.Appearance.font.family
            font.weight: Font.Medium
            Layout.fillWidth: true
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0; opacity: 0.5 }

        // Nothing playing — launch shortcut. Wraps to a column when narrow so
        // the label and button don't collide on a vertical strip.
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

        // Player card — art + info side-by-side, or stacked when narrow.
        // Fill height only when wide; when stacked, pack under the header so a
        // tall panel doesn't scatter the controls with empty space. (S26-C)
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: !root._narrow
            Layout.alignment: root._narrow ? Qt.AlignTop : Qt.AlignVCenter
            visible: root._available
            columns: root._narrow ? 1 : 2
            columnSpacing: 14
            rowSpacing: 14

            // Album art / app icon — smaller when stacked so the info column breathes.
            Rectangle {
                readonly property int _art: root._narrow ? 72 : 92
                Layout.preferredWidth: _art; Layout.preferredHeight: _art
                Layout.alignment: root._narrow ? Qt.AlignHCenter : Qt.AlignVCenter
                radius: Commons.Appearance.radius.base
                color: Commons.Appearance.colors.base

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: MediaServices.MprisService.artUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    Rectangle {
                        anchors.fill: parent
                        radius: Commons.Appearance.radius.base
                        color: "transparent"
                        border.color: Commons.Appearance.colors.accentBorder
                        border.width: 1
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: albumArt.status !== Image.Ready
                    text: MediaServices.MprisService.appIcon || "󰝚"
                    color: Commons.Appearance.colors.accent
                    font.pixelSize: 40
                    font.family: Commons.Appearance.font.family
                }
            }

            // Track info + controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: MediaServices.MprisService.title || "Unknown track"
                    color: Commons.Appearance.colors.text
                    font.pixelSize: Commons.Appearance.font.sizeMd
                    font.family: Commons.Appearance.font.family
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: MediaServices.MprisService.artist || MediaServices.MprisService.identity || ""
                    color: Commons.Appearance.colors.subtext0
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                    elide: Text.ElideRight
                }

                // Progress bar (seekable)
                Item {
                    Layout.fillWidth: true
                    // preferredHeight, not height — a ColumnLayout ignores plain
                    // height (falls back to implicitHeight 0), collapsing this and
                    // overlapping the time labels onto the controls (S26-C fix).
                    Layout.preferredHeight: 28
                    visible: MediaServices.MprisService.length > 0

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top; anchors.topMargin: 6
                        height: 4; radius: 2
                        color: Commons.Appearance.colors.surface0

                        Rectangle {
                            width: MediaServices.MprisService.length > 0 ? parent.width * Math.min(MediaServices.MprisService.position / MediaServices.MprisService.length, 1) : 0
                            height: parent.height; radius: 2
                            color: Commons.Appearance.colors.accent
                            Behavior on width { NumberAnimation { duration: 950 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: mouse => MediaServices.MprisService.seekTo(MediaServices.MprisService.length * (mouse.x / width))
                        }
                    }

                    Text {
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        text: formatTime(MediaServices.MprisService.position)
                        color: Commons.Appearance.colors.overlay0
                        font.pixelSize: 9; font.family: Commons.Appearance.font.family
                    }
                    Text {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        text: formatTime(MediaServices.MprisService.length)
                        color: Commons.Appearance.colors.overlay0
                        font.pixelSize: 9; font.family: Commons.Appearance.font.family
                    }
                }

                // Playback controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "󰒮"
                        color: prevArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: 20; font.family: Commons.Appearance.font.family
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        MouseArea { id: prevArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.previous() }
                    }

                    Item { Layout.preferredWidth: 24 }

                    Text {
                        text: MediaServices.MprisService.playing ? "󰏤" : "󰐊"
                        color: playArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.text
                        font.pixelSize: 26; font.family: Commons.Appearance.font.family
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        MouseArea { id: playArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.togglePlay() }
                    }

                    Item { Layout.preferredWidth: 24 }

                    Text {
                        text: "󰒭"
                        color: nextArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: 20; font.family: Commons.Appearance.font.family
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        MouseArea { id: nextArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.next() }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // Absorbs slack so the stacked (narrow) player packs under the header
        // instead of floating; collapses to 0 when the player fills height.
        Item { Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
