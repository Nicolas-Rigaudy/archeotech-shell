import QtQuick
import "." as Commons

// Busy-spinner rotation: one endless revolution loop. Unscaled on purpose (see
// Appearance.anim.spin): a spinner tells the user something is working, so the
// animation-scale and reduced-motion settings leave it running.
//
//   Text { text: "↻"; Commons.Spin { running: busy } }
RotationAnimator {
    loops: Animation.Infinite
    from: 0; to: 360
    duration: Commons.Appearance.anim.spin
}
