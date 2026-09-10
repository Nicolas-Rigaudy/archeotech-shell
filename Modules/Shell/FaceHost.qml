import QtQuick
import QtQuick.Layouts
import "../../Commons" as Commons
import "../../Services/Persistence" as Persistence

// Reusable face-switching viewport (req_003 / task_030 — the host-agnostic face
// contract). Declares interchangeable FACES over one data context, persists the
// choice, and switches via drag-swipe / two-finger VERTICAL scroll / page-dot tap
// with a carousel slide. Embed it in any card or panel:
//
//   FaceHost {
//       faces: [{ id, label, file: Qt.resolvedUrl("faces/Foo.qml") }, …]
//       face: "foo"                       // default; empty/unknown → first
//       configPath: "media.face"          // Persistence.Config key for the choice
//       context: theDataProvider          // injected into each face as `host`/`card`
//       gestures: true                    // drag+wheel (off for button-heavy panels)
//   }
//
// MangoWC drops horizontal two-finger scroll to layer surfaces, so the wheel path
// uses the VERTICAL axis (pixelDelta for touchpad) — see Widgets/Appearance/Carousel.
Item {
    id: faceHost

    property var faces: []
    property string face: ""
    property string configPath: ""
    property var context: null
    property bool gestures: true

    readonly property int _idx: {
        if (!faces || faces.length === 0) return -1
        for (var i = 0; i < faces.length; i++) if (faces[i].id === face) return i
        return 0
    }
    readonly property url _src: _idx >= 0 ? faces[_idx].file : ""

    // Size to the current face (+ dots) so a host layout can measure it.
    implicitHeight: (faceMain.item ? faceMain.item.implicitHeight : 0)
                    + (dots.visible ? dots.implicitHeight + 6 : 0)

    // ── persistence + switching ───────────────────────────────────────────────
    property int _swipeDir: 1
    property real _wheelAccum: 0
    property url _shownSource: _src
    function _loadFace() {
        if (!configPath) return
        var saved = Persistence.Config.get(configPath, "")
        if (saved) faceHost.face = saved
    }
    function _select(id) {
        if (!id || id === face) return
        faceHost.face = id
        if (configPath) Persistence.Config.set(configPath, id)
    }
    function _go(delta) {
        if (!faces || faces.length < 2) return
        var n = faces.length
        _swipeDir = delta >= 0 ? 1 : -1
        _select(faces[((_idx + delta) % n + n) % n].id)
    }
    function _selectIndex(i) {
        if (!faces || i < 0 || i >= faces.length || i === _idx) return
        _swipeDir = i >= _idx ? 1 : -1
        _select(faces[i].id)
    }
    function _inject(it) {
        if (!it) return
        if ('host' in it) it.host = context
        if ('card' in it) it.card = context     // legacy name (DashCard faces)
    }
    onFaceChanged: carousel.transition(_swipeDir)
    Component.onCompleted: if (Persistence.Config.ready) _loadFace()
    Connections {
        target: Persistence.Config
        function onReadyChanged() { if (Persistence.Config.ready) faceHost._loadFace() }
    }

    // ── carousel viewport ─────────────────────────────────────────────────────
    Item {
        id: carousel
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            bottom: dots.visible ? dots.top : parent.bottom
            bottomMargin: dots.visible ? 4 : 0
        }
        clip: true

        property bool _snap: false
        property real xMain: 0
        property real xPrev: 0

        // Current face — content BOUND to faceHost.face, so it is ALWAYS correct
        // (matches the page-dots) no matter how fast you switch.
        Loader {
            id: faceMain
            anchors.fill: parent
            source: faceHost._src
            onLoaded: faceHost._inject(item)
            transform: Translate { x: carousel.xMain }
        }
        // Transient: holds the OUTGOING face only during a slide.
        Loader {
            id: facePrev
            anchors.fill: parent
            active: false
            onLoaded: faceHost._inject(item)
            transform: Translate { x: carousel.xPrev }
        }

        Behavior on xMain { enabled: !carousel._snap; NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
        Behavior on xPrev { enabled: !carousel._snap; NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

        function transition(dir) {
            var oldSrc = faceHost._shownSource
            faceHost._shownSource = faceHost._src
            if (width <= 0 || !oldSrc || oldSrc === faceHost._src) return
            facePrev.source = oldSrc
            facePrev.active = true
            _snap = true; xPrev = 0; xMain = dir * width; _snap = false
            xPrev = -dir * width
            xMain = 0
            cleanup.restart()
        }
        Timer {
            id: cleanup
            interval: Commons.Appearance.anim.base + 80
            onTriggered: { facePrev.active = false; carousel._snap = true; carousel.xPrev = 0; carousel._snap = false }
        }

        DragHandler {
            target: null
            enabled: faceHost.gestures && faceHost.faces && faceHost.faces.length > 1
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveChanged: {
                if (active) return
                var dx = centroid.position.x - centroid.pressPosition.x
                var dy = centroid.position.y - centroid.pressPosition.y
                if (Math.abs(dx) < 40 || Math.abs(dx) >= faceHost.width) return
                if (Math.abs(dx) < Math.abs(dy)) return
                faceHost._go(dx < 0 ? 1 : -1)
            }
        }
        WheelHandler {
            enabled: faceHost.gestures && faceHost.faces && faceHost.faces.length > 1
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                var isTouch = event.pixelDelta.y !== 0
                var dy = isTouch ? event.pixelDelta.y : event.angleDelta.y
                if (dy === 0) return
                if ((dy < 0) !== (faceHost._wheelAccum < 0)) faceHost._wheelAccum = 0
                faceHost._wheelAccum += dy
                var step = 120
                while (faceHost._wheelAccum <= -step) { faceHost._go(1);  faceHost._wheelAccum += step }
                while (faceHost._wheelAccum >=  step) { faceHost._go(-1); faceHost._wheelAccum -= step }
                event.accepted = true
            }
        }
    }

    // ── page-dots — the affordance; tap to jump ─────────────────────────────────
    RowLayout {
        id: dots
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        visible: faceHost.faces && faceHost.faces.length > 1
        spacing: 6
        Repeater {
            model: faceHost.faces
            delegate: Rectangle {
                required property int index
                implicitWidth: index === faceHost._idx ? 16 : 6
                implicitHeight: 6
                radius: 3
                color: index === faceHost._idx ? Commons.Appearance.colors.accent
                                               : Commons.Appearance.colors.surface1
                Behavior on implicitWidth { NumberAnimation { duration: Commons.Appearance.anim.fast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                TapHandler { onTapped: faceHost._selectIndex(index) }
            }
        }
    }
}
