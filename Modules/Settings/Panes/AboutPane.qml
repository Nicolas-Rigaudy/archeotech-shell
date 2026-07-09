import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../Widgets"

Item {
    id: root

    Process {
        id: runner
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰅺"
            title: "About"
            description: "Shell version, compositor info, and quick links"
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

            ColumnLayout {
                id: col
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 24; leftMargin: 24; rightMargin: 24 }
                width: root.width - 48
                spacing: 6

                // ── Hero ──────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: heroCol.implicitHeight

                    ColumnLayout {
                        id: heroCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 24; rightMargin: 24 }
                        spacing: 4

                        Item { implicitHeight: 20; Layout.fillWidth: true }

                        Text {
                            text: "󰒓"
                            color: Commons.Appearance.colors.accent
                            font.pixelSize: 36
                            font.family: Commons.Appearance.font.family
                        }

                        Text {
                            text: "Archeotech Shell"
                            color: Commons.Appearance.colors.text
                            font.pixelSize: 22
                            font.family: Commons.Appearance.font.family
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Quickshell-based Wayland shell for MangoWC"
                            color: Commons.Appearance.colors.subtext0
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                        }

                        Text {
                            text: "Catppuccin Macchiato  ·  FiraCode Nerd Font"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                        }

                        Item { implicitHeight: 20; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "ENVIRONMENT" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: infoCol.implicitHeight

                    ColumnLayout {
                        id: infoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0

                        Item { implicitHeight: 8; Layout.fillWidth: true }

                        Repeater {
                            model: [
                                { label: "Shell",      value: "Quickshell 0.2.1"    },
                                { label: "Compositor", value: "MangoWC"              },
                                { label: "Palette",    value: "Catppuccin Macchiato" },
                                { label: "Font",       value: "FiraCode Nerd Font"   },
                            ]
                            delegate: Item {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 32

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1; color: Commons.Appearance.colors.base
                                }

                                RowLayout {
                                    anchors { fill: parent; topMargin: index > 0 ? 1 : 0 }

                                    Text {
                                        text: modelData.label
                                        color: Commons.Appearance.colors.overlay0
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                        font.family: Commons.Appearance.font.family
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: modelData.value
                                        color: Commons.Appearance.colors.subtext1
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                        font.family: Commons.Appearance.font.family
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 8; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "LINKS" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: linksCol.implicitHeight

                    ColumnLayout {
                        id: linksCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 }
                        spacing: 0

                        Item { implicitHeight: 6; Layout.fillWidth: true }

                        Repeater {
                            model: [
                                { icon: "󰊤", label: "GitHub Repository",  cmd: "xdg-open https://github.com"                          },
                                { icon: "󰖔", label: "Quickshell Docs",    cmd: "xdg-open https://quickshell.outfoxxed.me"             },
                                { icon: "󰋊", label: "MangoWC Source",     cmd: "xdg-open https://codeberg.org/mango_ct/MangoWC"       },
                                { icon: "󰉦", label: "Catppuccin Palette", cmd: "xdg-open https://catppuccin.com"                      },
                            ]
                            delegate: Item {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 40

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1; color: Commons.Appearance.colors.base
                                }

                                Rectangle {
                                    anchors { fill: parent; topMargin: index > 0 ? 1 : 0 }
                                    color: linkMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent"
                                    radius: Commons.Appearance.radius.sm
                                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                        spacing: 10

                                        Text {
                                            text: modelData.icon
                                            color: Commons.Appearance.colors.overlay0
                                            font.pixelSize: 16; font.family: Commons.Appearance.font.family
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Text {
                                            text: modelData.label
                                            color: Commons.Appearance.colors.subtext1
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            font.family: Commons.Appearance.font.family
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: "󰤭"
                                            color: Commons.Appearance.colors.overlay0
                                            font.pixelSize: 12; font.family: Commons.Appearance.font.family
                                        }
                                    }

                                    MouseArea {
                                        id: linkMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { runner.cmd = modelData.cmd; runner.running = true }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 6; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        color: Commons.Appearance.colors.overlay0
        font.pixelSize: 10
        font.family: Commons.Appearance.font.family
        font.weight: Font.Medium
        font.letterSpacing: 1.5
    }
}
