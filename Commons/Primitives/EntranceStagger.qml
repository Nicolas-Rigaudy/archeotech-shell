import QtQuick
import ".." as Commons
import "EntranceLogic.js" as Logic

// Staggered panel entrance: fades `target` in while it rises `distance` px into
// place, starting `baseDelay + index*step` ms after it mounts. Declare one per
// child of a panel with an increasing `index`, e.g. inside a dashboard card:
//
//   EntranceStagger { target: card; index: 2 }
//
// Cheap by construction: one NumberAnimation per target that stops at 1 — no
// layer.enabled, no per-frame work afterwards. `enabled: false` shows the
// target settled at once (the hook for a reduced-motion setting).
Item {
    id: root

    required property Item target
    property int  index: 0
    property int  step: 55
    property int  baseDelay: 90
    property real distance: 14
    property bool enabled: true

    // Entrance progress, 0 → 1. 1 once settled (or when disabled).
    property real progress: enabled ? 0 : 1

    visible: false
    width: 0; height: 0

    Binding { target: root.target; property: "opacity"; value: root.progress }

    Translate { id: shift; y: Logic.offset(root.progress, root.distance) }
    Component.onCompleted: {
        root.target.transform = [shift]
        if (enabled) enter.start()
    }

    SequentialAnimation {
        id: enter
        PauseAnimation { duration: Logic.startDelay(root.index, root.step, root.baseDelay) }
        NumberAnimation {
            target: root; property: "progress"; to: 1
            duration: Commons.Appearance.anim.spatialFast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Commons.Appearance.curve.emphasizedDecel
        }
    }
}
