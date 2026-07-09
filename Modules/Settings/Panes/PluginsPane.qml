import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../../../Services/Shell" as ShellServices
import "../Widgets"

// Sprint 26 — Plugin / Widget Manager.
//   • Installed modules: enable/disable, verified badge, uninstall (user dir
//     only — bundled repo modules are stow-managed, not deletable here).
//   • Built-in widgets: read-only catalogue; a "configurable" tag marks the
//     ones with a configSchema. Per-instance config is edited in Edit Layout
//     (the gear on each placed widget) — there is no global-default layer.
Item {
    id: root
    readonly property var _reg:  ShellServices.WidgetRegistry
    readonly property var _mods: ShellServices.ModuleRegistry

    // rm -rf the module folder, then rescan. Guarded to user-dir modules.
    Process {
        id: uninstaller
        property string dir: ""
        command: ["rm", "-rf", dir]
        running: false
        onExited: root._mods.rescan()
    }
    function _isUserModule(dir) { return !!dir && dir.indexOf("/.local/share/") !== -1 }
    function _uninstall(dir) {
        if (!root._isUserModule(dir)) return
        uninstaller.dir = dir
        uninstaller.running = true
    }
    function _hasSchema(m) { return !!m && !!m.configSchema && Object.keys(m.configSchema).length > 0 }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰏗"
            title: "Plugins"
            description: "Installed modules and the built-in widget catalogue"
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
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: col
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 24; leftMargin: 24; rightMargin: 24 }
                width: root.width - 48
                spacing: 8

                // ── Installed modules ────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { text: "INSTALLED MODULES"; Layout.fillWidth: true }
                    Text {
                        text: "󰑐  Rescan"
                        color: _rescanMa.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext0
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        MouseArea {
                            id: _rescanMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._mods.rescan()
                        }
                    }
                }

                EmptyState {
                    Layout.fillWidth: true
                    visible: root._mods.modules.length === 0
                    icon: "󰏗"
                    title: "No modules installed"
                    hint: "Drop a module folder into ~/.local/share/archeotech/modules/, then Rescan."
                }

                Repeater {
                    model: root._mods.modules
                    delegate: Rectangle {
                        id: modCard
                        required property var modelData
                        readonly property bool _enabled: root._mods.isEnabled(modelData.id)
                        property bool _confirming: false

                        Layout.fillWidth: true
                        implicitHeight: mc.implicitHeight + 20
                        radius: Commons.Appearance.radius.md
                        color: Commons.Appearance.colors.surface0
                        opacity: _enabled ? 1.0 : 0.6

                        ColumnLayout {
                            id: mc
                            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 10 }
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: modCard.modelData.icon || "󰏗"
                                    color: Commons.Appearance.colors.accent
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeLg
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: modCard.modelData.name || modCard.modelData.id
                                            color: Commons.Appearance.colors.text
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            font.bold: true
                                        }
                                        // Verified badge (honored, not cryptographically checked — S27).
                                        Rectangle {
                                            visible: modCard.modelData.verified === true
                                            height: 16; width: _vt.implicitWidth + 12
                                            radius: Commons.Appearance.radius.sm
                                            color: Commons.Appearance.colors.accentAlpha
                                            Text {
                                                id: _vt
                                                anchors.centerIn: parent
                                                text: "󰄬 Verified"
                                                color: Commons.Appearance.colors.accent
                                                font.family: Commons.Appearance.font.family
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                            }
                                        }
                                    }
                                    Text {
                                        text: (modCard.modelData.author || "unknown")
                                              + (modCard.modelData.version ? "  ·  v" + modCard.modelData.version : "")
                                              + "  ·  " + (modCard.modelData.canLiveIn || []).join(", ")
                                        color: Commons.Appearance.colors.overlay0
                                        font.family: Commons.Appearance.font.family
                                        font.pixelSize: Commons.Appearance.font.sizeSm
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                ToggleSwitch {
                                    checked: modCard._enabled
                                    onToggled: state => root._mods.setEnabled(modCard.modelData.id, state)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: root._hasSchema(modCard.modelData) || root._isUserModule(modCard.modelData.dir)

                                Text {
                                    visible: root._hasSchema(modCard.modelData)
                                    text: "󰒓  Configurable — set per-instance in Edit Layout"
                                    color: Commons.Appearance.colors.subtext0
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    Layout.fillWidth: true
                                }
                                Item { Layout.fillWidth: true; visible: !root._hasSchema(modCard.modelData) }

                                // Uninstall (user-dir modules only) — two-click confirm.
                                Text {
                                    visible: root._isUserModule(modCard.modelData.dir)
                                    text: modCard._confirming ? "Confirm delete?" : "󰩺  Uninstall"
                                    color: modCard._confirming ? Commons.Appearance.colors.red : Commons.Appearance.colors.subtext0
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modCard._confirming) {
                                                root._uninstall(modCard.modelData.dir)
                                                modCard._confirming = false
                                            } else {
                                                modCard._confirming = true
                                                _confirmReset.restart()
                                            }
                                        }
                                    }
                                    Timer { id: _confirmReset; interval: 3000; onTriggered: modCard._confirming = false }
                                }
                            }
                        }
                    }
                }

                Item { implicitHeight: 8; Layout.fillWidth: true }

                // ── Built-in widgets catalogue ───────────────────────────────────
                SectionLabel { text: "BUILT-IN WIDGETS" }
                Text {
                    Layout.fillWidth: true
                    text: "Placed and configured from Edit Layout. 󰒓 marks a widget with per-instance options."
                    color: Commons.Appearance.colors.overlay0
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    wrapMode: Text.WordWrap
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root._reg.availableBarWidgets.concat(root._reg.availableStripIcons)
                        delegate: Rectangle {
                            id: catTag
                            required property var modelData
                            readonly property bool _cfg: Object.keys(root._reg.configSchemaFor(modelData.id)).length > 0
                            height: 28
                            width: _bt.implicitWidth + 20
                            radius: Commons.Appearance.radius.base
                            color: Commons.Appearance.colors.surface0
                            border.width: 1
                            border.color: Commons.Appearance.colors.surface1
                            Row {
                                id: _bt
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon || ""
                                    color: Commons.Appearance.colors.accent
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: catTag.modelData.name + (catTag._cfg ? "  󰒓" : "")
                                    color: Commons.Appearance.colors.subtext1
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                }
                            }
                        }
                    }
                }

                Item { implicitHeight: 12; Layout.fillWidth: true }
            }
        }
    }
}
