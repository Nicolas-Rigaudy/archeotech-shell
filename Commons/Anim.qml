import QtQuick
import "." as Commons

// Reusable spatial/number animation with M3 curve presets (§18.4). Bundles a
// duration + bezier curve so call sites are one line. Defaults to the "enter
// gently" preset (spatial + emphasized decelerate); flip `exit: true` for the
// brisk "leave briskly" preset. Override `duration`/`curve` for anything else.
//
//   Behavior on scale { Commons.Anim {} }                 // enter, decel
//   Behavior on x     { Commons.Anim { exit: true } }     // exit, accel
//   Behavior on width { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
NumberAnimation {
    property bool exit: false
    property var curve: exit ? Commons.Appearance.curve.emphasizedAccel
                             : Commons.Appearance.curve.emphasizedDecel
    duration: exit ? Commons.Appearance.anim.exit : Commons.Appearance.anim.enter
    easing.type: Easing.BezierSpline
    easing.bezierCurve: curve
}
