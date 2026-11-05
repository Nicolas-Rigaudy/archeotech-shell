import QtQuick
import QtQuick.Layouts
import ".." as Commons

// Card section header: the title + divider at the top of a card (DashCard).
// Base look = accent display-face title over a Prim.Divider. A pack can restyle
// it with a `CardHeader` style delegate (adr_027 Layer C, item_156): an index
// code, a ruled label strip, a bracketed tab. The delegate sets its own
// implicitHeight; the host sizes to it. Nothing changes without a delegate.
Item {
    id: hdr
    property string title: ""
    // Optional short code a pack may print beside the title ("01", "NET").
    property string code: ""

    implicitWidth:  style.active ? style.item.implicitWidth : base.implicitWidth
    implicitHeight: style.active ? style.item.implicitHeight : base.implicitHeight

    ColumnLayout {
        id: base
        visible: !style.active
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Commons.Appearance.spacing.s2

        Text {
            text: hdr.title
            color: Commons.Appearance.colors.accent
            // Display face for section headers (Cinzel under a grimdark pack; falls
            // back to the body family when the pack ships none).
            font.family: Commons.Appearance.font.display
            font.pixelSize: Commons.Appearance.font.sizeMd
            font.letterSpacing: Commons.Appearance.font.trackingLabel
        }
        Divider {
            Layout.fillWidth: true
        }
    }

    StyleDelegate {
        id: style
        anchors.fill: parent
        componentId: "CardHeader"
        api: ({
            "title": hdr.title,
            "code":  hdr.code,
            "font": {
                "display":  Commons.Appearance.font.display,
                "size":     Commons.Appearance.font.sizeMd,
                "tracking": Commons.Appearance.font.trackingLabel
            },
            "palette": Commons.Appearance.colors
        })
    }
}
