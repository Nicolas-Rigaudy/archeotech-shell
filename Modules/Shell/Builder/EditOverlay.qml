import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices
import "../../Settings/Widgets" as SettingsWidgets

// Sprint 21 — visual builder edit mode.
//
// A full-surface editor shown inside every ShellSurface when State.editMode is
// true. It never touches the live Bar/Strip items: it reads ShellConfig and
// renders an abstract, editable map of the four screen edges. Every edit goes
// through ShellConfig's mutators → shell-config.json is rewritten → the live
// shell hot-reloads (Bar/Strip re-sync from config), so the user watches the
// real shell reconfigure underneath the dimmed editor.
//
// Edits apply to the global side config (per-screen overrides are a later
// refinement). v1 shows the same editor on every monitor.
Item {
    id: editOverlay
    anchors.fill: parent
    visible: Commons.State.editMode
    z: 100

    focus: visible
    Keys.onEscapePressed: Commons.State.editMode = false

    // Re-scan installed modules each time the editor opens so freshly-dropped
    // folders appear in the palette without a shell restart.
    onVisibleChanged: {
        if (visible) ShellServices.ModuleRegistry.rescan()
        else if (Commons.State.dragActive) endDrag()   // task_027 — cancel a mid-drag close
    }

    readonly property var _cfg:  ShellServices.ShellConfig
    readonly property var _reg:  ShellServices.WidgetRegistry
    readonly property var _mods: ShellServices.ModuleRegistry

    readonly property int _pad: Commons.Appearance.spacing.lg

    // ── Config helpers (zone "" = strip/holder icon list) ───────────────────────
    function _zonesFor(side) {
        var t = _cfg.sideType(side)
        if (t === "bar") return ["left", "center", "right"]
        if (t === "strip" || t === "holder") return [""]
        return []
    }
    // Sprint 26 — the builder works with { id, config } entries throughout so
    // per-instance config survives reorder/remove (splicing ids would drop it).
    function _list(side, zone) {
        return zone !== "" ? _cfg.zoneEntries(side, zone) : _cfg.stripEntries(side)
    }
    function _write(side, zone, entries) {
        if (zone !== "") _cfg.setZoneWidgets(side, zone, entries)
        else             _cfg.setStripIcons(side, entries)
    }
    function _meta(zone, id) {
        if (_reg.isPlugin(id)) {
            var m = _mods.moduleFor(id)
            return { id: id, name: (m && m.name) || id, icon: (m && m.icon) || "󰏗" }
        }
        return zone !== "" ? _reg.barWidgetMeta(id) : _reg.stripIconMeta(id)
    }
    function addId(side, zone, id) {
        var l = _list(side, zone).slice(); l.push({ id: id, config: {} }); _write(side, zone, l)
    }
    function removeAt(side, zone, idx) {
        var l = _list(side, zone).slice(); l.splice(idx, 1); _write(side, zone, l)
    }
    function moveBy(side, zone, idx, d) {
        var l = _list(side, zone).slice()
        var j = idx + d
        if (j < 0 || j >= l.length) return
        var t = l[idx]; l[idx] = l[j]; l[j] = t
        _write(side, zone, l)
    }
    function _label(s) { return s.charAt(0).toUpperCase() + s.slice(1) }

    // configSchema for an id — built-in from WidgetRegistry, plugin from its
    // module.json. Drives the per-chip config gear (shown only when non-empty).
    function _schemaFor(id) {
        if (_reg.isPlugin(id)) {
            var m = _mods.moduleFor(id)
            return (m && m.configSchema) ? m.configSchema : {}
        }
        return _reg.configSchemaFor(id)
    }
    function _hasConfig(id) {
        var s = _schemaFor(id)
        return !!s && Object.keys(s).length > 0
    }

    // ── Per-instance config popup state ─────────────────────────────────────────
    property bool   _cfgOpen:  false
    property string _cfgSide:  ""
    property string _cfgZone:  ""
    property int    _cfgIndex: -1
    property string _cfgId:    ""
    function openConfig(side, zone, index, id) {
        _cfgSide = side; _cfgZone = zone; _cfgIndex = index; _cfgId = id; _cfgOpen = true
    }
    function _currentConfig() {
        var l = _list(_cfgSide, _cfgZone)
        return (l[_cfgIndex] && l[_cfgIndex].config) || ({})
    }

    // ── Drag-and-drop state (task_027 / adr_028) ────────────────────────────────
    // Pointer DnD of chips across the four side-cards, all inside this one surface
    // (intra-surface, so Qt Drag/DropArea are reliable). The dragged chip stays put
    // in its Flow; a floating ghost image follows the cursor and an invisible
    // `dragProxy` carries Drag.active so the per-zone DropAreas track it. On drop we
    // rewrite config via ShellConfig.moveEntry (one hot-reload). Arrows + palette
    // stay as the keyboard-accessible path — this is additive.
    property string _dropSide:  ""      // zone currently under the cursor …
    property string _dropZone:  ""
    property int    _dropIndex: -1      // … and the insertion slot within it
    property bool   _dropValid: false   // does the move convert to a valid entry?

    function _entryConfigAt(side, zone, index) {
        var l = _list(side, zone)
        return (l[index] && l[index].config) || ({})
    }
    function _srcParts() {
        var s = Commons.State.draggedSource.split(":")
        return { side: s[0], zone: (s[1] === undefined ? "" : s[1]), index: parseInt(s[2]) }
    }
    // Would dropping the in-flight chip into (destZone-flavour) be accepted? Used
    // by DropAreas to light a valid/invalid affordance before the drop lands.
    function _dropConverts(destZone) {
        if (!Commons.State.dragActive) return false
        var src = _srcParts()
        return _cfg.moveConversion(src.zone, destZone, Commons.State.draggedKey,
                                   _entryConfigAt(src.side, src.zone, src.index)) !== null
    }

    function beginDrag(side, zone, index, id, chipItem) {
        Commons.State.draggedSource = side + ":" + zone + ":" + index
        Commons.State.draggedKey    = id
        var p = chipItem.mapToItem(editOverlay, 0, 0)
        dragProxy.width = chipItem.width; dragProxy.height = chipItem.height
        dragProxy.x = p.x; dragProxy.y = p.y
        ghost.width = chipItem.width; ghost.height = chipItem.height
        ghost.x = p.x; ghost.y = p.y
        chipItem.grabToImage(function(res) { ghost.source = res.url })
        Commons.State.dragActive = true
        dragProxy.Drag.active = true
    }
    function moveDrag(gx, gy) {
        dragProxy.x = gx - dragProxy.width / 2
        dragProxy.y = gy - dragProxy.height / 2
        ghost.x = dragProxy.x; ghost.y = dragProxy.y
    }
    function endDrag() {
        if (Commons.State.dragActive) dragProxy.Drag.drop()   // fires onDropped on the hovered zone
        dragProxy.Drag.active = false
        Commons.State.dragActive    = false
        Commons.State.draggedKey    = ""
        Commons.State.draggedSource = ""
        ghost.source = ""
        _dropSide = ""; _dropZone = ""; _dropIndex = -1; _dropValid = false
    }
    // Called from a zone's DropArea.onDropped. destIndex is the insertion slot as
    // seen among the *rendered* chips (source chip included); translate it to the
    // post-removal index moveEntry expects, then guard the no-op cases.
    function performDrop(destSide, destZone, destIndex) {
        var src = _srcParts()
        var cfg = _entryConfigAt(src.side, src.zone, src.index)
        if (_cfg.moveConversion(src.zone, destZone, Commons.State.draggedKey, cfg) === null) return
        var mDest = destIndex
        if (src.side === destSide && src.zone === destZone) {
            if (destIndex > src.index) mDest = destIndex - 1
            if (mDest === src.index) return          // dropped onto its own slot → no-op
        }
        _cfg.moveEntry(src.side, src.zone, src.index, destSide, destZone, mDest)
    }
    // Insertion index for a pointer at (px,py) in `flowItem` coords, walking the
    // chip Repeater in reading order (handles the Flow's row wrapping): the first
    // chip whose centre the pointer has passed, else the end.
    function _insertionIndex(rep, flowItem, px, py) {
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i)
            if (!it) continue
            var c = it.mapToItem(flowItem, it.width / 2, it.height / 2)
            if (py < c.y - it.height / 2) return i           // pointer is on an earlier row
            if (py <= c.y + it.height / 2 && px < c.x) return i   // same row, left of centre
        }
        return rep.count
    }

    // ── Palette state ───────────────────────────────────────────────────────────
    property string _palSide: ""
    property string _palZone: ""
    // Discovered modules accepting any of `targets`, as palette tiles.
    function _pluginTiles(targets) {
        var mods = _mods.modulesFor(targets)
        var out = []
        for (var i = 0; i < mods.length; i++)
            out.push({ id: "plugin:" + mods[i].id, name: mods[i].name || mods[i].id, icon: mods[i].icon || "󰏗" })
        return out
    }
    function openPalette(side, zone) {
        _palSide = side
        _palZone = zone
        // Bar zones take bar-zone modules; strips take strip-icon + panel-content.
        var base    = zone !== "" ? _reg.availableBarWidgets : _reg.availableStripIcons
        var plugins = _pluginTiles(zone !== "" ? ["bar-zone"] : ["strip-icon", "panel-content"])
        palette.items = base.concat(plugins)
        palette.title = "Add to " + _label(side) + (zone !== "" ? " · " + zone : "")
        palette.visible = true
    }

    // ── Scrim — dims the live shell and swallows clicks so it isn't usable ──────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea { anchors.fill: parent }
    }

    // ── Banner ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: banner
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 16
        width: bannerRow.implicitWidth + 28
        height: 40
        radius: Commons.Appearance.radius.pill
        color: Commons.Appearance.colors.glassBg
        border.width: 1
        border.color: Commons.Appearance.colors.accentBorder

        Row {
            id: bannerRow
            anchors.centerIn: parent
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰏬  Edit Mode"
                color: Commons.Appearance.colors.accent
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.bold: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Drag chips to move · Esc to exit"
                color: Commons.Appearance.colors.subtext0
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeSm
            }
            // Frame style (S22): framed (hugs screen) ↔ pill (floating, rounded).
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool on: editOverlay._cfg.pillMode()
                width: _pillTxt.implicitWidth + 18; height: 26
                radius: Commons.Appearance.radius.sm
                color: on ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0
                border.width: 1
                border.color: on ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.glassBorder
                Text {
                    id: _pillTxt
                    anchors.centerIn: parent
                    text: parent.on ? "󰗖  Pill frame" : "󰝤  Framed"
                    color: parent.on ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext0
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editOverlay._cfg.setPillMode(!editOverlay._cfg.pillMode())
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: doneTxt.implicitWidth + 18; height: 26
                radius: Commons.Appearance.radius.sm
                color: _doneMa.containsMouse ? Commons.Appearance.colors.accent
                                             : Commons.Appearance.colors.accentAlpha
                Text {
                    id: doneTxt
                    anchors.centerIn: parent
                    text: "Done"
                    color: _doneMa.containsMouse ? Commons.Appearance.colors.crust
                                                 : Commons.Appearance.colors.accent
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.bold: true
                }
                MouseArea {
                    id: _doneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Commons.State.editMode = false
                }
            }
        }
    }

    // ── Side mocks — each edge drawn as its true bar/strip silhouette, pinned in
    // place (task_028 / item_097). Drop sections mirror the live Bar's layout:
    // left | center | right on a horizontal bar (left-anchored / centered /
    // right-anchored), the same three stacked on a vertical bar, and a single
    // lane for a strip/holder. Reuses the task_027 drag machinery unchanged. ──
    Repeater {
        model: ["top", "bottom", "left", "right"]
        delegate: Item {
            id: sideCard
            anchors.fill: parent
            required property string modelData
            readonly property string side: modelData
            readonly property bool   _horizontal: side === "top" || side === "bottom"
            readonly property string _type: editOverlay._cfg.sideType(side)
            readonly property bool   _isBar: _type === "bar"
            readonly property bool   _on:    _type !== "none"
            readonly property var    _zones: editOverlay._zonesFor(side)   // [l,c,r] | [""] | []
            readonly property int    _thick: !_on ? 22 : (_isBar ? 46 : 40)
            // A strip/holder is a pill sized to its icon count and centred on the
            // edge (like the live shell); a bar stretches the whole edge instead.
            readonly property int    _stripCount: (!_isBar && _on) ? editOverlay._list(side, "").length : 0
            readonly property int    _stripLen: Math.max(48, _stripCount * 30 + Math.max(0, _stripCount - 1) * 6 + 20)

            // Silhouette pinned to the edge: horizontal sides stretch L↔R and pin
            // top/bottom; vertical sides stretch T↔B and pin left/right. Ends are
            // inset so the four mocks read as a frame without overlapping corners.
            Rectangle {
                id: mock
                // Edge pin (cross-axis) is unconditional; along-axis a bar stretches
                // edge-to-edge, a strip/holder sizes to its icons (_stripLen) and
                // centres.
                anchors.top:    sideCard.side === "top"    ? parent.top
                              : ((!sideCard._horizontal && sideCard._isBar) ? parent.top : undefined)
                anchors.bottom: sideCard.side === "bottom" ? parent.bottom
                              : ((!sideCard._horizontal && sideCard._isBar) ? parent.bottom : undefined)
                anchors.left:   sideCard.side === "left"   ? parent.left
                              : ((sideCard._horizontal && sideCard._isBar) ? parent.left : undefined)
                anchors.right:  sideCard.side === "right"  ? parent.right
                              : ((sideCard._horizontal && sideCard._isBar) ? parent.right : undefined)
                anchors.horizontalCenter: (sideCard._horizontal && !sideCard._isBar) ? parent.horizontalCenter : undefined
                anchors.verticalCenter:   (!sideCard._horizontal && !sideCard._isBar) ? parent.verticalCenter : undefined
                anchors.leftMargin:   sideCard._horizontal ? 72 : 16
                anchors.rightMargin:  sideCard._horizontal ? 72 : 16
                anchors.topMargin:    sideCard.side === "top" ? 64 : 66
                anchors.bottomMargin: sideCard.side === "bottom" ? 16 : 60
                width:  sideCard._horizontal ? (sideCard._isBar ? undefined : sideCard._stripLen) : sideCard._thick
                height: sideCard._horizontal ? sideCard._thick : (sideCard._isBar ? undefined : sideCard._stripLen)
                radius: Commons.Appearance.radius.lg
                color:  Commons.Appearance.colors.glassBg
                opacity: sideCard._on ? 1 : 0.5
                border.width: 1
                border.color: Commons.Appearance.colors.glassBorder

                // "Off" hint on a disabled edge.
                Text {
                    visible: !sideCard._on
                    anchors.centerIn: parent
                    text: editOverlay._label(sideCard.side) + " · Off"
                    color: Commons.Appearance.colors.overlay1
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                }

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: sideCard._horizontal ? 6 : 5

                    // Faint seams between the three bar sections (echoes the console).
                    Repeater {
                        model: (sideCard._isBar && sideCard._zones.length === 3) ? 2 : 0
                        delegate: Rectangle {
                            required property int index
                            color: Commons.Appearance.colors.glassBorder
                            opacity: 0.5
                            width:  sideCard._horizontal ? 1 : parent.width
                            height: sideCard._horizontal ? parent.height : 1
                            x: sideCard._horizontal ? Math.round(parent.width  * (index + 1) / 3) : 0
                            y: sideCard._horizontal ? 0 : Math.round(parent.height * (index + 1) / 3)
                        }
                    }

                    // One drop section per zone, each an equal band of the content.
                    Repeater {
                        model: sideCard._zones
                        delegate: Item {
                            id: section
                            required property string modelData
                            required property int index
                            readonly property string zoneName: modelData
                            readonly property int _n: sideCard._zones.length
                            // A strip/holder lane ("") centres its icons along the
                            // axis, matching the live Strip (icons cluster around the
                            // strip centre); bar zones keep left / centre / right.
                            readonly property bool _isStart:  zoneName === "left"
                            readonly property bool _isCenter: zoneName === "center" || zoneName === ""
                            readonly property bool _isEnd:    zoneName === "right"

                            // Centre section paints above its siblings so a cramped
                            // right cluster can't occlude the centred widget (the
                            // right section is a later sibling; lane-local z alone
                            // wouldn't lift it across sections).
                            z: _isCenter ? 2 : 1

                            width:  sideCard._horizontal ? content.width / _n : content.width
                            height: sideCard._horizontal ? content.height : content.height / _n
                            x: sideCard._horizontal ? index * (content.width / _n) : 0
                            y: sideCard._horizontal ? 0 : index * (content.height / _n)

                            // Chip lane, aligned within the band exactly like the live bar.
                            Flow {
                                id: lane
                                // Centre lane rides above the side lanes (mirrors the
                                // live bar's z=2 centre overlay) so a cramped right
                                // cluster can't hide the centred widget.
                                z: section._isCenter ? 2 : 1
                                flow: sideCard._horizontal ? Flow.LeftToRight : Flow.TopToBottom
                                spacing: 6
                                anchors.margins: 8
                                anchors.left:            (sideCard._horizontal && section._isStart) ? parent.left  : undefined
                                anchors.right:           (sideCard._horizontal && section._isEnd)   ? parent.right : undefined
                                anchors.top:             (!sideCard._horizontal && section._isStart) ? parent.top    : undefined
                                anchors.bottom:          (!sideCard._horizontal && section._isEnd)   ? parent.bottom : undefined
                                anchors.horizontalCenter: sideCard._horizontal ? (section._isCenter ? parent.horizontalCenter : undefined)
                                                                               : parent.horizontalCenter
                                anchors.verticalCenter:   sideCard._horizontal ? parent.verticalCenter
                                                                               : (section._isCenter ? parent.verticalCenter : undefined)

                                Repeater {
                                    id: chipRep
                                    model: editOverlay._list(sideCard.side, section.zoneName)
                                    delegate: Rectangle {
                                        id: chip
                                        required property var modelData
                                        required property int index
                                        readonly property string _id: chip.modelData.id
                                        readonly property var meta: editOverlay._meta(section.zoneName, chip._id)
                                        // Strips/holders are icon lanes (no inline
                                        // labels); only a horizontal bar shows titles.
                                        readonly property bool _iconOnly: !sideCard._isBar || !sideCard._horizontal
                                        readonly property bool _isSource:
                                            Commons.State.dragActive &&
                                            Commons.State.draggedSource === (sideCard.side + ":" + section.zoneName + ":" + chip.index)

                                        // Compact by default (icon only); the title
                                        // expands on hover so a full bar's worth of
                                        // pills fits without crowding the centre.
                                        implicitWidth:  chip._iconOnly ? 30
                                                       : (dragMA.containsMouse ? chipRow.implicitWidth + 14 : 34)
                                        implicitHeight: chip._iconOnly ? 30 : (sideCard._isBar ? 30 : 28)
                                        Behavior on implicitWidth { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                                        radius: Commons.Appearance.radius.md
                                        color: dragMA.containsMouse ? Commons.Appearance.colors.surface2
                                                                    : Commons.Appearance.colors.surface1
                                        border.width: 1
                                        border.color: chip._isSource ? Commons.Appearance.colors.accentBorder
                                                                     : Commons.Appearance.colors.glassBorder
                                        opacity: chip._isSource ? 0.35 : 1
                                        Behavior on opacity { NumberAnimation { duration: 90 } }

                                        // Drag handle over the chip body (declared before
                                        // chipRow so the hover controls stack above it).
                                        MouseArea {
                                            id: dragMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            property real _px: 0
                                            property real _py: 0
                                            property bool _dragging: false
                                            onPressed: (m) => { _px = m.x; _py = m.y; _dragging = false }
                                            onPositionChanged: (m) => {
                                                if (!pressed) return
                                                var gp = dragMA.mapToItem(editOverlay, m.x, m.y)
                                                if (!_dragging) {
                                                    if (Math.abs(m.x - _px) + Math.abs(m.y - _py) < 6) return
                                                    _dragging = true
                                                    editOverlay.beginDrag(sideCard.side, section.zoneName, chip.index, chip._id, chip)
                                                }
                                                editOverlay.moveDrag(gp.x, gp.y)
                                            }
                                            onReleased: { if (_dragging) { editOverlay.endDrag(); _dragging = false } }
                                            onCanceled: { if (_dragging) { editOverlay.endDrag(); _dragging = false } }
                                        }

                                        Row {
                                            id: chipRow
                                            anchors.centerIn: parent
                                            spacing: 5
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: chip.meta.icon || ""
                                                color: Commons.Appearance.colors.accent
                                                font.family: Commons.Appearance.font.family
                                                font.pixelSize: Commons.Appearance.font.sizeBase
                                            }
                                            Text {
                                                visible: !chip._iconOnly && dragMA.containsMouse
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: chip.meta.name || chip._id
                                                color: Commons.Appearance.colors.text
                                                font.family: Commons.Appearance.font.family
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                            }
                                            // Config gear — reveals on hover (horizontal chips only).
                                            Text {
                                                visible: !chip._iconOnly && editOverlay._hasConfig(chip._id) && dragMA.containsMouse
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰒓"
                                                color: Commons.Appearance.colors.subtext0
                                                font.family: Commons.Appearance.font.family
                                                font.pixelSize: Commons.Appearance.font.sizeBase
                                                MouseArea {
                                                    anchors.fill: parent; anchors.margins: -3
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: editOverlay.openConfig(sideCard.side, section.zoneName, chip.index, chip._id)
                                                }
                                            }
                                            // Remove × — reveals on hover (horizontal chips).
                                            Text {
                                                visible: !chip._iconOnly && dragMA.containsMouse
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "×"
                                                color: Commons.Appearance.colors.red
                                                font.family: Commons.Appearance.font.family
                                                font.pixelSize: Commons.Appearance.font.sizeMd
                                                MouseArea {
                                                    anchors.fill: parent; anchors.margins: -3
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: editOverlay.removeAt(sideCard.side, section.zoneName, chip.index)
                                                }
                                            }
                                        }

                                        // Icon-only (vertical) chips: hover reveals a small × badge.
                                        Rectangle {
                                            visible: chip._iconOnly && dragMA.containsMouse
                                            anchors.top: parent.top; anchors.right: parent.right
                                            anchors.margins: -4
                                            width: 16; height: 16; radius: 8
                                            color: Commons.Appearance.colors.red
                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: Commons.Appearance.colors.crust
                                                font.family: Commons.Appearance.font.family
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editOverlay.removeAt(sideCard.side, section.zoneName, chip.index)
                                            }
                                        }
                                    }
                                }
                            }

                            // Insertion caret — accent = valid drop, red = incompatible.
                            Rectangle {
                                id: caret
                                width:  sideCard._horizontal ? 2 : 22
                                height: sideCard._horizontal ? 22 : 2
                                radius: 1
                                visible: editOverlay._dropSide === sideCard.side
                                         && editOverlay._dropZone === section.zoneName
                                         && editOverlay._dropIndex >= 0
                                color: editOverlay._dropValid ? Commons.Appearance.colors.accent
                                                              : Commons.Appearance.colors.red
                                Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                                Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            }

                            // Drop target covering this section (DropAreas ignore clicks).
                            DropArea {
                                anchors.fill: parent
                                property int _idx: 0
                                function _reposition(px, py) {
                                    var idx = editOverlay._insertionIndex(chipRep, section, px, py)
                                    _idx = idx
                                    var x0 = 6, y0 = 6
                                    if (chipRep.count > 0 && idx < chipRep.count) {
                                        var it = chipRep.itemAt(idx)
                                        if (it) {
                                            var p = it.mapToItem(section, 0, 0)
                                            if (sideCard._horizontal) { x0 = p.x - 3; y0 = p.y + (it.height - caret.height) / 2 }
                                            else { x0 = p.x + (it.width - caret.width) / 2; y0 = p.y - 3 }
                                        }
                                    } else if (chipRep.count > 0) {
                                        var last = chipRep.itemAt(chipRep.count - 1)
                                        if (last) {
                                            var lp = last.mapToItem(section, 0, 0)
                                            if (sideCard._horizontal) { x0 = lp.x + last.width + 1; y0 = lp.y + (last.height - caret.height) / 2 }
                                            else { x0 = lp.x + (last.width - caret.width) / 2; y0 = lp.y + last.height + 1 }
                                        }
                                    } else {
                                        if (sideCard._horizontal) { x0 = 6; y0 = (section.height - caret.height) / 2 }
                                        else { x0 = (section.width - caret.width) / 2; y0 = 6 }
                                    }
                                    caret.x = x0; caret.y = y0
                                    editOverlay._dropSide  = sideCard.side
                                    editOverlay._dropZone  = section.zoneName
                                    editOverlay._dropIndex = idx
                                    editOverlay._dropValid = editOverlay._dropConverts(section.zoneName)
                                }
                                onEntered: (drag) => _reposition(drag.x, drag.y)
                                onPositionChanged: (drag) => _reposition(drag.x, drag.y)
                                onExited: {
                                    if (editOverlay._dropSide === sideCard.side && editOverlay._dropZone === section.zoneName) {
                                        editOverlay._dropSide = ""; editOverlay._dropZone = ""; editOverlay._dropIndex = -1
                                    }
                                }
                                onDropped: (drop) => {
                                    if (editOverlay._dropConverts(section.zoneName))
                                        editOverlay.performDrop(sideCard.side, section.zoneName, _idx)
                                }
                            }
                        }
                    }
                }
            }

            // Floating toolbar (type switch + Add), just inside the mock.
            Row {
                id: toolbar
                spacing: 6
                anchors.horizontalCenter: sideCard._horizontal ? mock.horizontalCenter : undefined
                anchors.verticalCenter:   sideCard._horizontal ? undefined : mock.verticalCenter
                anchors.top:    sideCard.side === "top"    ? mock.bottom : undefined
                anchors.bottom: sideCard.side === "bottom" ? mock.top    : undefined
                anchors.left:   sideCard.side === "left"   ? mock.right  : undefined
                anchors.right:  sideCard.side === "right"  ? mock.left   : undefined
                anchors.topMargin: 8; anchors.bottomMargin: 8
                anchors.leftMargin: 8; anchors.rightMargin: 8

                // Type switch — one segmented track; the active mode is a solid
                // accent fill (crust text, clearly readable), the rest quiet until
                // hovered. Compact, no inter-segment gaps.
                Rectangle {
                    radius: Commons.Appearance.radius.sm
                    color: Commons.Appearance.colors.surface0
                    border.width: 1
                    border.color: Commons.Appearance.colors.glassBorder
                    implicitWidth: _seg.implicitWidth
                    implicitHeight: 24
                    clip: true
                    Row {
                        id: _seg
                        height: parent.height
                        Repeater {
                            model: [
                                { t: "bar",    l: "Bar"    },
                                { t: "strip",  l: "Strip"  },
                                { t: "holder", l: "Holder" },
                                { t: "none",   l: "Off"    }
                            ]
                            delegate: Rectangle {
                                id: typeBtn
                                required property var modelData
                                readonly property bool active: editOverlay._cfg.sideType(sideCard.side) === modelData.t
                                width: _tl.implicitWidth + 18
                                height: parent.height
                                color: active ? Commons.Appearance.colors.accent
                                              : (_segMa.containsMouse ? Commons.Appearance.colors.surface2 : "transparent")
                                Text {
                                    id: _tl
                                    anchors.centerIn: parent
                                    text: typeBtn.modelData.l
                                    color: typeBtn.active ? Commons.Appearance.colors.crust
                                                          : Commons.Appearance.colors.subtext0
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    font.bold: typeBtn.active
                                }
                                MouseArea {
                                    id: _segMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editOverlay._cfg.setSideType(sideCard.side, typeBtn.modelData.t)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: sideCard._on
                    width: _addRow.implicitWidth + 16; height: 24
                    radius: Commons.Appearance.radius.sm
                    color: _addMa.containsMouse ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0
                    border.width: 1
                    border.color: _addMa.containsMouse ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.glassBorder
                    Row {
                        id: _addRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "＋"
                            color: Commons.Appearance.colors.accent
                            font.family: Commons.Appearance.font.family
                            font.pixelSize: Commons.Appearance.font.sizeSm
                        }
                        Text {
                            text: "Add"
                            color: Commons.Appearance.colors.accent
                            font.family: Commons.Appearance.font.family
                            font.pixelSize: Commons.Appearance.font.sizeSm
                        }
                    }
                    MouseArea {
                        id: _addMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editOverlay.openPalette(sideCard.side,
                                     editOverlay._cfg.sideType(sideCard.side) === "bar" ? "left" : "")
                    }
                }
            }
        }
    }

    // ── Trash target — appears mid-drag; drop a chip here to remove it (task_028).
    Item {
        id: trash
        visible: Commons.State.dragActive
        z: 140
        anchors.centerIn: parent
        width: 68; height: 68
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: trashDrop.containsDrag ? Commons.Appearance.colors.red : Commons.Appearance.colors.glassBg
            border.width: 1
            border.color: trashDrop.containsDrag ? Commons.Appearance.colors.red : Commons.Appearance.colors.glassBorder
            scale: trashDrop.containsDrag ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text: "󰩹"
                color: trashDrop.containsDrag ? Commons.Appearance.colors.crust : Commons.Appearance.colors.subtext0
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeLg
            }
        }
        DropArea {
            id: trashDrop
            anchors.fill: parent
            onDropped: (drop) => {
                var s = editOverlay._srcParts()
                editOverlay.removeAt(s.side, s.zone, s.index)
            }
        }
    }

    // ── Drag proxy + ghost (task_027 / adr_028) ─────────────────────────────────
    // `dragProxy` is invisible and carries Drag.active/hotSpot so the per-zone
    // DropAreas track the pointer; its mimeData holds only the "side:zone:index"
    // locator (the widget key rides Commons.State). `ghost` is the grabbed-image
    // preview trailing the cursor. Neither is wrapped in layer.enabled (hit-test
    // rule); both sit above the side cards, below the config popup (z 200).
    Item {
        id: dragProxy
        visible: false
        z: 150
        Drag.active: false
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.mimeData: ({ "text/plain": Commons.State.draggedSource })
    }
    Image {
        id: ghost
        visible: Commons.State.dragActive && source != ""
        opacity: 0.85
        z: 151
        fillMode: Image.Pad
    }

    // ── Palette popup ────────────────────────────────────────────────────────────
    WidgetPalette {
        id: palette
        onPicked: (id) => {
            editOverlay.addId(editOverlay._palSide, editOverlay._palZone, id)
            palette.visible = false
        }
        onCancelled: palette.visible = false
    }

    // ── Per-instance config popup (Sprint 26) ───────────────────────────────────
    // Driven by editOverlay state (not anchored to a chip) so it survives the
    // Repeater rebuild that a config write triggers. Each edit persists via
    // setEntryConfig → hot reload; the form re-reads the same value (no loop,
    // ConfigForm only emits on user interaction).
    Item {
        anchors.fill: parent
        visible: editOverlay._cfgOpen
        z: 200

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
            MouseArea { anchors.fill: parent; onClicked: editOverlay._cfgOpen = false }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: cfgCol.implicitHeight + 32
            radius: Commons.Appearance.radius.lg
            color: Commons.Appearance.colors.glassBg
            border.width: 1
            border.color: Commons.Appearance.colors.accentBorder

            ColumnLayout {
                id: cfgCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Configure · " + (editOverlay._reg.isPlugin(editOverlay._cfgId)
                                ? ((editOverlay._mods.moduleFor(editOverlay._cfgId) || {}).name || editOverlay._cfgId)
                                : editOverlay._meta(editOverlay._cfgZone, editOverlay._cfgId).name)
                        color: Commons.Appearance.colors.text
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeMd
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "×"
                        color: Commons.Appearance.colors.subtext0
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeLg
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editOverlay._cfgOpen = false
                        }
                    }
                }

                SettingsWidgets.ConfigForm {
                    Layout.fillWidth: true
                    schema: editOverlay._cfgOpen ? editOverlay._schemaFor(editOverlay._cfgId) : ({})
                    config: editOverlay._cfgOpen ? editOverlay._currentConfig() : ({})
                    onChanged: (c) => editOverlay._cfg.setEntryConfig(
                        editOverlay._cfgSide, editOverlay._cfgZone, editOverlay._cfgIndex, c)
                }
            }
        }
    }
}
