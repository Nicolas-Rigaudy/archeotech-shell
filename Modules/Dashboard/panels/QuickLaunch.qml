import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../../../Services/Shell" as ShellServices

DashCard {
    id: root
    title: "QUICK LAUNCH"

    Process {
        id: launchProc
        running: false
        command: ["bash", "-c", ""]
        onExited: command = ["bash", "-c", ""]
    }

    function launch(cmd) {
        launchProc.command = ["bash", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"]
        launchProc.running = true
        ShellServices.ShellState.closeAllAcross()
    }

    readonly property string _p: "file:///usr/share/icons/Papirus/32x32/"
    readonly property var apps: [
        { label: "Terminal",    icon: _p + "apps/kitty.svg",               cmd: "kitty" },
        { label: "Browser",     icon: _p + "apps/zen-browser.svg",         cmd: "zen-browser" },
        { label: "Editor",      icon: _p + "apps/visual-studio-code.svg",  cmd: "code" },
        { label: "Notes",       icon: _p + "apps/obsidian.svg",            cmd: "obsidian" },
        { label: "Lazygit",     icon: _p + "apps/git.svg",                 cmd: "kitty --title lazygit -e lazygit" },
        { label: "Files",       icon: _p + "places/folder.svg",            cmd: "kitty --title yazi -e yazi" },
        { label: "Monitor",     icon: _p + "apps/btop.svg",                cmd: "kitty --title btop -e btop" },
        { label: "Cheatsheets", icon: _p + "apps/help-browser.svg",        cmd: "kitty --title navi -e navi" }
    ]

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.apps
            delegate: Rectangle {
                id: tile
                required property var modelData
                width: 110; height: 34
                radius: Commons.Appearance.radius.base
                color: Commons.Appearance.colors.surface0Alpha
                border.color: launchLayer.hovered ? Commons.Appearance.colors.accentBorder : "transparent"
                border.width: 1
                Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        source: modelData.icon
                        width: 16; height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        smooth: true
                        visible: status === Image.Ready
                    }

                    Text {
                        text: modelData.label
                        color: Commons.Appearance.colors.text
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeBase
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StateLayer {
                    id: launchLayer
                    anchors.fill: parent
                    hoverScale: 1.05
                    pressScale: 0.96
                    onClicked: root.launch(tile.modelData.cmd)
                }
            }
        }
    }
}
