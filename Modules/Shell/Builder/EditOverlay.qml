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
    onVisibleChanged: if (visible) ShellServices.ModuleRegistry.rescan()

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
                text: "Esc to exit"
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

    // ── Side editor cards — one per edge, anchored to that edge ─────────────────
    Repeater {
        model: ["top", "bottom", "left", "right"]
        delegate: Rectangle {
            id: sideCard
            required property string modelData
            readonly property string side: modelData
            readonly property bool   _vertical: side === "left" || side === "right"

            anchors.top:    side === "top"    ? parent.top    : undefined
            anchors.bottom: side === "bottom" ? parent.bottom : undefined
            anchors.left:   side === "left"   ? parent.left   : undefined
            anchors.right:  side === "right"  ? parent.right  : undefined
            anchors.horizontalCenter: (side === "top" || side === "bottom") ? parent.horizontalCenter : undefined
            anchors.verticalCenter:   _vertical ? parent.verticalCenter : undefined
            anchors.topMargin:    side === "top" ? 72 : 24
            anchors.bottomMargin: 24
            anchors.leftMargin:   24
            anchors.rightMargin:  24

            width:  _vertical ? 300 : Math.min(parent.width - 48, 840)
            height: body.implicitHeight + 2 * editOverlay._pad
            radius: Commons.Appearance.radius.lg
            color:  Commons.Appearance.colors.glassBg
            border.width: 1
            border.color: Commons.Appearance.colors.glassBorder

            ColumnLayout {
                id: body
                anchors {
                    top: parent.top; left: parent.left; right: parent.right
                    margins: editOverlay._pad
                }
                spacing: Commons.Appearance.spacing.md

                // Header: side label + type switcher.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: editOverlay._label(sideCard.side)
                        color: Commons.Appearance.colors.text
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeMd
                        font.bold: true
                    }
                    Row {
                        spacing: 4
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
                                width: _tl.implicitWidth + 16; height: 24
                                radius: Commons.Appearance.radius.sm
                                color: active ? Commons.Appearance.colors.accentAlpha
                                              : Commons.Appearance.colors.surface0
                                border.width: 1
                                border.color: active ? Commons.Appearance.colors.accentBorder
                                                     : Commons.Appearance.colors.glassBorder
                                Text {
                                    id: _tl
                                    anchors.centerIn: parent
                                    text: typeBtn.modelData.l
                                    color: typeBtn.active ? Commons.Appearance.colors.accent
                                                          : Commons.Appearance.colors.subtext0
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editOverlay._cfg.setSideType(sideCard.side, typeBtn.modelData.t)
                                }
                            }
                        }
                    }
                }

                // "Off" hint when the side carries nothing.
                Text {
                    visible: editOverlay._zonesFor(sideCard.side).length === 0
                    Layout.fillWidth: true
                    text: "This edge is off — pick Bar, Strip or Holder above."
                    color: Commons.Appearance.colors.overlay1
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    wrapMode: Text.WordWrap
                }

                // Zone blocks (3 for a bar, 1 unlabeled for strip/holder).
                Repeater {
                    model: editOverlay._zonesFor(sideCard.side)
                    delegate: ColumnLayout {
                        id: zoneBlock
                        required property string modelData
                        readonly property string zoneName: modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            visible: zoneBlock.zoneName !== ""
                            text: zoneBlock.zoneName.toUpperCase()
                            color: Commons.Appearance.colors.subtext0
                            font.family: Commons.Appearance.font.family
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.bold: true
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            // Existing widgets as removable / reorderable chips.
                            Repeater {
                                model: editOverlay._list(sideCard.side, zoneBlock.zoneName)
                                delegate: Rectangle {
                                    id: chip
                                    required property var modelData
                                    required property int index
                                    readonly property string _id: chip.modelData.id
                                    readonly property var meta: editOverlay._meta(zoneBlock.zoneName, chip._id)
                                    height: 30
                                    width: chipRow.implicitWidth + 16
                                    radius: Commons.Appearance.radius.md
                                    color: Commons.Appearance.colors.surface1
                                    border.width: 1
                                    border.color: Commons.Appearance.colors.glassBorder

                                    Row {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: chip.meta.icon || ""
                                            color: Commons.Appearance.colors.accent
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: chip.meta.name || chip._id
                                            color: Commons.Appearance.colors.text
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeSm
                                        }
                                        // Config gear (only if the widget declares a configSchema)
                                        Text {
                                            visible: editOverlay._hasConfig(chip._id)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰒓"
                                            color: Commons.Appearance.colors.subtext0
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -3
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editOverlay.openConfig(sideCard.side, zoneBlock.zoneName, chip.index, chip._id)
                                            }
                                        }
                                        // Reorder ‹ ›  + remove ×
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "‹"
                                            color: Commons.Appearance.colors.subtext0
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeMd
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -3
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editOverlay.moveBy(sideCard.side, zoneBlock.zoneName, chip.index, -1)
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "›"
                                            color: Commons.Appearance.colors.subtext0
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeMd
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -3
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editOverlay.moveBy(sideCard.side, zoneBlock.zoneName, chip.index, 1)
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "×"
                                            color: Commons.Appearance.colors.red
                                            font.family: Commons.Appearance.font.family
                                            font.pixelSize: Commons.Appearance.font.sizeMd
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -3
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editOverlay.removeAt(sideCard.side, zoneBlock.zoneName, chip.index)
                                            }
                                        }
                                    }
                                }
                            }

                            // Add slot.
                            Rectangle {
                                height: 30; width: 34
                                radius: Commons.Appearance.radius.md
                                color: _addMa.containsMouse ? Commons.Appearance.colors.accentAlpha
                                                            : Commons.Appearance.colors.surface0
                                border.width: 1
                                border.color: _addMa.containsMouse ? Commons.Appearance.colors.accentBorder
                                                                   : Commons.Appearance.colors.glassBorder
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: Commons.Appearance.colors.accent
                                    font.family: Commons.Appearance.font.family
                                    font.pixelSize: Commons.Appearance.font.sizeLg
                                }
                                MouseArea {
                                    id: _addMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editOverlay.openPalette(sideCard.side, zoneBlock.zoneName)
                                }
                            }
                        }
                    }
                }
            }
        }
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
