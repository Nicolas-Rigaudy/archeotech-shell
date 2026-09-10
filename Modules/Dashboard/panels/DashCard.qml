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

    // ── Face persistence + swipe switching (req_003 / task_030 Wave 3+4) ───────
    // The chosen face is stored per-card under "dashboard.faces.<faceKey>" and
    // restored on load, so it survives reloads. Users switch faces by SWIPING the
    // card left/right (DragHandler in bg) or tapping a page-dot; each change slides
    // the new face in (faceEnter) — no header chrome, keeping the card uncluttered.
    property string faceKey: title
    property int _swipeDir: 1        // +1 next (slide from right), -1 prev
    function _loadFace() {
        if (!faces || faces.length < 1) return
        var saved = Persistence.Config.get("dashboard.faces." + faceKey, "")
        if (saved) card.face = saved
    }
    function _selectFace(id) {
        if (!id || id === card.face) return        // no-op guard (avoids stray writes)
        card.face = id
        Persistence.Config.set("dashboard.faces." + faceKey, id)
    }
    function _goFace(delta) {                       // relative step (swipe): wraps
        if (!faces || faces.length < 2) return
        var n = faces.length
        card._swipeDir = delta >= 0 ? 1 : -1
        _selectFace(faces[((_faceIdx + delta) % n + n) % n].id)
    }
    function _selectIndex(i) {                      // absolute (page-dot tap)
        if (!faces || i < 0 || i >= faces.length || i === _faceIdx) return
        card._swipeDir = i >= _faceIdx ? 1 : -1
        _selectFace(faces[i].id)
    }
    onFaceChanged: faceStack.transition(card._swipeDir)
    Component.onCompleted: if (Persistence.Config.ready) _loadFace()
    Connections {
        target: Persistence.Config
        function onReadyChanged() { if (Persistence.Config.ready) card._loadFace() }
    }

    // Touchpad two-finger horizontal swipe → face change. Accumulate the wheel
    // deltas and cool down after a step so one gesture moves one face, not a burst.
    property real _wheelAccum: 0
    property bool _wheelCooling: false
    Timer { id: _wheelCool; interval: 350; onTriggered: card._wheelCooling = false }

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

        // Swipe the card body left/right to change face (only with >1 face).
        // target:null → tracks without moving anything; taps still reach page-dots.
        DragHandler {
            target: null
            enabled: card.faces && card.faces.length > 1
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (active) return
                var dx = centroid.position.x - centroid.pressPosition.x
                var dy = centroid.position.y - centroid.pressPosition.y
                // Genuine horizontal swipe only: ≥40px, within the card, and more
                // horizontal than vertical — guards against stray/warp events.
                if (Math.abs(dx) < 40 || Math.abs(dx) >= card.width) return
                if (Math.abs(dx) < Math.abs(dy)) return
                card._goFace(dx < 0 ? 1 : -1)
            }
        }

        // Touchpad two-finger horizontal swipe (and horizontal wheel) → face change.
        // No acceptedDevices filter — if the touchpad enumerates as a generic pointer
        // the filter would silently drop its scroll events. Accept horizontal intent.
        WheelHandler {
            enabled: card.faces && card.faces.length > 1
            onWheel: (ev) => {
                if (card._wheelCooling) return
                var h = ev.angleDelta.x
                // Some setups deliver a horizontal swipe as y with a modifier; prefer
                // x, but fall back to y only when x is absent and shift isn't held.
                if (h === 0 && !(ev.modifiers & Qt.ShiftModifier)) return
                if (Math.abs(h) < Math.abs(ev.angleDelta.y)) return   // vertical scroll → ignore
                card._wheelAccum += h
                if (Math.abs(card._wheelAccum) >= 90) {
                    card._goFace(card._wheelAccum < 0 ? 1 : -1)
                    card._wheelAccum = 0
                    card._wheelCooling = true
                    _wheelCool.restart()
                }
            }
        }

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

                // Two-loader CAROUSEL: on a face change the outgoing face slides
                // out one way while the incoming slides in the other (a real
                // carousel, not a crossfade). Both loaders inject `card` for data.
                // When `faces` is empty this whole item is hidden (excluded from the
                // layout) and the card's classic `_content` children render instead.
                Item {
                    id: faceStack
                    visible: card._faceIdx >= 0
                    Layout.fillWidth: true
                    // Fill the card's (row-stretched) height; preferredHeight tracks
                    // the current face so the card sizes correctly without growing.
                    Layout.fillHeight: true
                    Layout.preferredHeight: faceMain.item && faceMain.item.implicitHeight ? faceMain.item.implicitHeight : 0
                    clip: true

                    property bool _snap: false      // set offset without animating
                    property real xMain: 0
                    property real xPrev: 0
                    // Source last shown, so a transition knows what to slide OUT
                    // (faceMain already binds to the NEW source by the time we run).
                    property url _shownSource: card._faceSource

                    // The current face — content BOUND to card.face, so it is ALWAYS
                    // correct (matches the page-dots) no matter how fast you swipe.
                    Loader {
                        id: faceMain
                        anchors.fill: parent
                        source: card._faceSource
                        onLoaded: if (item && ('card' in item)) item.card = card
                        transform: Translate { x: faceStack.xMain }
                    }
                    // Transient: holds the OUTGOING face only during a slide.
                    Loader {
                        id: facePrev
                        anchors.fill: parent
                        active: false
                        onLoaded: if (item && ('card' in item)) item.card = card
                        transform: Translate { x: faceStack.xPrev }
                    }

                    Behavior on xMain { enabled: !faceStack._snap; NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
                    Behavior on xPrev { enabled: !faceStack._snap; NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

                    // Slide the (already-bound) new face in from `dir` while a snapshot
                    // of the old face slides out the other way. Content is never
                    // managed imperatively → no ordering races on rapid swipes.
                    function transition(dir) {
                        var oldSrc = _shownSource
                        _shownSource = card._faceSource
                        if (width <= 0 || !oldSrc || oldSrc === card._faceSource) return
                        facePrev.source = oldSrc
                        facePrev.active = true
                        _snap = true; xPrev = 0; xMain = dir * width; _snap = false
                        xPrev = -dir * width
                        xMain = 0
                        _cleanup.restart()
                    }

                    Timer {
                        id: _cleanup
                        interval: Commons.Appearance.anim.base + 80
                        onTriggered: {
                            facePrev.active = false
                            faceStack._snap = true; faceStack.xPrev = 0; faceStack._snap = false
                        }
                    }
                }

                // Page-dots — the only face affordance. Active dot elongates; tap to jump.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: card.faces && card.faces.length > 1
                    spacing: 6
                    Repeater {
                        model: card.faces
                        delegate: Rectangle {
                            required property int index
                            implicitWidth: index === card._faceIdx ? 16 : 6
                            implicitHeight: 6
                            radius: 3
                            color: index === card._faceIdx ? Commons.Appearance.colors.accent
                                                           : Commons.Appearance.colors.surface1
                            Behavior on implicitWidth { NumberAnimation { duration: Commons.Appearance.anim.fast; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                            TapHandler { onTapped: card._selectIndex(index) }
                        }
                    }
                }
            }
        }
    }
}
