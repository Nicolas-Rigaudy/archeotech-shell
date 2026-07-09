import QtQuick
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

// Sprint 17 Stage 5 — uniform panel container. Owns the glass chrome,
// offsetScale slide-from-edge animation, focus + Esc + click-outside-to-close.
// Content is loaded from PanelRegistry keyed by panelId — adding a new panel
// is one Content/*.qml file + one line in PanelRegistry.
//
// Mounted inside ShellSurface as a sibling of the SideLoaders + CornerBlends;
// covers the full surface so the outer TapHandler can detect off-panel clicks.
//
// Anchoring (panelBox):
//   side="right"  → top+bottom+right (full perpendicular extent, hugs right),
//                   width = size, slide-out via negative rightMargin
//   side="left"   → top+bottom+left,   slide-out via leftMargin
//   side="top"    → left+right+top,    slide-out via topMargin
//   side="bottom" → left+right+bottom, slide-out via bottomMargin
//
// Asymmetric radius — corners on the content-facing edge are rounded; corners
// on the strip-facing edge are flat so the panel reads as continuous with the
// adjacent strip.
Item {
    id: panel
    anchors.fill: parent

    required property string panelId
    required property var    screen

    readonly property string _screenName: screen ? screen.name : ""
    readonly property var    _meta: ShellServices.PanelRegistry.panelFor(panelId)
    readonly property string _side: _meta ? _meta.side : "right"
    readonly property int    _size: _meta ? _meta.size : 320

    function close() { ShellServices.ShellState.close(_screenName) }

    // Public visibility flag for content modules — they connect to onPanelOpenChanged
    // to run state-sync side effects (e.g., refresh nm-cli state when CC opens).
    readonly property bool panelOpen: ShellServices.ShellState.isOpen(_screenName, panelId)
    readonly property bool _open: panelOpen

    // 0 = fully visible at rest, 1 = fully off-screen on the panel's side
    property real offsetScale: _open ? 0 : 1
    Behavior on offsetScale {
        NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic }
    }

    visible: offsetScale < 1.0
    focus: _open
    Keys.priority: Keys.BeforeItem
    Keys.onEscapePressed: close()

    // Gap margins on perpendicular sides so panel doesn't overlap adjacent bars/strips
    readonly property int _topGap:    ShellServices.ShellConfig.sideGap("top",    _screenName)
    readonly property int _bottomGap: ShellServices.ShellConfig.sideGap("bottom", _screenName)
    readonly property int _leftGap:   ShellServices.ShellConfig.sideGap("left",   _screenName)
    readonly property int _rightGap:  ShellServices.ShellConfig.sideGap("right",  _screenName)

    // Click outside the panel box → close
    TapHandler {
        enabled: panel._open
        onTapped: point => {
            var p = point.position
            if (p.x < panelBox.x || p.x > panelBox.x + panelBox.width ||
                p.y < panelBox.y || p.y > panelBox.y + panelBox.height) {
                panel.close()
            }
        }
    }

    Rectangle {
        id: panelBox

        anchors.top:    panel._side === "bottom" ? undefined : parent.top
        anchors.bottom: panel._side === "top"    ? undefined : parent.bottom
        anchors.left:   panel._side === "right"  ? undefined : parent.left
        anchors.right:  panel._side === "left"   ? undefined : parent.right

        anchors.topMargin:    panel._side === "bottom" ? 0
                            : panel._side === "top"    ? panel._topGap - (panel._size + panel._topGap + 5) * panel.offsetScale
                            : panel._topGap
        anchors.bottomMargin: panel._side === "top"    ? 0
                            : panel._side === "bottom" ? panel._bottomGap - (panel._size + panel._bottomGap + 5) * panel.offsetScale
                            : panel._bottomGap
        anchors.leftMargin:   panel._side === "right"  ? 0
                            : panel._side === "left"   ? panel._leftGap - (panel._size + panel._leftGap + 5) * panel.offsetScale
                            : panel._leftGap
        anchors.rightMargin:  panel._side === "left"   ? 0
                            : panel._side === "right"  ? panel._rightGap - (panel._size + panel._rightGap + 5) * panel.offsetScale
                            : panel._rightGap

        width:  panel._side === "left" || panel._side === "right" ? panel._size : 0
        height: panel._side === "top"  || panel._side === "bottom" ? panel._size : 0

        color: Commons.Appearance.colors.glassBg

        // Strip-adjacent corners are flat; content-facing corners are rounded.
        readonly property real _r: Commons.Appearance.radius.lg
        topLeftRadius:     panel._side === "right"  || panel._side === "bottom" ? _r : 0
        topRightRadius:    panel._side === "left"   || panel._side === "bottom" ? _r : 0
        bottomLeftRadius:  panel._side === "right"  || panel._side === "top"    ? _r : 0
        bottomRightRadius: panel._side === "left"   || panel._side === "top"    ? _r : 0

        opacity: 1 - panel.offsetScale * 0.4

        Loader {
            id: _contentLoader
            anchors.fill: parent
            anchors.margins: 12
            sourceComponent: panel._meta ? panel._meta.content : null
            onLoaded: {
                if (item && 'panelRoot' in item) item.panelRoot = panel
            }
        }
    }
}
