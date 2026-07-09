import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

// Sprint 21 — the click-to-assign palette. Shown by EditOverlay when an "add"
// slot is clicked; lists the assignable widgets/icons as tiles and emits
// picked(id) on selection. Card-modal: a full-surface scrim swallows clicks
// (cancelling), the card itself swallows its own clicks.
Item {
    id: pal
    anchors.fill: parent
    visible: false
    z: 200

    property var    items: []
    property string title: "Add widget"
    signal picked(string id)
    signal cancelled()

    // Scrim / click-outside-to-cancel.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: pal.cancelled()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width:  480
        height: contentCol.implicitHeight + 2 * Commons.Appearance.spacing.xl
        radius: Commons.Appearance.radius.lg
        color:  Commons.Appearance.colors.glassBg
        border.width: 1
        border.color: Commons.Appearance.colors.glassBorder

        // Swallow clicks so they don't fall through to the scrim.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: contentCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                margins: Commons.Appearance.spacing.xl
            }
            spacing: Commons.Appearance.spacing.lg

            Text {
                text: pal.title
                color: Commons.Appearance.colors.text
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.bold: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: Commons.Appearance.spacing.sm

                Repeater {
                    model: pal.items
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        width:  138
                        height: 42
                        radius: Commons.Appearance.radius.md
                        color: _ma.containsMouse ? Commons.Appearance.colors.accentAlpha
                                                 : Commons.Appearance.colors.surface0
                        border.width: 1
                        border.color: _ma.containsMouse ? Commons.Appearance.colors.accentBorder
                                                        : Commons.Appearance.colors.glassBorder

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tile.modelData.icon || ""
                                color: Commons.Appearance.colors.accent
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeIcon
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 78
                                text: tile.modelData.name || tile.modelData.id
                                color: Commons.Appearance.colors.text
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeBase
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: _ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pal.picked(tile.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
