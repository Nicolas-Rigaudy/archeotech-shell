import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../Widgets"

Item {
    id: root

    Commons.CommandRunner { id: runner }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰅺"
            title: "About"
            description: "Shell version, compositor info, and quick links"
        }

        Divider { }   // frame separator under the pane header

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
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Commons.Appearance.spacing.s6; leftMargin: Commons.Appearance.spacing.s6; rightMargin: Commons.Appearance.spacing.s6 }
                width: root.width - 48
                spacing: Commons.Appearance.spacing.s2

                // ── Hero ──────────────────────────────────────────────────────
                SettingsCard {
                    Item { implicitHeight: Commons.Appearance.spacing.s4; Layout.fillWidth: true }

                    Text {
                        text: "󰒓"
                        color: Commons.Appearance.colors.accent
                        font.pixelSize: Commons.Appearance.font.size7xl
                        font.family: Commons.Appearance.font.family
                    }

                    Text {
                        text: "Archeotech Shell"
                        color: Commons.Appearance.colors.textPrimary
                        font.pixelSize: Commons.Appearance.font.sizeHeadline
                        font.family: Commons.Appearance.font.family
                        font.weight: Commons.Appearance.font.weightBold
                    }

                    Text {
                        text: "Quickshell-based Wayland shell for MangoWC"
                        color: Commons.Appearance.colors.textSecondary
                        font.pixelSize: Commons.Appearance.font.sizeBase
                        font.family: Commons.Appearance.font.family
                    }

                    Text {
                        text: "Catppuccin Macchiato  ·  FiraCode Nerd Font"
                        color: Commons.Appearance.colors.textMuted
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                    }

                    Item { implicitHeight: Commons.Appearance.spacing.s4; Layout.fillWidth: true }
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
                SectionLabel { text: "ENVIRONMENT"; SearchTarget { key: "about.environment"; target: envCard } }

                SettingsCard {
                    id: envCard
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

                                Divider {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                }

                                RowLayout {
                                    anchors { fill: parent; topMargin: index > 0 ? 1 : 0 }

                                    Text {
                                        text: modelData.label
                                        color: Commons.Appearance.colors.textMuted
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                        font.family: Commons.Appearance.font.family
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: modelData.value
                                        color: Commons.Appearance.colors.textSecondary
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                        font.family: Commons.Appearance.font.family
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                }

                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true }
                SectionLabel { text: "LINKS" }

                SettingsCard {
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

                                Divider {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                }

                                Rectangle {
                                    anchors { fill: parent; topMargin: index > 0 ? 1 : 0 }
                                    color: "transparent"
                                    radius: Commons.Appearance.radius.sm

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: Commons.Appearance.spacing.s2; rightMargin: Commons.Appearance.spacing.s2 }
                                        spacing: Commons.Appearance.spacing.s3

                                        Text {
                                            text: modelData.icon
                                            color: Commons.Appearance.colors.textMuted
                                            font.pixelSize: Commons.Appearance.font.sizeXl; font.family: Commons.Appearance.font.family
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Text {
                                            text: modelData.label
                                            color: Commons.Appearance.colors.textSecondary
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            font.family: Commons.Appearance.font.family
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: "󰏌"
                                            color: Commons.Appearance.colors.textMuted
                                            font.pixelSize: Commons.Appearance.font.sizeBase; font.family: Commons.Appearance.font.family
                                        }
                                    }

                                    StateLayer {
                                        anchors.fill: parent
                                        onClicked: runner.runShell(modelData.cmd)
                                    }
                                }
                            }
                        }
                }
            }
        }
    }
}
