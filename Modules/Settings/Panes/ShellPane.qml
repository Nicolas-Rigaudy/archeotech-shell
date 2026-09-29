import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
import "../../../Services/Persistence" as Persistence
import "../../../Services/Shell" as ShellServices
import "../../../Services/Compositor" as CompositorServices
import "../Widgets"
import "../../Dashboard/panels/SystemNotesLogic.js" as NotesLogic

// Shell pane (Sprint 24) — hub for shell-structure customization: the visual
// builder (edit mode), bar layout, clock, module visibility. Renamed from the
// old "Bar" pane; designed to absorb widget/strip controls as settings grow.
Item {
    id: root

    // Enter the visual builder — close the open panel first so the editor owns
    // the surface (mirrors shell.qml _setEditMode).
    function _enterEditMode() {
        ShellServices.ShellState.closeAllAcross()
        Commons.State.editMode = true
    }

    // Frame sliders write to shell-config (the source the frame reads), but a
    // slider drag fires continuously — debounce so we don't thrash the file /
    // reload on every tick. Live values preview locally; commit on settle.
    property int  _pendingRadius: -1
    property int  _pendingGap:    -1
    Timer {
        id: _radiusTimer; interval: 250
        onTriggered: if (root._pendingRadius >= 0) { ShellServices.ShellConfig.setCornerRadius(root._pendingRadius); root._pendingRadius = -1 }
    }
    Timer {
        id: _gapTimer; interval: 250
        onTriggered: if (root._pendingGap >= 0) { ShellServices.ShellConfig.setOuterGap(root._pendingGap); root._pendingGap = -1 }
    }

    // Scroller proportion: live setProportion is a cheap compositor dispatch, so a
    // short debounce keeps the focused window resizing smoothly under the drag
    // without firing a call on every sub-step. _savedProp tracks whether the
    // current value has been persisted as the new default.
    property real _pendingProp: -1
    property bool _savedProp:   false
    Timer {
        id: _propTimer; interval: 60
        onTriggered: if (root._pendingProp >= 0) {
            CompositorServices.CompositorService.setProportion(root._pendingProp)
            root._pendingProp = -1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰍹"
            title: "Shell"
            description: "Customize the bar, edge strips and widgets — and open the visual builder"
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
                spacing: 6

                // ── Edit layout (visual builder entry) ─────────────────────────
                SectionLabel { text: "CUSTOMIZE" }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64

                    RectangularShadow {
                        anchors.fill: editBg
                        radius: editBg.radius
                        blur: 16; offset: Qt.vector2d(0, 4); spread: 0
                        color: Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
                    }
                    Rectangle {
                        id: editBg
                        anchors.fill: parent
                        radius: Commons.Appearance.radius.md
                        color: Commons.Appearance.colors.surfaceCard

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        Text {
                            text: "󰏬"
                            color: Commons.Appearance.colors.accent
                            font.pixelSize: 24; font.family: Commons.Appearance.font.family
                            Layout.alignment: Qt.AlignVCenter
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            Text {
                                text: "Edit Layout"
                                color: Commons.Appearance.colors.textPrimary
                                font.pixelSize: Commons.Appearance.font.sizeMd
                                font.family: Commons.Appearance.font.family
                                font.weight: Font.Medium
                            }
                            Text {
                                text: "Click-to-assign builder for the bar, strips & widgets  ·  Super+Shift+E"
                                color: Commons.Appearance.colors.textSecondary
                                font.pixelSize: Commons.Appearance.font.sizeSm
                                font.family: Commons.Appearance.font.family
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                        Text {
                            text: "󰅂"
                            color: Commons.Appearance.colors.textMuted
                            font.pixelSize: 18; font.family: Commons.Appearance.font.family
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                        StateLayer {
                            anchors.fill: parent
                            onClicked: root._enterEditMode()
                        }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "FRAME" }

                SettingsCard {
                    ToggleRow {
                        label: "Pill frame"
                        description: "Float the whole frame off the screen edges with rounded outer corners"
                        checked: ShellServices.ShellConfig.pillMode()
                        onToggled: value => ShellServices.ShellConfig.setPillMode(value)
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    SliderRow {
                        label: "Corner Radius"
                        description: "Roundness of the frame's inner corners"
                        from: 0; to: 24; stepSize: 1
                        value: ShellServices.ShellConfig.cornerRadius()
                        format: v => Math.round(v) + "px"
                        onMoved: (v) => { root._pendingRadius = Math.round(v); _radiusTimer.restart() }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }
                    SliderRow {
                        label: "Outer Gap"
                        description: "Breathing space between the shell and tiled windows"
                        from: 0; to: 20; stepSize: 1
                        value: ShellServices.ShellConfig.outerGap()
                        format: v => Math.round(v) + "px"
                        onMoved: (v) => { root._pendingGap = Math.round(v); _gapTimer.restart() }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "SCROLLER" }

                SettingsCard {
                        SliderRow {
                            id: propSlider
                            label: "Window width"
                            description: "Focused window's width; the rest is the side peek"
                            from: 0.8; to: 1.0; stepSize: 0.01
                            value: Persistence.Config.get("scroller.proportion", 0.98)
                            format: v => Math.round(v * 100) + "%"
                            onMoved: (v) => {
                                root._pendingProp = v
                                root._savedProp = false
                                Persistence.Config.set("scroller.proportion", v)
                                _propTimer.restart()
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

                        Item { implicitHeight: 8; Layout.fillWidth: true }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Commons.Appearance.radius.md
                            color: "transparent"
                            border.width: 1
                            border.color: Commons.Appearance.colors.glassBorder

                            RowLayout {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                spacing: 10
                                Text {
                                    text: root._savedProp ? "󰄬" : "󰆓"
                                    color: Commons.Appearance.colors.accent
                                    font.pixelSize: 16; font.family: Commons.Appearance.font.family
                                }
                                Text {
                                    text: root._savedProp ? "Saved as default" : "Save as default"
                                    color: Commons.Appearance.colors.textPrimary
                                    font.pixelSize: Commons.Appearance.font.sizeBase
                                    font.family: Commons.Appearance.font.family
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "new windows, after reload"
                                    color: Commons.Appearance.colors.textMuted
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    font.family: Commons.Appearance.font.family
                                }
                            }
                            StateLayer {
                                anchors.fill: parent
                                onClicked: {
                                    CompositorServices.CompositorService.setDefaultProportion(propSlider.value)
                                    root._savedProp = true
                                }
                            }
                        }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "DASHBOARD · SYSTEM NOTES" }

                // Which stats the dashboard's System Notes card shows. Bound to
                // the real "dashboard.notes" list (unset = all); a stat whose
                // source is missing on this machine is hidden on the card anyway.
                SettingsCard {
                    Repeater {
                        model: NotesLogic.STATS
                        delegate: ColumnLayout {
                            id: statRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0
                            Rectangle {
                                visible: statRow.index > 0
                                Layout.fillWidth: true; Layout.preferredHeight: 1
                                color: Commons.Appearance.colors.surface0
                            }
                            ToggleRow {
                                Layout.fillWidth: true
                                label: statRow.modelData.label
                                description: statRow.modelData.description
                                checked: NotesLogic.isOn(Persistence.Config.get("dashboard.notes", null), statRow.modelData.id)
                                onToggled: value => Persistence.Config.set("dashboard.notes",
                                    NotesLogic.toggle(Persistence.Config.get("dashboard.notes", null), statRow.modelData.id, value))
                            }
                        }
                    }
                }

                SettingsCard {
                    Text {
                        text: "󰋽  Add, remove and arrange widgets in the bar and edge strips from Edit Layout above. Frame changes apply live."
                        color: Commons.Appearance.colors.textMuted
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
