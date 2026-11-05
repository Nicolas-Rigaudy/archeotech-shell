pragma ComponentBehavior: Bound
import QtQuick

// Cyberdeck Netrunner: card title (adr_027 Layer C delegate for CardHeader).
// Bold Rajdhani capitals in the accent, tracked wide, no rule under it.
Item {
    id: hdr
    property var api: ({})
    property string register: ""

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + 6

    Text {
        id: label
        text: hdr.api.title || ""
        color: hdr.api.palette ? hdr.api.palette.accent : "transparent"
        font.family: hdr.api.font ? hdr.api.font.display : ""
        font.pixelSize: 20
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.5
    }
}
