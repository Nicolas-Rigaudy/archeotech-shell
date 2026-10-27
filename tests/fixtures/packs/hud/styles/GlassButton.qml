import QtQuick

// HUD pack style delegate for GlassButton (adr_027 Layer C).
//
// Chrome-only visual override: a flat, sharp-cornered dataslate button with a
// thin accent frame and corner ticks — no shadow, no gloss. Reads the versioned
// `api` (see docs/STYLE_API.md); does NOT import Commons (pack files live outside
// the shell tree) — all theme colours arrive via api.colors. The base component
// keeps the label, content slot, interaction and press-scale.
Item {
    id: root
    property var api: ({})

    readonly property var _c: api.colors || ({})
    readonly property bool _active: !!api.active

    Rectangle {
        anchors.fill: parent
        color: root._active ? Qt.rgba(Qt.color(root._c.accent).r, Qt.color(root._c.accent).g, Qt.color(root._c.accent).b, 0.18)
                            : "transparent"
        border.width: root._active ? 2 : 1
        border.color: root._active ? (root._c.accent || "#7dc4e4") : (root._c.border || "#363a4f")
        radius: 0                      // dataslate = sharp
        antialiasing: true
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    // Corner ticks — short accent marks at each corner, the HUD signature.
    Repeater {
        model: [ { l: true, t: true }, { l: false, t: true }, { l: false, t: false }, { l: true, t: false } ]
        delegate: Item {
            Rectangle {   // horizontal tick
                color: root._c.accent || "#7dc4e4"
                width: 6; height: 2
                x: modelData.l ? 0 : root.width - width
                y: modelData.t ? 0 : root.height - height
            }
            Rectangle {   // vertical tick
                color: root._c.accent || "#7dc4e4"
                width: 2; height: 6
                x: modelData.l ? 0 : root.width - width
                y: modelData.t ? 0 : root.height - height
            }
        }
    }
}
