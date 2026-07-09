import QtQuick
import "../../Commons" as Commons
import "../../Services/Compositor" as CompositorServices

// Focused window title with app icon prefix. Hides when nothing focused.
//
// Sizes itself: implicitWidth caps at holderRoot._titleMaxWidth so the left
// cluster (workspaces + title + media) can never slide under the centered
// clock; the inner Text elides when capped. The cap is driven purely by the
// widget's own implicit width — no Layout clamps (those stretched the zone).
Item {
    id: root
    required property var holderRoot
    property string widgetId

    property string raw: CompositorServices.MangoWC.titleFor(holderRoot && holderRoot.screen ? holderRoot.screen.name : "")

    property string display: {
        if (raw.includes("Visual Studio Code")) return "󰨞  " + raw.replace(/ - Visual Studio Code$/, "").replace(/^.*\//, "").trim()
        if (raw.includes("Zen Browser"))        return "󰈹  " + raw.replace(/ — Zen Browser$/, "").replace(/^\(\d+\) /, "")
        if (raw.includes("kitty"))              return "  " + raw.replace(/ - kitty$/, "")
        if (raw.includes("fish"))               return "  " + raw.replace(/ - fish$/, "")
        return raw
    }

    visible: raw.length > 0 && holderRoot && holderRoot.horizontal

    implicitHeight: label.implicitHeight
    // min(natural width, allowed width) — shrinks (and the Text elides) only
    // when the title would otherwise reach the clock.
    implicitWidth: Math.min(label.implicitWidth,
                            holderRoot ? holderRoot._titleMaxWidth : 100000)

    Text {
        id: label
        anchors.fill: parent
        // Gap between the workspace pills and the title (intrinsic, title-only).
        leftPadding: 14
        verticalAlignment: Text.AlignVCenter
        text: root.display
        color: Commons.Appearance.colors.subtext0
        font.pixelSize: Commons.Appearance.font.sizeSm
        font.family: Commons.Appearance.font.family
        elide: Text.ElideRight
    }
}
