import QtQuick

// Shadow Spears style delegate for GlassButton (adr_027 Layer C).
//
// Cyber-monastic dataslate button: flat, sharp-cornered, thin mauve frame with a
// gothic top rule line (a header-bar hint) — no gloss, no shadow. Chrome only;
// the base component keeps the label, interaction and press-scale. Reads the
// versioned `api` (docs/STYLE_API.md); no Commons import (pack files live outside
// the shell tree) — colours arrive via api.colors.
Item {
    id: root
    property var api: ({})

    readonly property var  _c: api.colors || ({})
    readonly property bool _active: !!api.active
    readonly property color _accent: _c.accent || "#c6a0f6"

    Rectangle {
        anchors.fill: parent
        radius: 0                                   // dataslate = sharp
        antialiasing: true
        color: root._active ? Qt.rgba(Qt.color(root._accent).r, Qt.color(root._accent).g, Qt.color(root._accent).b, 0.16)
                            : "transparent"
        border.width: 1
        border.color: root._active ? root._accent : (root._c.border || "#363a4f")
        Behavior on border.color { ColorAnimation { duration: 160 } }

        // Gothic top rule — a thin accent bar across the top edge (reads as a
        // dataslate header / rank stripe). Full-width when active, inset when not.
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root._active ? parent.width : parent.width - 12
            height: 2
            color: root._accent
            opacity: root._active ? 1.0 : 0.55
            Behavior on width   { NumberAnimation { duration: 160 } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }
}
