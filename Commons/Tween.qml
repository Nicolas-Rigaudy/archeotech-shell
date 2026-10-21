import QtQuick
import "." as Commons

// The shell's general-purpose tween: a short ease-out on any number property
// (fades, scale pops, height/width settles, position moves). `time` defaults to
// the effects token; pass another animation token for a different pace.
//
//   Behavior on opacity { Commons.Tween {} }
//   Behavior on x       { Commons.Tween { spatial: true; time: Commons.Appearance.anim.base } }
//
// spatial: true marks movement (position, size, scale, rotation): reduced motion
// makes it instant, where opacity and colour keep their fade. The animation-scale
// setting and pack `anim` overrides reach every tween through the tokens.
// overshoot: true settles with a small bounce (spatial props only).
NumberAnimation {
    property int  time: Commons.Appearance.anim.effectsFast
    property bool spatial: false
    property bool overshoot: false

    duration: (spatial && Commons.Appearance.reducedMotion) ? 0 : time
    easing.type: overshoot ? Easing.OutBack : Easing.OutCubic
    easing.overshoot: 1.2
}
