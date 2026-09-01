import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Commons/Primitives"

Item {
    id: root
    property int activeIndex: 0
    signal paneSelected(int index)

    // Settings search (Sprint 24) — non-empty query swaps the nav list for a
    // ranked results list; picking a result jumps to that pane.
    property string query: ""
    readonly property var _results: query !== "" ? PaneRegistry.search(query) : []

    function _go(paneId) {
        var idx = PaneRegistry.indexFor(paneId)
        root.activeIndex = idx
        root.paneSelected(idx)
        root.query = ""
    }

    Rectangle {
        anchors.fill: parent
        // Chrome — stays part of the shared panel glass (was opaque mantle,
        // which broke the translucent cohesion with the rest of the shell).
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item { implicitHeight: 12; Layout.fillWidth: true }

            // ── Search field ──────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 42

                Rectangle {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    radius: Commons.Appearance.radius.base
                    // Nested input card — matches the launcher search field.
                    color: Commons.Appearance.colors.surfaceCard
                    border.color: searchField.activeFocus
                        ? Commons.Appearance.colors.accent : Commons.Appearance.colors.glassBorder
                    border.width: searchField.activeFocus ? 2 : 1
                    Behavior on border.color { Commons.ColorAnim {} }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                        spacing: 6

                        Text {
                            text: "󰍉"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: 13; font.family: Commons.Appearance.font.family
                        }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            text: root.query
                            onTextChanged: root.query = text
                            placeholderText: "Search settings…"
                            color: Commons.Appearance.colors.text
                            placeholderTextColor: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                            background: null
                            Keys.onEscapePressed: root.query = ""
                            onAccepted: if (root._results.length > 0) root._go(root._results[0].pane)
                        }
                        Text {
                            visible: root.query !== ""
                            text: "✕"
                            color: clearMa.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                            font.pixelSize: 12; font.family: Commons.Appearance.font.family
                            MouseArea {
                                id: clearMa; anchors.fill: parent; anchors.margins: -4
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.query = ""
                            }
                        }
                    }
                }
            }

            Item { implicitHeight: 4; Layout.fillWidth: true }

            // ── Search results (shown while querying) ─────────────────────────
            Text {
                visible: root.query !== "" && root._results.length === 0
                text: "No matches"
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
                Layout.leftMargin: 20; Layout.topMargin: 6
            }

            Repeater {
                model: root._results
                delegate: Item {
                    id: resItem
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 40

                    Rectangle {
                        id: resBg
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        radius: Commons.Appearance.radius.base
                        color: "transparent"

                        StateLayer {
                            anchors.fill: parent
                            pressScale: 1.0
                            onClicked: root._go(resItem.modelData.pane)
                        }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                        spacing: 10
                        Text {
                            text: resItem.modelData.paneIcon
                            color: Commons.Appearance.colors.subtext0
                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                            Layout.alignment: Qt.AlignVCenter
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: resItem.modelData.label
                                color: Commons.Appearance.colors.text
                                font.pixelSize: Commons.Appearance.font.sizeSm
                                font.family: Commons.Appearance.font.family
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: resItem.modelData.paneLabel
                                color: Commons.Appearance.colors.overlay0
                                font.pixelSize: Commons.Appearance.font.sizeSm - 1
                                font.family: Commons.Appearance.font.family
                            }
                        }
                    }
                }
            }

            // ── Nav items (hidden while searching) ─────────────────────────────
            Repeater {
                model: root.query === "" ? PaneRegistry.panes : []
                delegate: Item {
                    id: navItem
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 44

                    // Raised selected pill: solid accent-tinted surface + soft shadow
                    // (shadowStrength-gated) so the active row lifts instead of a flat tint.
                    RectangularShadow {
                        anchors.fill: activeBg; radius: activeBg.radius
                        blur: 10; offset: Qt.vector2d(0, 2); spread: 0
                        color: Qt.rgba(0, 0, 0, 0.33 * Commons.Appearance.shadowStrength)
                        opacity: root.activeIndex === navItem.index ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                    Rectangle {
                        id: activeBg
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        radius: Commons.Appearance.radius.base
                        // One surface-based progression (coherent with the raised-key
                        // language): resting → subtle neutral pill on hover → raised
                        // warm pill (+ the shadow above) on active. No separate accent
                        // wash — StateLayer here is click + (disabled) tint only.
                        color: root.activeIndex === navItem.index ? Commons.Appearance.colors.surfaceWarm
                             : navSL.hovered                       ? Commons.Appearance.colors.surface0Alpha
                             :                                       "transparent"
                        Behavior on color { Commons.ColorAnim {} }

                        StateLayer {
                            id: navSL
                            anchors.fill: parent
                            tint: "transparent"; pressTint: "transparent"
                            pressScale: 1.0
                            onClicked: {
                                root.activeIndex = navItem.index
                                root.paneSelected(navItem.index)
                            }
                        }
                    }

                    // Left accent bar for active state
                    Rectangle {
                        visible: root.activeIndex === navItem.index
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 3; height: 20; radius: 2
                        // Active pane marker = accent (register metal); teal dropped (too modern).
                        color: Commons.Appearance.colors.accent
                        Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                        spacing: 12

                        Text {
                            text: navItem.modelData.icon
                            color: root.activeIndex === navItem.index
                                ? Commons.Appearance.colors.accent
                                : Commons.Appearance.colors.subtext0
                            font.pixelSize: 16
                            font.family: Commons.Appearance.font.family
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        }

                        Text {
                            text: navItem.modelData.label
                            color: root.activeIndex === navItem.index
                                ? Commons.Appearance.colors.text
                                : Commons.Appearance.colors.subtext0
                            font.pixelSize: Commons.Appearance.font.sizeMd
                            font.family: Commons.Appearance.font.display   // page names in the display face
                            font.weight: root.activeIndex === navItem.index ? Font.Medium : Font.Normal
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true }
        }

        // Wheel scroll
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (wheel.angleDelta.y < 0)
                    root.activeIndex = Math.min(root.activeIndex + 1, PaneRegistry.panes.length - 1)
                else
                    root.activeIndex = Math.max(root.activeIndex - 1, 0)
            }
        }
    }
}
