import Quickshell
import Quickshell.Wayland
import QtQuick
import "Sides" as Sides
import "Panels" as Panels
import "Builder" as Builder
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices

// Sprint 17 Stage 4 — one full-screen overlay PanelWindow per monitor.
// Hosts the 4 sides (Bar/Strip/none via SideLoader) + a single FrameBackground
// that draws the resting glass for every side and their shared rounded corners.
//
// Input passthrough = QsWindow.mask covering only the side/corner regions
// (the only reliable API — see ANALYSIS.md §15). Keyboard focus is Exclusive
// when a panel is open on this screen, None otherwise.
//
// Compositor exclusiveZone is reserved by separate thin ShellExclusions
// windows — this surface is ExclusionMode.Ignore.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: _surface
        required property var modelData

        readonly property string _screenName: modelData ? modelData.name : ""

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "archeotech-shell"
        // Exclusive focus when a panel is open OR edit mode is active (so the
        // EditOverlay receives Escape and the palette is interactive).
        WlrLayershell.keyboardFocus: (ShellServices.ShellState.anyOpen(_screenName) || Commons.State.editMode)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        // Mask = union of the 4 side regions + (when any panel is open) a
        // full-surface region for click-outside-to-close + (in edit mode) a
        // full-surface region so the editor is interactive. Inactive sides
        // collapse to 0×0 so they contribute nothing. The FrameBackground corner
        // fills are decorative (not masked → clicks there pass through).
        mask: Region {
            Region { item: _topSide }
            Region { item: _bottomSide }
            Region { item: _rightSide }
            Region { item: _leftSide }
            Region { item: _panelOpenMask }
            Region { item: _editMask }
            Region { item: _topBarPopupMask }
            Region { item: _bottomBarPopupMask }
            Region { item: _leftBarPopupMask }
            Region { item: _rightBarPopupMask }
        }

        // Bar popups (hover/wifi/bt/calendar) AND bar-hosted panels float outside
        // the thin SideLoader rect — mirror each bar's union bounds here so clicks
        // land on them. One per side; collapses to 0×0 when that side isn't a bar
        // or has nothing open (strips lack _anyPopupOpen → _open stays false).
        // (S26-C generalised this from top-only to all four sides.)
        component BarPopupMask: Item {
            required property Item sideItem
            readonly property var  _bar:  sideItem.item
            readonly property bool _open: _bar && _bar._anyPopupOpen === true
            readonly property rect _b:    _open ? _bar._popupBounds : Qt.rect(0, 0, 0, 0)
            x: sideItem.x + _b.x
            y: sideItem.y + _b.y
            width:  _open ? _b.width  : 0
            height: _open ? _b.height : 0
        }
        BarPopupMask { id: _topBarPopupMask;    sideItem: _topSide }
        BarPopupMask { id: _bottomBarPopupMask; sideItem: _bottomSide }
        BarPopupMask { id: _leftBarPopupMask;   sideItem: _leftSide }
        BarPopupMask { id: _rightBarPopupMask;  sideItem: _rightSide }

        // Full-surface mask while editing so all of EditOverlay is clickable;
        // collapses to 0×0 otherwise.
        Item {
            id: _editMask
            x: 0; y: 0
            width:  Commons.State.editMode ? _surface.width  : 0
            height: Commons.State.editMode ? _surface.height : 0
        }

        // When any panel is open on this screen, _panelOpenMask covers the
        // whole surface so a click outside the strip/panel area can close it.
        // When no panel is open, it collapses to 0×0 and contributes nothing.
        Item {
            id: _panelOpenMask
            x: 0; y: 0
            width:  ShellServices.ShellState.anyOpen(_surface._screenName) ? _surface.width  : 0
            height: ShellServices.ShellState.anyOpen(_surface._screenName) ? _surface.height : 0

            // Click outside any side strip → close the active panel.
            TapHandler {
                enabled: ShellServices.ShellState.anyOpen(_surface._screenName)
                onTapped: point => {
                    function inside(s) {
                        return point.position.x >= s.x && point.position.x < s.x + s.width
                            && point.position.y >= s.y && point.position.y < s.y + s.height
                    }
                    if (!inside(_topSide) && !inside(_bottomSide)
                        && !inside(_leftSide) && !inside(_rightSide)
                        // A bar-hosted panel lives outside its side's rect — its
                        // bounds are in the bar-popup masks; treat those as inside
                        // so clicking the panel doesn't close it.
                        && !inside(_topBarPopupMask) && !inside(_bottomBarPopupMask)
                        && !inside(_leftBarPopupMask) && !inside(_rightBarPopupMask)) {
                        // Global close — clicking outside on one screen dismisses
                        // the panel on every screen.
                        ShellServices.ShellState.closeAllAcross()
                    }
                }
            }
        }

        // Static collapsed sizes — drive corner-gap margins. The live
        // SideLoader widths can grow during strip hover, but the gap for
        // corner pieces stays at the collapsed size so the corner geometry
        // doesn't reflow and the bar pill doesn't shift.
        readonly property int _topGap:    ShellServices.ShellConfig.sideGap("top",    _screenName)
        readonly property int _bottomGap: ShellServices.ShellConfig.sideGap("bottom", _screenName)
        readonly property int _leftGap:   ShellServices.ShellConfig.sideGap("left",   _screenName)
        readonly property int _rightGap:  ShellServices.ShellConfig.sideGap("right",  _screenName)

        // Extended corner geometry — each corner piece extends `_r` pixels into
        // the adjacent bar/strip areas so a single concave arc (radius _r) can
        // span from the bar's edge to the strip's edge with smooth tangents.
        readonly property int _r: ShellServices.ShellConfig.cornerRadius()

        // Pill mode (S22): the whole frame floats inward by `_pillGap`.
        readonly property bool _pillMode: ShellServices.ShellConfig.pillMode()
        readonly property int  _pillGap:  ShellServices.ShellConfig.pillGap()
        readonly property int  _off:      _pillMode ? _pillGap : 0

        // ── Frame background (S22) ──────────────────────────────────────────────
        // Single Shape drawing the glass for all active sides + their shared
        // dynamic rounded inner corners. The Bar/Strip Items above are transparent
        // and only host widgets; this owns the resting frame fill. z:0 — under the
        // sides (z:10) so widgets/icons sit on top.
        FrameBackground {
            z: 0
            anchors.fill: parent
            screenName: _surface._screenName
        }

        // ── Sides ─────────────────────────────────────────────────────────────
        // Transparent containers anchored to each edge; they position widgets/
        // icons over the FrameBackground glass. Inset by `neighbourGap + _r` at a
        // joined end (keeps content off the strip column / corner) and by `_off`
        // at the outer edge. z: 10 — above panels (z:5) so strips stay visible and
        // interactive when a panel is open. Margins animate so switches glide.
        Sides.SideLoader {
            id: _topSide
            z: 10
            side: "top"
            screen: _surface.modelData
            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                topMargin:   _surface._off
                // Bar widgets only need to clear the neighbour strip column, not
                // the corner-radius fillet (they're vertically centred, well clear
                // of the curve) — so no `+ _r` here. Lets the icons sit close to the
                // corners while the FrameBackground glass/corners stay untouched.
                leftMargin:  _surface._off + (_surface._leftGap  > 0 ? _surface._leftGap  : 0)
                rightMargin: _surface._off + (_surface._rightGap > 0 ? _surface._rightGap : 0)
            }
            Behavior on anchors.topMargin   { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin  { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
        }

        Sides.SideLoader {
            id: _bottomSide
            z: 10
            side: "bottom"
            screen: _surface.modelData
            anchors {
                bottom: parent.bottom
                left:   parent.left
                right:  parent.right
                bottomMargin: _surface._off
                leftMargin:   _surface._off + (_surface._leftGap  > 0 ? _surface._leftGap  + _surface._r : 0)
                rightMargin:  _surface._off + (_surface._rightGap > 0 ? _surface._rightGap + _surface._r : 0)
            }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin   { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin  { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
        }

        Sides.SideLoader {
            id: _rightSide
            z: 10
            side: "right"
            screen: _surface.modelData
            anchors {
                top:    parent.top
                bottom: parent.bottom
                right:  parent.right
                rightMargin:  _surface._off
                topMargin:    _surface._off + (_surface._topGap    > 0 ? _surface._topGap    + _surface._r : 0)
                bottomMargin: _surface._off + (_surface._bottomGap > 0 ? _surface._bottomGap + _surface._r : 0)
            }
            Behavior on anchors.rightMargin  { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin    { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
        }

        Sides.SideLoader {
            id: _leftSide
            z: 10
            side: "left"
            screen: _surface.modelData
            anchors {
                top:    parent.top
                bottom: parent.bottom
                left:   parent.left
                leftMargin:   _surface._off
                topMargin:    _surface._off + (_surface._topGap    > 0 ? _surface._topGap    + _surface._r : 0)
                bottomMargin: _surface._off + (_surface._bottomGap > 0 ? _surface._bottomGap + _surface._r : 0)
            }
            Behavior on anchors.leftMargin   { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin    { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: Commons.Appearance.anim.panel; easing.type: Easing.OutCubic } }
        }

        // Corner blends removed (S22) — the FrameBackground above now draws all
        // junctions as one continuous fill with dynamic rounded inner corners.

        // ── Panels ────────────────────────────────────────────────────────────
        // Sprint 17 → S5 update: panels are now rendered INSIDE the Strip
        // popup card (Sides/Strip.qml). The strip's card grows from popup-size
        // to panel-size on activation, with the icons staying as a sidebar at
        // the strip-attached edge so the user can switch between panels (e.g.
        // CC ↔ NC) without losing them. Panels.Panel is no longer instantiated
        // here; PanelRegistry remains the source of truth for content + size.

        // ── Edit mode (Sprint 21) ──────────────────────────────────────────────
        // Full-surface visual builder, above everything. Visible only when
        // State.editMode; reads/writes ShellConfig (live shell hot-reloads).
        Builder.EditOverlay {
            z: 30
            anchors.fill: parent
        }
    }
}
