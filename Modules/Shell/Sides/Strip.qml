import QtQuick
import QtQuick.Shapes
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices
import "../Panels" as Panels

// Edge strip + popup + panel — single component for all three states.
//
//   1. Idle  — thin frame at the screen edge (collapsedSize).
//   2. Hover — popup card grows from the strip's inner edge; icons centered.
//   3. Active — popup expands further into a full panel; the icons stay as a
//      sidebar/tabbar at the strip-attached edge (so the user can switch
//      between e.g. CC and NC), content from PanelRegistry fills the rest.
//
// The card's screen position is invariant: idle and panel modes both grow
// perpendicular to the strip, and the icon column sits at the strip-attached
// edge of the body the whole time — so icons stay glued to the screen edge
// while content emerges into the new space.
Item {
    id: strip

    required property string side
    required property var screen

    // Holder mode (Sprint 21): the resting strip body is hidden and reserves
    // no space — only an invisible edge-width hover zone remains, so the card
    // reveals on hover/shortcut and floats over tiled windows. Card + icons +
    // panel behaviour are otherwise identical to a strip.
    property bool holderMode: false

    // panelRoot interface for content modules (mirrors Panel.qml). Closing is
    // global — exiting a panel on one screen closes every screen's instance.
    function close() { ShellServices.ShellState.closeAllAcross() }
    readonly property bool panelOpen: _panelOpen

    // ── holderRoot contract (Sprint 26-C phase 4) ──────────────────────────────
    // The superset API a bar and a strip both expose, so one opener widget runs
    // on either. Strips implement the hover-reveal + panel half; dismissPopups is
    // a no-op (a strip has no floating control popups). anchor is ignored — a
    // strip card is centred, not anchored under the opener.
    readonly property string type:       holderMode ? "holder" : "strip"
    readonly property bool   horizontal: _horizontal
    readonly property string screenName: _screenName
    readonly property int    thickness:  _bodyDepth
    function togglePanel(id, sideArg, anchor) {
        ShellServices.ShellState.toggleGlobal(id, sideArg !== undefined ? sideArg : side)
    }
    function dismissPopups() {}
    // Is `id` the active panel shown on THIS strip? (_showsPanel only checks the
    // side/primary-host routing, so AND the id match — else every opener on an
    // active side reports active.)
    function showsPanel(id)  { return _activePanel === id && _showsPanel(id) }
    function iconHoverEnter() { _iconHoverEnter() }
    function iconHoverExit()  { _iconHoverExit() }

    readonly property string _screenName: screen ? screen.name : ""
    readonly property bool   _horizontal: side === "top" || side === "bottom"
    readonly property var    _icons: ShellServices.ShellConfig.stripIcons(side, _screenName)
    readonly property int    collapsedSize: ShellServices.ShellConfig.sideSize(side, _screenName)
    readonly property int    _expanded:     ShellServices.ShellConfig.sideExpanded(side, _screenName)

    readonly property string _activePanel: ShellServices.ShellState.activePanel(_screenName)
    // Sprint 26 follow-up B — only show the panel if the active side matches
    // this strip (or is wildcard ""), so the same opener on 2+ sides opens
    // just the clicked one.
    readonly property string _activeSide:  ShellServices.ShellState.activeSide(_screenName)
    // A wildcard open (side "" — bar gear / shortcut / IPC) must show on exactly
    // ONE strip, not every strip that lists the panel. Pick the primary host:
    // the first side in priority order whose config hosts this panel.
    function _isPrimaryHost(id) {
        var order = ["right", "bottom", "left", "top"]
        for (var i = 0; i < order.length; i++) {
            if (ShellServices.ShellConfig.stripIcons(order[i], _screenName).indexOf(id) !== -1)
                return order[i] === side
        }
        return false
    }
    function _showsPanel(id) {
        if (!id || _icons.indexOf(id) === -1) return false
        return _activeSide === side || (_activeSide === "" && _isPrimaryHost(id))
    }
    readonly property bool   _panelOpen:   _activePanel !== "" && _showsPanel(_activePanel)
    readonly property bool   _showCard:    _hov || _panelOpen

    // Panel meta + content mount live in the shared PanelHost kernel (declared
    // inside contentArea as `host`). Strip reads its size hints to drive the card
    // geometry below. `host` is referenced by id from component scope — it's
    // declared later in the file, which QML resolves fine.
    readonly property int    _panelSize:   host.panelSize
    readonly property var    _axisSizeRaw: host.axisSizeRaw
    // Panel content may expose `implicitAxis` (numeric) to drive axisSize:"auto".
    readonly property real   _contentImplicitAxis: host.contentImplicitAxis

    property bool _hov: false
    // Defensive: child MouseAreas can shadow the strip-level MA's hover in Qt 6.
    // OR'ing an explicit icon-hover counter keeps the popup alive even when
    // the strip MA momentarily loses its containsMouse to an icon's MouseArea.
    property int _iconHoverCount: 0
    function _updateHover() {
        if (_stripMA.containsMouse || _iconHoverCount > 0) {
            _leaveTimer.stop()
            strip._hov = true
        } else {
            _leaveTimer.restart()
        }
    }

    // ── Sizing ─────────────────────────────────────────────────────────────────
    readonly property int _iconSize:    36
    readonly property int _iconSpacing: 8
    readonly property int _padLong:     14
    readonly property int _padShort:    4
    readonly property int _iconsLen:    _icons.length * _iconSize
                                      + Math.max(0, _icons.length - 1) * _iconSpacing
    readonly property int _bodyAxis:    Math.max(_expanded, _iconsLen + 2 * _padLong)
    readonly property int _bodyDepth:   _iconSize + 2 * _padShort

    readonly property int _r:  Commons.Appearance.radius.md  // neck arc radius (smaller = popup less tall)
    readonly property int _rb: Commons.Appearance.radius.md
    readonly property int _popupExtra: _bodyDepth + _r

    // Auto-sized panels only know their axis extent once their content has
    // loaded + measured `implicitAxis`; until then hold the card at popup size so
    // it expands in ONE motion (the anti-jitter gate). PanelHost computes this.
    readonly property bool _ready: host.ready

    // Perpendicular expansion target (drives strip Item size + card perpendicular dim).
    readonly property real _perpTarget: (_panelOpen && _ready) ? _panelSize
                                       : (_hov || _panelOpen)  ? _popupExtra
                                       :                          0

    // Animated values — bound to targets so they animate on state changes.
    property real _perp: _perpTarget
    Behavior on _perp { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }

    // Along-strip extent. Floor at the icon cluster width; ceil at the screen
    // axis. axisSize "full" = legacy (entire screen edge), "auto" = follow
    // content's implicitAxis, numeric = exact pixels (still clamped).
    readonly property int _screenAxis: _horizontal ? width : height
    readonly property int _axisFloor:  _bodyAxis + 2 * _r
    readonly property real _axisTarget: (!_panelOpen || !_ready)
        ? _axisFloor
        : _axisSizeRaw === "full" ? _screenAxis
        : _axisSizeRaw === "auto" ? Math.min(_screenAxis, Math.max(_axisFloor, _contentImplicitAxis + 2 * _r))
        :                            Math.min(_screenAxis, Math.max(_axisFloor, _axisSizeRaw))
    property real _axis: _axisTarget
    Behavior on _axis { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }

    // Card position along the strip axis: always centered on the screen.
    // Icons cluster around the card's center via iconArea, so a centered
    // card means icons stay glued to their idle screen position regardless
    // of card width or which icon is active. (An earlier draft anchored the
    // card on the active icon — that pulled the whole card sideways when
    // switching panels, since the icon row clusters and isn't spread out.)
    readonly property real _cardAxis: (_screenAxis - _axis) / 2

    // Perpendicular offset of the card from the screen edge. A strip insets
    // the card by its (visible) collapsed body; a holder has no resting body,
    // so the card sits flush against the screen edge (no gap).
    readonly property real _edgeInset:  holderMode ? 0 : collapsedSize
    // At rest a holder still needs a thin hover-catch even though _perp is 0.
    readonly property real _perpExtent: holderMode ? Math.max(collapsedSize, _perp)
                                                   : (collapsedSize + _perp)

    // Item grows perpendicular to the strip so the popup/panel falls inside
    // ShellSurface's input mask.
    implicitWidth:  _horizontal ? 0 : _perpExtent
    implicitHeight: _horizontal ? _perpExtent : 0

    // Keyboard focus + Esc-to-close when panel is open.
    focus: _panelOpen
    Keys.priority: Keys.BeforeItem
    Keys.onEscapePressed: strip.close()

    // Strip-level hover tracker. Hover-only (clicks pass through). The
    // containsMouseChanged handler funnels into _updateHover() so the popup
    // state is the OR of (strip-MA hover, any-icon hover) — robust to Qt 6's
    // child-MA hover shadowing.
    MouseArea {
        id: _stripMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: strip._updateHover()
    }

    Timer {
        id: _leaveTimer
        interval: 250
        onTriggered: strip._hov = false
    }

    // Called by strip icons via holderRoot — keeps the popup card open
    // when the cursor crosses from the strip body onto an icon (and
    // back), even when child MouseAreas shadow the strip-level hover.
    function _iconHoverEnter() { _iconHoverCount++;                       _updateHover() }
    function _iconHoverExit()  { _iconHoverCount = Math.max(0, _iconHoverCount - 1); _updateHover() }

    // ── Always-visible strip body ─────────────────────────────────────────────
    Rectangle {
        id: stripBody
        z: 1
        // Transparent — the unified FrameBackground (ShellSurface) draws the
        // resting strip glass + shared rounded corners (S22). Kept (non-holder)
        // only so the hover MouseArea / geometry stays as before; the popup card
        // below still draws its own glass.
        visible: !strip.holderMode
        color: "transparent"

        anchors.left:   (strip._horizontal || strip.side === "left")    ? parent.left   : undefined
        anchors.right:  (strip._horizontal || strip.side === "right")   ? parent.right  : undefined
        anchors.top:    (!strip._horizontal || strip.side === "top")    ? parent.top    : undefined
        anchors.bottom: (!strip._horizontal || strip.side === "bottom") ? parent.bottom : undefined
        width:  strip._horizontal ? undefined : strip.collapsedSize
        height: strip._horizontal ? strip.collapsedSize : undefined
    }

    // ── Card (popup → panel) ───────────────────────────────────────────────────
    Shape {
        id: card

        readonly property real _r:  strip._r
        readonly property real _rb: strip._rb

        // Perpendicular dim follows _perp; along-strip dim follows _axis.
        width:  strip._horizontal ? strip._axis : strip._perp
        height: strip._horizontal ? strip._perp : strip._axis

        // Perpendicular: attach edge sits at the strip body's inner edge.
        // Along-axis: anchored on the active icon's screen center
        // (preserves popup→panel continuity), clamped to screen bounds.
        x: strip.side === "right" ? parent.width  - strip._edgeInset - card.width
         : strip.side === "left"  ? strip._edgeInset
         : strip._cardAxis
        y: strip.side === "bottom" ? parent.height - strip._edgeInset - card.height
         : strip.side === "top"    ? strip._edgeInset
         : strip._cardAxis

        // Sprint 26 fix: NO layer here. The icons live inside this card; with
        // layer.enabled the layered item's input hit-test ate all hover (the
        // strip MouseArea never saw the cursor) and icon hover flipped with the
        // card size → a feedback loop that made the popup jitter. CurveRenderer
        // antialiases the shape natively (no offscreen layer), so edges stay
        // smooth without blocking hover. (See DECISIONS 2026-07-02.)
        preferredRendererType: Shape.CurveRenderer

        transformOrigin: strip.side === "right"  ? Item.Right
                       : strip.side === "left"   ? Item.Left
                       : strip.side === "bottom" ? Item.Bottom : Item.Top

        opacity: strip._showCard ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        readonly property var _p: {
            const W = width, H = height, r = _r, rb = _rb
            if (strip.side === "right")  return [
                Qt.point(W,     0),       Qt.point(W,     H),
                Qt.point(W - r, H - r),   Qt.point(rb,    H - r),
                Qt.point(0,     H - r - rb), Qt.point(0,  r + rb),
                Qt.point(rb,    r),       Qt.point(W - r, r)
            ]
            if (strip.side === "left") return [
                Qt.point(0,     H),       Qt.point(0,     0),
                Qt.point(r,     r),       Qt.point(W - rb, r),
                Qt.point(W,     r + rb),  Qt.point(W,     H - r - rb),
                Qt.point(W - rb, H - r),  Qt.point(r,     H - r)
            ]
            if (strip.side === "top") return [
                Qt.point(0,         0),     Qt.point(W,         0),
                Qt.point(W - r,     r),     Qt.point(W - r,     H - rb),
                Qt.point(W - r - rb, H),    Qt.point(r + rb,    H),
                Qt.point(r,         H - rb), Qt.point(r,        r)
            ]
            return [
                Qt.point(W,         H),     Qt.point(0,         H),
                Qt.point(r,         H - r), Qt.point(r,         rb),
                Qt.point(r + rb,    0),     Qt.point(W - r - rb, 0),
                Qt.point(W - r,     rb),    Qt.point(W - r,     H - r)
            ]
        }

        ShapePath {
            fillColor:   Commons.Appearance.colors.glassBgLight
            strokeWidth: 0
            strokeColor: "transparent"

            startX: card._p[0].x
            startY: card._p[0].y
            PathLine { x: card._p[1].x; y: card._p[1].y }
            PathArc  { x: card._p[2].x; y: card._p[2].y
                       radiusX: card._r;  radiusY: card._r;  direction: PathArc.Counterclockwise }
            PathLine { x: card._p[3].x; y: card._p[3].y }
            PathArc  { x: card._p[4].x; y: card._p[4].y
                       radiusX: card._rb; radiusY: card._rb; direction: PathArc.Clockwise }
            PathLine { x: card._p[5].x; y: card._p[5].y }
            PathArc  { x: card._p[6].x; y: card._p[6].y
                       radiusX: card._rb; radiusY: card._rb; direction: PathArc.Clockwise }
            PathLine { x: card._p[7].x; y: card._p[7].y }
            PathArc  { x: card._p[0].x; y: card._p[0].y
                       radiusX: card._r;  radiusY: card._r;  direction: PathArc.Counterclockwise }
        }

        // ── Content area: active panel content, mounted by the shared PanelHost
        // kernel (Sprint 26-C phase 4 — replaces the inline meta+loader copy that
        // BarPanel already shares). PanelHost resolves meta, mounts the built-in
        // Component / plugin file:// content, injects panelRoot + appearance, and
        // reports size hints; Strip reads those (via id `host`) to size the card.
        Item {
            id: contentArea

            anchors.left:   strip.side === "left"   ? iconArea.right  : parent.left
            anchors.right:  strip.side === "right"  ? iconArea.left   : parent.right
            anchors.top:    strip.side === "top"    ? iconArea.bottom : parent.top
            anchors.bottom: strip.side === "bottom" ? iconArea.top    : parent.bottom
            anchors.leftMargin:   strip.side === "left"   ? 4 : strip._r
            anchors.rightMargin:  strip.side === "right"  ? 4 : strip._r
            anchors.topMargin:    strip.side === "top"    ? 4 : strip._r
            anchors.bottomMargin: strip.side === "bottom" ? 4 : strip._r

            opacity: (strip._panelOpen && strip._ready) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Panels.PanelHost {
                id: host
                anchors.fill: parent
                side:       strip.side
                screen:     strip.screen
                panelId:    strip._activePanel
                shown:      strip._panelOpen
                screenAxis: strip._screenAxis
                axisFloor:  strip._bodyAxis
                panelRoot:  strip
            }
        }

        // ── Icon area: anchored to the card's strip-attached edge with a r/2
        // margin (so the icon is perpendicular-centered in the small popup
        // and stays at the same screen position when the panel expands).
        // Full extent along the strip; icons cluster around the bodyAxis-wide
        // center so they don't fly apart in panel mode.
        Item {
            id: iconArea

            anchors.left:   strip.side === "right"  ? undefined : parent.left
            anchors.right:  strip.side === "left"   ? undefined : parent.right
            anchors.top:    strip.side === "bottom" ? undefined : parent.top
            anchors.bottom: strip.side === "top"    ? undefined : parent.bottom

            anchors.leftMargin:   strip.side === "left"   ? strip._r / 2 : strip._r
            anchors.rightMargin:  strip.side === "right"  ? strip._r / 2 : strip._r
            anchors.topMargin:    strip.side === "top"    ? strip._r / 2 : strip._r
            anchors.bottomMargin: strip.side === "bottom" ? strip._r / 2 : strip._r

            width:  strip._horizontal ? undefined        : strip._bodyDepth
            height: strip._horizontal ? strip._bodyDepth : undefined

            Repeater {
                model: strip._icons
                delegate: Item {
                    id: iconSlot
                    required property string modelData
                    required property int index

                    // Cluster icons around the bodyAxis-wide center so they
                    // stay put when iconArea grows for the panel.
                    readonly property int  _n:       strip._icons.length
                    readonly property real _axisLen: strip._horizontal ? iconArea.width : iconArea.height
                    readonly property real _cluster: (_axisLen - strip._bodyAxis) / 2
                    readonly property real _center:  _cluster + strip._bodyAxis * (index + 0.5) / Math.max(1, _n)

                    readonly property int _hitLong:  48
                    readonly property int _hitShort: strip._bodyDepth
                    width:  strip._horizontal ? _hitLong  : _hitShort
                    height: strip._horizontal ? _hitShort : _hitLong
                    x: strip._horizontal ? _center - width  / 2 : (iconArea.width  - width)  / 2
                    y: strip._horizontal ? (iconArea.height - height) / 2 : _center - height / 2

                    WidgetLoader {
                        anchors.fill: parent
                        widgetId: iconSlot.modelData
                        holderRoot: strip
                        // Sprint 26 — resolve this icon's per-instance config by
                        // position (strip icons are keyed by index, not a diffed
                        // ListModel). Reactive on ShellConfig.data.
                        config: {
                            var e = ShellServices.ShellConfig.stripEntries(strip.side, strip._screenName)
                            return (e[iconSlot.index] && e[iconSlot.index].config) || ({})
                        }
                    }
                }
            }
        }
    }
}
