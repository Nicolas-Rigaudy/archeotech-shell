import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Commons" as Commons
import "../../../Commons/Primitives" as Prim
import "../../Shell" as ShellUI

// Shared dashboard card shell (2026-07-20 rework). Elevated `surfaceCard` with a
// soft drop shadow (like the launcher tiles), an optional section title +
// divider, and a content slot. Cards declare their properties/Process/Timers as
// usual and put their visual rows as direct children — those land in `inner`.
//
// Non-visual children (Process/Timer/Connections) also route into `inner` via
// the default alias; a ColumnLayout ignores them for layout, so that's harmless.
Item {
    id: card
    default property alias _content: inner.data
    property string title: ""

    // ── Face contract (req_003 / task_030) ───────────────────────────────────
    // A card MAY declare interchangeable FACES over the SAME data instead of one
    // hardcoded look:
    //
    //   faces: [{ id, label, file: Qt.resolvedUrl("faces/FooBars.qml") }, …]
    //   face:  "<id>"      // default; empty/unknown → first declared
    //
    // Switching (drag-swipe / two-finger vertical scroll / page-dot tap), the
    // carousel slide, and persistence all live in the shared ShellUI.FaceHost
    // below — this card just feeds its faces in and passes itself as the data
    // `context` (each face reads it as `card`). When `faces` is empty the FaceHost
    // is hidden and the card's classic `_content` children render unchanged.
    property var faces: []
    property string face: ""
    property string faceKey: title

    implicitHeight: bg.implicitHeight

    RectangularShadow {
        anchors.fill: bg
        radius: bg.radius
        blur:   16
        offset: Qt.vector2d(0, 4)
        spread: 0
        color:  Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
    }

    Prim.MetalSurface {
        id: bg
        anchors.fill: parent
        radius: Commons.Appearance.radius.md
        color:  Commons.Appearance.colors.surfaceCard
        implicitHeight: outer.implicitHeight + 32

        ColumnLayout {
            id: outer
            // bottom-anchored so `inner` can fillHeight — lets a card whose
            // content opts into Layout.fillHeight (e.g. QuickLaunch) stretch to
            // the stretched card height. Content without fillHeight stays at top.
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 16 }
            spacing: 8

            Text {
                visible: card.title.length > 0
                text: card.title
                color: Commons.Appearance.colors.accent
                // Display face for section headers (Cinzel under a grimdark pack; falls
                // back to the body family when the pack ships none).
                font.family: Commons.Appearance.font.display
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.letterSpacing: 1.5
                opacity: 0.85
            }
            Rectangle {
                visible: card.title.length > 0
                Layout.fillWidth: true
                height: 1
                color: Commons.Appearance.colors.surface0
            }

            ColumnLayout {
                id: inner
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Faces mount here when the card declares any; otherwise the FaceHost
                // is hidden (excluded from layout) and `_content` children render.
                ShellUI.FaceHost {
                    visible: card.faces && card.faces.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    faces: card.faces
                    face: card.face
                    configPath: card.faceKey ? "dashboard.faces." + card.faceKey : ""
                    context: card
                    gestures: true
                }
            }
        }
    }
}
