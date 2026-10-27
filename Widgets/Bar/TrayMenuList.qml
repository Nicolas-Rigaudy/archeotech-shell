import QtQuick
import Quickshell
import "../../Commons" as Commons
import "../../Commons/Primitives"

// One level of a tray DBusMenu (item_039), drawn for TrayMenu. A submenu entry
// expands in place into another TrayMenuList (this component, via a Loader), so
// the menu stays one window. `picked` bubbles up so the popup can close.
Column {
    id: col

    // A QsMenuHandle: the item's menu, or a QsMenuEntry that has children.
    property var handle: null
    property int depth: 0
    signal picked()

    // Widest row (submenus included), independent of this column's own width, so
    // the popup can size itself to it without a width <-> implicitWidth loop.
    readonly property real naturalWidth: {
        var w = 0
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i)
            if (it) w = Math.max(w, it.naturalWidth)
        }
        return w
    }

    // Entries loaded so far (the menu arrives over DBus after `handle` is set).
    readonly property int rowCount: rep.count

    spacing: 1

    // Entry label without DBusMenu mnemonic underscores ("_File" -> "File").
    function plain(t) { return (t || "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_") }

    // Entry icon as an Image source ("" = none).
    function iconSource(name) {
        if (!name) return ""
        if (name.indexOf("/") === 0 || name.indexOf("image://") === 0 || name.indexOf("file:") === 0) return name
        return Quickshell.iconPath(name, true)   // "" when the theme has no such icon
    }

    QsMenuOpener { id: opener; menu: col.handle }

    Repeater {
        id: rep
        model: opener.children
        delegate: Column {
            id: entryCol
            required property var modelData
            readonly property bool _sep: modelData.isSeparator
            readonly property bool _sub: modelData.hasChildren
            property bool _open: false
            readonly property real naturalWidth: Math.max(row.implicitWidth, sub.item ? sub.item.naturalWidth : 0)
            width: col.width
            spacing: 1

            Rectangle {                         // separator
                visible: entryCol._sep
                width: parent.width - Commons.Appearance.spacing.s3 * 2
                x: Commons.Appearance.spacing.s3
                height: entryCol._sep ? 1 : 0
                color: Commons.Appearance.colors.glassBorder
            }

            Item {                              // one row
                id: row
                visible: !entryCol._sep
                width: parent.width
                height: entryCol._sep ? 0 : 28
                implicitWidth: rowContent.implicitWidth + Commons.Appearance.spacing.s3 * 2
                                + col.depth * Commons.Appearance.spacing.s4
                                + (entryCol._sub ? Commons.Appearance.spacing.s5 : 0)
                opacity: entryCol.modelData.enabled ? 1.0 : Commons.Appearance.disabledOpacity

                Rectangle {                     // hover wash + press
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.sm
                    color: "transparent"
                    StateLayer {
                        anchors.fill: parent
                        interactive: entryCol.modelData.enabled
                        pressScale: 1.0
                        onClicked: {
                            if (entryCol._sub) { entryCol._open = !entryCol._open; return }
                            entryCol.modelData.triggered()
                            col.picked()
                        }
                    }
                }

                Row {
                    id: rowContent
                    anchors.verticalCenter: parent.verticalCenter
                    x: Commons.Appearance.spacing.s3 + col.depth * Commons.Appearance.spacing.s4
                    spacing: Commons.Appearance.spacing.s2

                    Item {                      // check / radio mark
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entryCol.modelData.buttonType !== QsMenuButtonType.None
                        Text {
                            anchors.centerIn: parent
                            visible: entryCol.modelData.checkState === Qt.Checked
                            text: entryCol.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : ""
                            color: Commons.Appearance.colors.accent
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                        }
                    }
                    Image {                     // entry icon
                        width: 16; height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: col.iconSource(entryCol.modelData.icon)
                        sourceSize.width: 32; sourceSize.height: 32
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: col.plain(entryCol.modelData.text)
                        color: Commons.Appearance.colors.textPrimary
                        font.pixelSize: Commons.Appearance.font.sizeBase
                        font.family: Commons.Appearance.font.family
                    }
                }
                Text {                          // submenu chevron
                    visible: entryCol._sub
                    anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s3; verticalCenter: parent.verticalCenter }
                    text: entryCol._open ? "" : ""
                    color: Commons.Appearance.colors.textMuted
                    font.pixelSize: Commons.Appearance.font.size2xs
                    font.family: Commons.Appearance.font.family
                }
            }

            // Submenu, expanded in place. By URL, not sourceComponent: QML refuses a
            // component that instantiates itself statically.
            Loader {
                id: sub
                active: entryCol._sub && entryCol._open
                width: parent.width
                source: "TrayMenuList.qml"
                Binding { target: sub.item; property: "handle"; value: entryCol.modelData; when: sub.item !== null }
                Binding { target: sub.item; property: "depth";  value: col.depth + 1;      when: sub.item !== null }
                Binding { target: sub.item; property: "width";  value: entryCol.width;     when: sub.item !== null }
                Connections { target: sub.item; ignoreUnknownSignals: true; function onPicked() { col.picked() } }
            }
        }
    }
}
