import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../Commons" as Commons

// System tray — a StatusNotifierItem host. Quickshell's SystemTray service IS
// the SNI host, so any app that publishes a tray icon the standard freedesktop
// way (Discord, Steam, KeePassXC, nm-applet, the cdx widget, …) shows up here
// automatically — no per-app wiring. One icon per registered item:
//   left-click   → activate (primary action); opens the menu if the item is menu-only
//   middle-click → secondary action
//   right-click  → the app's own context menu (DBusMenu, anchored to the icon)
//   scroll       → forwarded to the item (e.g. volume applets)
// Row on a horizontal bar, column on a vertical one — icons are square, so no
// rotation concern. Collapses to nothing when the tray is empty (no bar gap).
Item {
    id: root
    required property var holderRoot
    property string widgetId

    readonly property bool _horizontal: holderRoot && holderRoot.horizontal
    readonly property bool _empty: SystemTray.items.values.length === 0
    // Hidden on a clean bar when the tray is empty (waybar-style — no dead gap),
    // but shown with a placeholder while editing so it can still be seen/moved.
    visible: holderRoot && (!_empty || Commons.State.editMode)
    implicitWidth:  _empty ? 26 : grid.implicitWidth
    implicitHeight: _empty ? 26 : grid.implicitHeight
    Layout.alignment: _horizontal ? Qt.AlignVCenter : Qt.AlignHCenter

    // Edit-mode placeholder: a faint tray glyph so the (empty) widget has a
    // grabbable footprint in the builder. Real icons replace it once apps register.
    Text {
        visible: root._empty
        anchors.centerIn: parent
        text: "󰀻"
        color: Commons.Appearance.colors.overlay0
        font.pixelSize: 16
        font.family: Commons.Appearance.font.family
    }

    // One reused anchor — only one context menu is ever open at a time. Menu
    // drops off the bar edge: below a top/bottom bar, beside a side strip.
    QsMenuAnchor {
        id: trayMenu
        anchor.edges: root._horizontal ? Edges.Bottom
                    : (root.holderRoot && root.holderRoot.side === "right" ? Edges.Left : Edges.Right)
    }
    function _openMenu(cell) {
        if (!cell.modelData.hasMenu) return
        trayMenu.menu = cell.modelData.menu
        trayMenu.anchor.item = cell
        trayMenu.open()
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        rows:    root._horizontal ? 1 : -1   // -1 = auto (single row / single column)
        columns: root._horizontal ? -1 : 1
        spacing: 4

        Repeater {
            // `.values` (the plain array), not the ObjectModel directly — the
            // Caelestia/documented pattern; the delegate's modelData is then the
            // real SystemTrayItem so activate()/menu/icon all resolve.
            model: SystemTray.items.values
            delegate: Item {
                id: cell
                required property var modelData
                width: 26; height: 26

                // Subtle rounded hover key behind the icon (shell feedback language).
                Rectangle {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.sm
                    color: _ma.containsMouse ? Commons.Appearance.colors.stateHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                }

                // Plain Image — the item's `icon` string is a directly-usable Image
                // source (per the Quickshell docs). Hidden unless it actually loads.
                Image {
                    id: iconImg
                    anchors.centerIn: parent
                    width: 18; height: 18
                    source: cell.modelData.icon
                    sourceSize.width: 36
                    sourceSize.height: 36
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready
                }
                // Fallback when the item ships no resolvable icon (a bare IconName
                // with no installed file / no IconPixmap): a glyph from the item's
                // title initial, so it's never a broken-texture square and stays a
                // clear hover/click target. (The app should ship an IconPixmap.)
                Text {
                    visible: iconImg.status !== Image.Ready
                    anchors.centerIn: parent
                    text: (cell.modelData.title || cell.modelData.id || "󰀻").charAt(0).toUpperCase()
                    color: Commons.Appearance.colors.subtext1
                    font.pixelSize: 13
                    font.family: Commons.Appearance.font.family
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: _ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.MiddleButton) {
                            cell.modelData.secondaryActivate()
                        } else if (event.button === Qt.RightButton) {
                            root._openMenu(cell)
                        } else {
                            // Left-click: open the menu if the item has one (the
                            // common Linux tray convention — most apps' activate()
                            // is a no-op), else fall back to activate().
                            if (cell.modelData.hasMenu) root._openMenu(cell)
                            else cell.modelData.activate()
                        }
                    }
                    onWheel: event => cell.modelData.scroll(event.angleDelta.y, false)
                }
            }
        }
    }
}
