import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Commons" as Commons
import "../../../Commons/Primitives" as Prim
import "../../../Services/Persistence" as Persistence

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
    // A card MAY declare visual FACES — interchangeable presentation layouts over
    // the SAME data — instead of hardcoding one look. Each face is a self-contained
    // component file, bound to the owning card for its data:
    //
    //   faces: [{ id, label, file: Qt.resolvedUrl("faces/FooBars.qml"), constraints? }]
    //   face:  "<id>"      // selected face; empty/unknown → first declared (default)
    //
    // The selected face is mounted in the content slot via `faceLoader`, which
    // injects `card` so the face binds to the card's data props (cpu/ram/…). When
    // `faces` is empty the card uses its classic default `_content` children, so
    // every existing card is unaffected. Swapping `face` re-sources ONLY the inner
    // face (the card shell + data/poller stay mounted) — no flicker, no data reset.
    property var faces: []
    property string face: ""

    readonly property int _faceIdx: {
        if (!faces || faces.length === 0) return -1
        for (var i = 0; i < faces.length; i++) if (faces[i].id === face) return i
        return 0   // default = first declared face (clean fallback on empty/unknown)
    }
    readonly property url _faceSource: _faceIdx >= 0 ? faces[_faceIdx].file : ""
    readonly property string _faceLabel: (_faceIdx >= 0 && faces[_faceIdx].label) ? faces[_faceIdx].label : ""

    // ── Face persistence + picker (req_003 / task_030 Wave 3+4) ───────────────
    // The chosen face is stored per-card under "dashboard.faces.<faceKey>" and
    // restored on load, so it survives reloads. The header pill cycles faces.
    property string faceKey: title
    function _loadFace() {
        if (!faces || faces.length < 1) return
        var saved = Persistence.Config.get("dashboard.faces." + faceKey, "")
        if (saved) card.face = saved
    }
    function _selectFace(id) {
        card.face = id
        Persistence.Config.set("dashboard.faces." + faceKey, id)
    }
    function _cycleFace() {
        if (!faces || faces.length < 2) return
        _selectFace(faces[(_faceIdx + 1) % faces.length].id)
    }
    Component.onCompleted: if (Persistence.Config.ready) _loadFace()
    Connections {
        target: Persistence.Config
        function onReadyChanged() { if (Persistence.Config.ready) card._loadFace() }
    }

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

            RowLayout {
                Layout.fillWidth: true
                visible: card.title.length > 0
                spacing: 8

                Text {
                    text: card.title
                    color: Commons.Appearance.colors.accent
                    // Display face for section headers (Cinzel under a grimdark pack;
                    // falls back to the body family when the pack ships none).
                    font.family: Commons.Appearance.font.display
                    font.pixelSize: Commons.Appearance.font.sizeMd
                    font.letterSpacing: 1.5
                    opacity: 0.85
                }

                Item { Layout.fillWidth: true }

                // Face-cycle pill — appears only when the card declares >1 face.
                // Click cycles to the next face and persists the choice.
                Rectangle {
                    id: facePill
                    visible: card.faces && card.faces.length > 1
                    implicitHeight: 20
                    implicitWidth: pillRow.implicitWidth + 14
                    radius: Commons.Appearance.radius.sm
                    color:        faceHov.hovered ? Commons.Appearance.colors.accentAlpha : "transparent"
                    border.color: faceHov.hovered ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.surface1
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "󰕰"
                            color: Commons.Appearance.colors.subtext1
                            font.family: Commons.Appearance.font.family
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: card._faceLabel
                            color: faceHov.hovered ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                            font.family: Commons.Appearance.font.family
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: faceHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: card._cycleFace() }
                }
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

                // Faces mount here when the card declares any; otherwise this
                // Loader is inactive (zero footprint) and the card's classic
                // `_content` children render as before.
                Loader {
                    id: faceLoader
                    active: card._faceIdx >= 0
                    visible: active
                    Layout.fillWidth: true
                    source: card._faceSource
                    onLoaded: if (item && ('card' in item)) item.card = card
                }
            }
        }
    }
}
