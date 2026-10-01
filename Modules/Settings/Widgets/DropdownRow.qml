import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "../../../Commons" as Commons
import "../../../Commons/Primitives"

// Settings row with a pick-one-of-many list (for choices too long for a
// SegmentedControl, e.g. display resolutions). The closed field is a GlassButton
// (same surface, border, hover and press as every other control) with the
// current value and a chevron; the open list is a glass card with an e3 shadow,
// hover wash and the current value marked in the accent. Same API as before.
Item {
    id: root
    property string label: ""
    property string description: ""
    property var options: []    // list of { value: string, label: string }
    property string currentValue: ""
    property real fieldWidth: 220
    signal selected(string value)

    // Same row rhythm as ToggleRow (44, or 56 with a description) so stacked
    // pickers never touch (two 30 px fields used to sit flush and overlap).
    implicitHeight: Math.max(description ? 56 : 44, _text.implicitHeight + 2 * Commons.Appearance.spacing.s2)
    Layout.fillWidth: true

    // Close when the surrounding Settings Flickable scrolls: the open list
    // follows the field and would drift off it.
    property var _flick: {
        for (var p = root.parent; p; p = p.parent) if (p.contentY !== undefined) return p
        return null
    }
    // Only a user scroll (the Flickable moving), not a bounds clamp when the
    // content grows or shrinks.
    Connections {
        target: root._flick
        ignoreUnknownSignals: true
        function onMovementStarted() { list.close() }
        function onFlickStarted() { list.close() }
    }

    readonly property string _currentLabel: {
        for (var i = 0; i < root.options.length; i++)
            if (root.options[i].value === root.currentValue) return root.options[i].label
        return root.options.length ? root.options[0].label : ""
    }

    RowLayout {
        anchors.fill: parent
        spacing: Commons.Appearance.spacing.s4

        ColumnLayout {
            id: _text
            Layout.fillWidth: true
            // Takes all the slack, so the field sits at the row's right edge like
            // ToggleRow's switch, aligned across rows whatever the label length.
            Layout.preferredWidth: 0
            spacing: 2
            Text {
                // fillWidth here too: a ColumnLayout cannot grow past its
                // children's maximum width, so without it the slack went to the
                // right of the field and fields misaligned across rows.
                Layout.fillWidth: true
                text: root.label
                color: Commons.Appearance.colors.textPrimary
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
            }
            Text {
                visible: root.description !== ""
                Layout.fillWidth: true
                text: root.description
                color: Commons.Appearance.colors.textMuted
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
                wrapMode: Text.WordWrap
            }
        }

        GlassButton {
            id: field
            Layout.preferredWidth: root.fieldWidth
            active: false
            enabled: root.enabled
            opacity: root.enabled ? 1 : Commons.Appearance.opacity.divider
            activeFocusOnTab: true
            onClicked: list.opened ? list.close() : list.open()
            Keys.onReturnPressed: list.open()
            Keys.onSpacePressed: list.open()
            // Focus ring (keyboard navigation).
            Rectangle {
                parent: field
                anchors.fill: parent
                anchors.margins: -2
                radius: Commons.Appearance.radius.base + 2
                color: "transparent"
                border.width: 2
                border.color: Commons.Appearance.colors.accentBorder
                visible: field.activeFocus
            }

            Item {
                width: field.width - 2 * field.hpad
                height: field.height
                Text {
                    anchors { left: parent.left; right: chevron.left; rightMargin: Commons.Appearance.spacing.s2; verticalCenter: parent.verticalCenter }
                    text: root._currentLabel
                    color: Commons.Appearance.colors.textPrimary
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                    elide: Text.ElideRight
                }
                Text {
                    id: chevron
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: list.opened ? "󰅃" : "󰅀"
                    color: Commons.Appearance.colors.textMuted
                    font.pixelSize: Commons.Appearance.font.sizeBase
                    font.family: Commons.Appearance.font.family
                }
            }

            Popup {
                id: list
                // As a GlassButton child it lives in the content row, which is inset
                // hpad px from the field's left edge: shift back to the field edge.
                x: -field.hpad
                y: field.height + Commons.Appearance.spacing.s1
                width: field.width
                padding: Commons.Appearance.spacing.s1
                implicitHeight: Math.min(view.contentHeight + 2 * padding, 260)
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                // Open on the current value, keyboard-ready.
                onAboutToShow: {
                    view.currentIndex = Math.max(0, root.options.findIndex(o => o.value === root.currentValue))
                    view.positionViewAtIndex(view.currentIndex, ListView.Center)
                    view.forceActiveFocus()
                }
                onClosed: field.forceActiveFocus()

                background: Item {
                    RectangularShadow {
                        anchors.fill: card
                        radius: card.radius
                        blur:   Commons.Appearance.elevation.e3.blur
                        offset: Qt.vector2d(0, Commons.Appearance.elevation.e3.y)
                        spread: Commons.Appearance.elevation.e3.spread
                        color:  Commons.Appearance.elevation.e3.color
                    }
                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: Commons.Appearance.radius.base
                        color: Commons.Appearance.colors.glassBg
                        border.width: 1
                        border.color: Commons.Appearance.colors.glassBorder
                    }
                }

                contentItem: ListView {
                    id: view
                    clip: true
                    model: root.options
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollIndicator.vertical: ScrollIndicator {}
                    keyNavigationEnabled: true
                    Keys.onReturnPressed: { if (currentIndex >= 0) { root.selected(root.options[currentIndex].value); list.close() } }
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool _cur: modelData.value === root.currentValue
                        width: view.width
                        height: 28
                        radius: Commons.Appearance.radius.sm
                        required property int index
                        color: (rowArea.containsMouse || view.currentIndex === index) ? Commons.Appearance.colors.stateHover : "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s2; right: check.left; verticalCenter: parent.verticalCenter }
                            text: row.modelData.label
                            color: row._cur ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textPrimary
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                            font.weight: row._cur ? Commons.Appearance.font.weightMedium : Commons.Appearance.font.weightRegular
                            elide: Text.ElideRight
                        }
                        Text {
                            id: check
                            anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s2; verticalCenter: parent.verticalCenter }
                            text: row._cur ? "󰄬" : ""
                            color: Commons.Appearance.colors.accent
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.selected(row.modelData.value); list.close() }
                        }
                    }
                }
            }
        }
    }
}
