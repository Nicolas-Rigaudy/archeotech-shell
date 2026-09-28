import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives" as Prim
import "../../../Services/Shell" as ShellServices
import "../../../Widgets/Bar" as BarWidgets

// Bar — a side container that hosts widgets driven by shell-config.json.
// Three zones on horizontal bars (left / center / right) each mount a
// Repeater of WidgetLoader, resolving widget ids via WidgetRegistry's
// filename convention (Widgets/Bar/<PascalId>Widget.qml).
//
// Bar owns the popup state (hover info, calendar, WiFi, BT) — widgets
// flip these properties through the holderRoot API. Popup components live
// in Widgets/Bar/*Popup.qml and read state directly from holderRoot.
//
// Vertical side bars still inline a simplified icon Column for now.
// Widget-aware vertical layouts arrive in a later sprint.
Item {
    id: bar

    required property string side
    required property var screen

    readonly property bool   horizontal: side === "top" || side === "bottom"
    readonly property bool   _isTop:     side === "top"
    readonly property bool   _isBottom:  side === "bottom"
    readonly property bool   _isLeft:    side === "left"
    readonly property bool   _isRight:   side === "right"
    readonly property int    thickness:  Commons.Appearance.bar.height
    readonly property string _screenName: screen ? screen.name : ""

    // Auto-hide / force-hide (item_015): the bar vanishes and reserves no space
    // in fullscreen / force-hide, reappearing on exit. (A bar has no hover-peek
    // like a strip's holder — it simply hides; no new collapsed chrome.)
    readonly property bool _hidden: ShellServices.ShellState.sidesHidden(_screenName)
    visible: !_hidden
    implicitWidth:  _hidden ? 0 : (horizontal ? 0 : thickness)
    implicitHeight: _hidden ? 0 : (horizontal ? thickness : 0)

    // Live widths of the non-title left-zone widgets, reported by their loaders
    // (see the left Repeater delegate). Used to size the title so the left
    // cluster can't slide under the centered clock.
    property real _wsWidth:    0
    property real _mediaWidth: 0

    // Fixed console-seam geometry: the bar splits into three sections at seams
    // anchored to the bar CENTRE ± a fixed fraction — content-independent, so the
    // seams never move as widgets resize. Middle section a touch smaller than the
    // sides (the clock is narrow). See _dividers.
    readonly property real _seamHalf:   pill.width * 0.14   // ½ the middle section (≈28% of the bar)
    readonly property real _leftSeamX:  pill.width / 2 - _seamHalf
    readonly property real _rightSeamX: pill.width / 2 + _seamHalf

    // Max width the title may take: the left cluster (workspaces + title + media)
    // must stay left of the left seam (console) / short of the centred clock
    // (base). The title caps its own implicit width to this and elides — no Layout
    // clamps (those stretched the zone).
    readonly property real _titleMaxWidth: bar._segmentsActive
        ? Math.max(60, _leftSeamX - _consoleInset - _wsWidth - _mediaWidth - 14)
        : Math.max(60, pill.width / 2 - _centerRow.width / 2
            - Commons.Appearance.bar.innerPadding - _wsWidth - _mediaWidth - 16)

    // ── Popup state (read/written by widgets via holderRoot) ──────────────────────
    property real    _popupAnchorX:   0
    property string  _popupLabel:     ""
    property string  _popupPrimary:   ""
    property string  _popupSecondary: ""
    property string  _popupHint:      ""
    property bool    _popupVisible:   false
    property real    _lastShowTime:   0
    property var     _popupOwner:     null

    property bool _calendarVisible:  false
    property int  _calendarYear:     new Date().getFullYear()
    property int  _calendarMonth:    new Date().getMonth() + 1

    property bool _wifiPopupVisible: false
    property bool _btPopupVisible:   false
    property real _wifiAnchorX:      0
    property real _btAnchorX:        0

    // Along-axis center (bar-local) of the panel-opener that was last clicked,
    // so a bar-hosted panel drops anchored under it. -1 = unset → bar center.
    property real _panelAnchor: -1

    // ── Bar-popup input region (consumed by ShellSurface's input mask) ──────────
    // The popup cards float BELOW the bar, outside the SideLoader rect that the
    // surface mask covers — without this, clicks on them pass straight through to
    // the windows behind. We expose the union bounding box (bar-local coords) of
    // every visible popup; ShellSurface mirrors it into a mask region. Ids are
    // resolved at component scope, so referencing the popups declared further
    // down is fine.
    readonly property bool _anyPopupOpen:
        _hoverCardPopup.visible || _calendarPopup.visible
        || _wifiPopup.visible   || _btPopup.visible || _barPanel.visible
    readonly property rect _popupBounds: {
        var ps = [_hoverCardPopup, _calendarPopup, _wifiPopup, _btPopup, _barPanel]
        var l = 1e9, t = 1e9, r = -1e9, b = -1e9, any = false
        for (var i = 0; i < ps.length; i++) {
            if (!ps[i].visible) continue
            any = true
            l = Math.min(l, ps[i].x); t = Math.min(t, ps[i].y)
            r = Math.max(r, ps[i].x + ps[i].width); b = Math.max(b, ps[i].y + ps[i].height)
        }
        return any ? Qt.rect(l, t, r - l, b - t) : Qt.rect(0, 0, 0, 0)
    }

    // ── holderRoot API surface ─────────────────────────────────────────────────────
    function showPopup(item, label, primary, secondary, hint) {
        // A pinned control popup (WiFi/BT) owns the screen — never raise a hover
        // status card while one is open (it would render behind it). This makes
        // the hover card and the click popups mutually exclusive: one slot only.
        if (_wifiPopupVisible || _btPopupVisible) return
        _hideTimer.stop()
        _calHideTimer.stop()
        _calendarVisible = false
        _lastShowTime = Date.now()
        _popupOwner   = item
        var pt = item.mapToItem(bar, item.width / 2, 0)
        _popupAnchorX   = pt.x
        _popupLabel     = label
        _popupPrimary   = primary
        _popupSecondary = secondary || ""
        _popupHint      = hint || ""
        _popupVisible   = true
    }
    // caller === undefined means a popup card itself is hiding (always allowed).
    // caller !== _popupOwner means a stale onExited from the previous icon — ignore.
    function hidePopup(caller) {
        if (caller === undefined || caller === _popupOwner) _hideTimer.restart()
    }
    function hideCalendar(caller) { _calHideTimer.restart() }
    function keepPopupsAlive() {
        _hideTimer.stop()
        _calHideTimer.stop()
        _popupVisible = false
    }

    // ── holderRoot contract (Sprint 26-C phase 4) ──────────────────────────────
    // The superset API a bar and a strip both expose, so one opener widget runs
    // on either. Bars implement the panel/popup half; the hover-reveal hooks are
    // no-ops (a bar has no hover-reveal card).
    readonly property string type:       "bar"
    readonly property string screenName: _screenName
    // Toggle a panel; record where it should drop from (the opener's along-axis
    // center) so BarPanel anchors under it. sideArg "" = wildcard (bar gear).
    function togglePanel(id, sideArg, anchor) {
        if (anchor !== undefined) _panelAnchor = anchor
        ShellServices.ShellState.toggleGlobal(id, sideArg || "")
    }
    function dismissPopups() { _wifiPopupVisible = false; _btPopupVisible = false }
    // A bar opener is active when its panel is open on THIS bar's side.
    function showsPanel(id) {
        return ShellServices.ShellState.activePanel(_screenName) === id
            && ShellServices.ShellState.activeSide(_screenName) === side
    }
    function iconHoverEnter() {}
    function iconHoverExit()  {}

    Timer { id: _hideTimer;    interval: 250; onTriggered: bar._popupVisible    = false }
    Timer { id: _calHideTimer; interval: 250; onTriggered: bar._calendarVisible = false }

    // ── Stable ListModels for each zone ────────────────────────────────────────
    // HyprPanel's preserve-delegates pattern. When shell-config.json changes,
    // _syncZone() does an in-place add/remove/move diff on the ListModel so
    // unchanged widgets (e.g. MPRIS marquee mid-scroll) keep their state.
    // A plain `model: <jsArray>` Repeater would destroy + recreate everything.
    ListModel { id: _leftModel }
    ListModel { id: _centerModel }
    ListModel { id: _rightModel }

    // Sprint 26 — entries are { id, config }. We key each row on a stable
    // `instanceKey` = id + "#" + occurrence so two same-id widgets (e.g. two
    // clocks) keep distinct delegates. Config rides as a JSON string
    // (`configJson`) — ListModel mangles nested object roles; the delegate
    // JSON.parses it. Updating config on an existing row is setProperty in
    // place, so the widget instance survives an edit (no reload).
    // ponytail: reordering two same-id widgets recreates the moved delegate
    // (its occurrence changes) — cheap; revisit only if it visibly flickers.
    function _syncZone(model, entries) {
        var rows = []
        var seen = {}
        for (var i = 0; i < entries.length; i++) {
            var id  = entries[i].id
            var occ = seen[id] === undefined ? 0 : seen[id] + 1
            seen[id] = occ
            rows.push({ widgetId: id, instanceKey: id + "#" + occ,
                        configJson: JSON.stringify(entries[i].config || {}) })
        }
        // Remove keys no longer present.
        var newSet = {}
        for (var j = 0; j < rows.length; j++) newSet[rows[j].instanceKey] = true
        for (var k = model.count - 1; k >= 0; k--) {
            if (!newSet[model.get(k).instanceKey]) model.remove(k)
        }
        // Insert / move / update-config so model order matches rows.
        for (var m = 0; m < rows.length; m++) {
            var r = rows[m]
            var currentIdx = -1
            for (var n = m; n < model.count; n++) {
                if (model.get(n).instanceKey === r.instanceKey) { currentIdx = n; break }
            }
            if (currentIdx === -1) {
                model.insert(m, r)
            } else {
                if (currentIdx !== m) model.move(currentIdx, m, 1)
                if (model.get(m).configJson !== r.configJson)
                    model.setProperty(m, "configJson", r.configJson)
            }
        }
    }

    function _syncAllZones() {
        _syncZone(_leftModel,   ShellServices.ShellConfig.zoneEntries(bar.side, "left",   bar._screenName))
        _syncZone(_centerModel, ShellServices.ShellConfig.zoneEntries(bar.side, "center", bar._screenName))
        _syncZone(_rightModel,  ShellServices.ShellConfig.zoneEntries(bar.side, "right",  bar._screenName))
    }

    Component.onCompleted: _syncAllZones()
    Connections {
        target: ShellServices.ShellConfig
        function onDataChanged() { bar._syncAllZones() }
    }

    // Console instrument segments (pack console, item_083): pill-local {x,w} for
    // each functional group (left cluster / centre gauge / right status bank) so
    // each can get a bordered housing. Empty unless the pack sets bar.dividers.
    // The main RowLayout fills the pill inset by innerPadding, so the left group
    // starts at innerPadding and the right group ends at pill.width-innerPadding.
    // Console (item_083): the whole top bar is ONE recessed instrument panel
    // (Legion register — not three floating boxes), with vertical seam dividers
    // at the boundaries between the functional zones (left cluster | centre gauge
    // | right bank). Empty unless the pack sets bar.dividers.
    readonly property bool _consoleOn: Commons.Appearance.bar.dividers && bar.horizontal
    // Steel pack: the console is expressed as per-cluster bolted BarSegments
    // (workspaces / media / clock, + the right status bank below), so the old
    // standalone seam dividers are suppressed — the panels do the dividing.
    readonly property bool _segmentsActive: _consoleOn && Commons.Appearance.frameChamfer
    readonly property real _consoleInset: Commons.Appearance.bar.innerPadding + 12
    // Two fixed full-height seams splitting the bar into three sections. Anchored
    // to the bar centre (± _seamHalf), so they never move as content resizes.
    readonly property var _dividers: _consoleOn
        ? [Math.round(_leftSeamX), Math.round(_rightSeamX)]
        : []

    // ── Pill — anchored to the bar's outer edge ────────────────────────────────
    Rectangle {
        id: pill
        z: 1
        // Transparent — the unified FrameBackground (ShellSurface) draws the
        // resting glass for every side + the shared rounded/capped corners (S22).
        // This pill only positions/hosts the bar widgets.
        color: "transparent"

        anchors.top:    bar._isBottom ? undefined : parent.top
        anchors.bottom: bar._isTop    ? undefined : parent.bottom
        anchors.left:   bar._isRight  ? undefined : parent.left
        anchors.right:  bar._isLeft   ? undefined : parent.right

        anchors.topMargin:    Commons.Appearance.bar.marginTop
        anchors.bottomMargin: Commons.Appearance.bar.marginTop
        anchors.leftMargin:   Commons.Appearance.bar.marginSide
        anchors.rightMargin:  Commons.Appearance.bar.marginSide

        width:  bar.thickness
        height: bar.thickness

        // ── Horizontal layout — LEFT | filler | RIGHT in a RowLayout,
        //    CENTER absolutely centered (overlay so widget widths in
        //    left/right zones don't push the clock off-center).
        RowLayout {
            visible: bar.horizontal
            anchors.fill: parent
            // Extra inset when the console plate is on, so the zone content clears
            // the plate's corner-bolt fittings (they were overlapping workspaces).
            anchors.leftMargin:  Commons.Appearance.bar.innerPadding + (bar._consoleOn ? 12 : 0)
            anchors.rightMargin: Commons.Appearance.bar.innerPadding + (bar._consoleOn ? 12 : 0)
            spacing: 0

            // LEFT zone
            RowLayout {
                id: _leftGroup
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Repeater {
                    id: _leftZone
                    model: bar.horizontal ? _leftModel : null
                    delegate: WidgetLoader {
                        // Qt 6.11.1 stopped auto-binding ListModel roles to
                        // a delegate's *inherited* required properties; we
                        // pass widgetId explicitly via `model.widgetId`.
                        required property var model
                        required property int index
                        widgetId: model ? model.widgetId : ""
                        holderRoot:  bar
                        config:   (model && model.configJson) ? JSON.parse(model.configJson) : ({})
                        isFirst:  index === 0
                        isLast:   index === _leftZone.count - 1
                        // Report the non-title widths up so the title can size
                        // itself to never reach the clock (see bar._titleMaxWidth).
                        onWidthChanged: {
                            if (widgetId === "workspaces") bar._wsWidth    = width
                            else if (widgetId === "media")  bar._mediaWidth = width
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // RIGHT zone
            RowLayout {
                id: _rightGroup
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Repeater {
                    id: _rightZone
                    model: bar.horizontal ? _rightModel : null
                    delegate: WidgetLoader {
                        required property var model
                        required property int index
                        widgetId: model ? model.widgetId : ""
                        holderRoot:  bar
                        config:   (model && model.configJson) ? JSON.parse(model.configJson) : ({})
                        isFirst:  index === 0
                        isLast:   index === _rightZone.count - 1
                    }
                }
            }
        }

        // CENTER zone — overlay, absolutely centered. z above the RowLayout
        // so the clock isn't pushed when the left/right zone widths change.
        Row {
            id: _centerRow
            visible: bar.horizontal
            anchors.centerIn: parent
            z: 2
            spacing: 0
            Repeater {
                id: _centerZone
                model: bar.horizontal ? _centerModel : null
                delegate: WidgetLoader {
                    required property var model
                    required property int index
                    widgetId: model ? model.widgetId : ""
                    holderRoot:  bar
                    config:   (model && model.configJson) ? JSON.parse(model.configJson) : ({})
                    isFirst:  index === 0
                    isLast:   index === _centerZone.count - 1
                }
            }
        }

        // ── Console instrument panel (pack console, item_083) ───────────────────
        // The WHOLE top bar is one recessed steel instrument panel (Legion
        // register): a single console face spanning the bar, copper corner-bolt
        // fittings, and vertical seam dividers (bevel groove + bolt-pair) at the
        // boundaries between the functional zones — NOT three floating boxes.
        // z:-1 keeps it behind the widgets, which sit in it as readouts. Base
        // look: dividers=false → _consoleOn false → nothing drawn.
        Item {
            id: _console
            visible: bar._consoleOn
            z: -1
            anchors.fill: parent
            readonly property string _pack:  Commons.Appearance.activePackDir
            readonly property string _rivet: _pack === "" ? "" : "file://" + _pack + "panels/rivet.png"

            // The bar FACE is drawn by FrameFx as the top band of the one brushed
            // chassis (full width, behind these widgets) — so the bar itself only
            // adds the zone dividers here; no separate plate (that inset gap/seam
            // is why the bar looked cut off from the screen edge).
            Repeater {                                  // zone dividers — recessed groove between two
                model: bar._dividers                     // seams anchor the boxes (kept even with segments on)
                delegate: Item {                         // full-height connector — same seam as before, now
                    x: modelData; y: 0; height: parent.height   // spanning top→bottom to connect the bar edges.
                    Rectangle { x: 0; width: 1; height: parent.height; color: Qt.rgba(0, 0, 0, 0.55) }
                    Rectangle { x: 1; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.06) }
                    // rivets inset from the bar edges so they clear the frame bezel
                    // (the groove still runs edge-to-edge). 4px top/bottom.
                    // left-plate rivets
                    Image { source: _console._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: -9; y: 4 }
                    Image { source: _console._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: -9; y: parent.height - 11 }
                    // right-plate rivets
                    Image { source: _console._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: 3; y: 4 }
                    Image { source: _console._rivet; width: 7; height: 7; sourceSize: Qt.size(14, 14); smooth: true; x: 3; y: parent.height - 11 }
                }
            }

            // Right status bank — the whole cluster of system indicators housed as
            // ONE bolted segment (a "status panel"), not one box per icon. Sized to
            // the live _rightGroup; it ends at pill.width - the console inset, so its
            // left edge = that minus its width. 10px pad each side clears the icons.
            Prim.BarSegment {
                visible: bar._segmentsActive && _rightGroup.width > 4
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: pill.width - bar._consoleInset - _rightGroup.width - 10
                width: _rightGroup.width + 20
            }
        }

        // ── Vertical layout (left/right side bars) — config-driven zones,
        //    same ListModels as horizontal (left→top, right→bottom, center→
        //    middle overlay). Widgets render their icon-only form via BarPill
        //    (S26-C), so a vertical bar is now fully configurable like the top
        //    bar — no more hardcoded icon column.
        //    Each orientation's Repeaters only get a model while that orientation
        //    is active: hiding the inactive one with `visible` alone still
        //    instantiated every widget twice.
        ColumnLayout {
            visible: !bar.horizontal
            anchors.fill: parent
            anchors.topMargin:    Commons.Appearance.bar.innerPadding
            anchors.bottomMargin: Commons.Appearance.bar.innerPadding
            spacing: 0

            // TOP zone
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: bar.horizontal ? null : _leftModel
                    delegate: WidgetLoader {
                        required property var model
                        required property int index
                        widgetId: model ? model.widgetId : ""
                        holderRoot:  bar
                        config:   (model && model.configJson) ? JSON.parse(model.configJson) : ({})
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // BOTTOM zone
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: bar.horizontal ? null : _rightModel
                    delegate: WidgetLoader {
                        required property var model
                        required property int index
                        widgetId: model ? model.widgetId : ""
                        holderRoot:  bar
                        config:   (model && model.configJson) ? JSON.parse(model.configJson) : ({})
                    }
                }
            }
        }

        // CENTER zone (vertical) — absolutely centered overlay, mirrors the
        // horizontal center Row so zone widths don't shift it.
        Column {
            visible: !bar.horizontal
            anchors.centerIn: parent
            z: 2
            spacing: 8
            Repeater {
                model: bar.horizontal ? null : _centerModel
                delegate: WidgetLoader {
                    required property var model
                    required property int index
                    widgetId: model ? model.widgetId : ""
                    holderRoot:  bar
                    config:   (model && model.configJson) ? JSON.parse(model.configJson) : ({})
                }
            }
        }
    }

    // ── Popup overlays — single instance, persistent ───────────────────────────
    BarWidgets.HoverCard     { id: _hoverCardPopup; holderRoot: bar }
    BarWidgets.CalendarPopup { id: _calendarPopup;  holderRoot: bar }
    BarWidgets.WifiPopup     { id: _wifiPopup;       holderRoot: bar }
    BarWidgets.BtPopup       { id: _btPopup;         holderRoot: bar }
    BarWidgets.BarPanel      { id: _barPanel;        holderRoot: bar }
}
