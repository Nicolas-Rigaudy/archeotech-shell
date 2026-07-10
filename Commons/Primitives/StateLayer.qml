import QtQuick
import ".." as Commons

// Shared hover/press state-layer (§18.4 micro-interaction primitive). A plain
// accent-tinted overlay whose opacity tracks pointer state, plus an optional
// press-depress / hover-grow scale on a target item. Replaces per-widget
// hand-rolled `hovered ? accentAlpha : transparent` swaps.
//
// Drop it in as the LAST visual child of a rounded surface:
//   Rectangle {
//       radius: Commons.Appearance.radius.base
//       Behavior on scale { Commons.Anim { curve: ...expressiveDefaultSpatial } }
//       // …content…
//       StateLayer { anchors.fill: parent; onClicked: doThing() }
//   }
//
// Hit-testing rule (DECISIONS 2026-07-02): this is a normal sibling overlay
// with a normal MouseArea — never a `layer.enabled` wrapper — so hover/press
// hit-testing stays correct. The MouseArea also *consumes* the click, so a host
// row's own TapHandler won't also fire (matches the old pin-button pattern).
Rectangle {
    id: layer

    // ── Tunables ──────────────────────────────────────────────────────────────
    property color tint:        Commons.Appearance.colors.stateHover
    property color pressTint:   Commons.Appearance.colors.statePressed
    property real  pressScale:  0.98   // press-depress; 1.0 to disable
    property real  hoverScale:  1.0    // hover-grow;  >1.0 to enable
    // Item the scale is applied to (needs its own `Behavior on scale`). Defaults
    // to the host surface this overlay fills.
    property Item  scaleTarget: parent
    property int   cursorShape: Qt.PointingHandCursor
    property bool  interactive: true

    // ── Readouts ──────────────────────────────────────────────────────────────
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.containsPress
    signal clicked()

    // Inherit the host's corner radius so the wash matches the surface.
    radius: parent && parent.radius ? parent.radius : 0
    color: area.containsPress ? pressTint : tint
    opacity: !interactive ? 0.0
           : area.containsPress ? 1.0
           : area.containsMouse ? 1.0 : 0.0
    Behavior on opacity { Commons.Anim { duration: Commons.Appearance.anim.fast; curve: Commons.Appearance.curve.standardDecel } }
    Behavior on color   { Commons.ColorAnim {} }

    Binding {
        target: layer.scaleTarget
        property: "scale"
        when: layer.interactive && layer.scaleTarget !== null
              && (layer.pressScale !== 1.0 || layer.hoverScale !== 1.0)
        value: area.containsPress ? layer.pressScale
             : area.containsMouse ? layer.hoverScale : 1.0
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: layer.interactive
        hoverEnabled: true
        cursorShape: layer.cursorShape
        onClicked: layer.clicked()
    }
}
