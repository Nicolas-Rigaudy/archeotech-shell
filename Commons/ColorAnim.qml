import QtQuick
import "." as Commons

// Reusable colour/opacity animation (§18.4). Short by default (effects range)
// with a decelerate curve — the state-layer / crossfade idiom. Never carries an
// overshoot curve: control-points > 1 would flash a translucent colour past its
// target. Override `duration`/`curve` as needed.
//
//   Behavior on color { Commons.ColorAnim {} }
//   Behavior on border.color { Commons.ColorAnim { duration: Commons.Appearance.anim.effectsMed } }
// (For opacity/number props use Commons.Anim — ColorAnimation only drives colours.)
ColorAnimation {
    property var curve: Commons.Appearance.curve.standardDecel
    duration: Commons.Appearance.anim.fast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: curve
}
