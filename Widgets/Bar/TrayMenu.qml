import QtQuick
import Quickshell
import "../../Commons" as Commons
import "../../Commons/Primitives"

// Glass tray context menu (item_039): the app's DBusMenu drawn with the shell's own
// card material instead of the platform QMenu. Entries follow the menu protocol:
// separators, disabled rows, check and radio marks, icons, and submenus, which
// expand in place under their row. Pick an entry or click away (the popup grabs
// focus) to close; Esc closes too.
//
//   TrayMenu { id: m }   m.anchor.item = icon; m.menuHandle = item.menu; m.visible = true
PopupWindow {
    id: pop

    // The item's QsMenuHandle (SystemTrayItem.menu).
    property var menuHandle: null

    // Ask for the menu; it appears once its entries have arrived over DBus, so
    // the window is created at its final size (it cannot grow afterwards).
    property bool wanted: false
    visible: wanted && list.rowCount > 0
    onVisibleChanged: if (!visible) wanted = false

    // Room around the card for its drop shadow; none under layer blur, where the
    // window hugs the card (same rule as the toast window).
    readonly property int _pad: Commons.Appearance.outerShadows ? 16 : 0
    readonly property int _minWidth: 188

    grabFocus: true
    color: "transparent"
    implicitWidth:  Math.max(_minWidth, list.naturalWidth) + 2 * _pad + 2 * card.inset
    implicitHeight: list.implicitHeight + 2 * _pad + 2 * card.inset

    Item {
        anchors.fill: parent
        focus: pop.visible
        Keys.onEscapePressed: pop.wanted = false

        Item {
            id: card
            readonly property int inset: 4
            x: pop._pad; y: pop._pad
            width: parent.width - 2 * pop._pad
            height: parent.height - 2 * pop._pad

            GlassShadow {
                anchors.fill: surface
                radius: surface.radius
                blur:   Commons.Appearance.elevation.e3.blur
                offset: Qt.vector2d(0, Commons.Appearance.elevation.e3.y)
                spread: Commons.Appearance.elevation.e3.spread
                color:  Commons.Appearance.outerShadowColor(Commons.Appearance.elevation.e3)
            }
            MetalSurface {
                id: surface
                anchors.fill: parent
                radius: Commons.Appearance.radius.md
                chamfer: 4
                crisp: Commons.Appearance.crispEdges
            }
            Rectangle {                             // glass rim (the plated look draws its own seat)
                anchors.fill: parent
                visible: !Commons.Appearance.platedChrome
                radius: surface.radius
                antialiasing: !Commons.Appearance.crispEdges
                color: "transparent"
                border.width: 1
                border.color: Commons.Appearance.colors.glassBorder
            }

            TrayMenuList {
                id: list
                x: card.inset; y: card.inset
                width: card.width - 2 * card.inset
                handle: pop.menuHandle
                onPicked: pop.wanted = false
            }
        }
    }
}
