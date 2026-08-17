import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Services/Theming" as Theming

// Sprint 26 — compact theme picker for the quick-switcher panel: a snap-to-
// centre carousel of theme *families* (one tile per family, showing its 4-colour
// swatch), matching the wallpaper/logo carousels. Mode toggle + the contextual
// flavor / accent rows sit ABOVE the carousel (so the accent dots never hug the
// panel's bottom edge next to the bar widgets). The carousel keeps a fixed
// height when horizontal so toggling those rows never resizes the tiles; when
// vertical (side panels) it fills, and tiles size off width so height is free.
// Drives the ColorScheme service, which applies the resolved variant.
//
// The full, detailed picker (schedule, both flavor axes at once) still lives in
// Settings → Appearance via ColorSchemeBody — this is the fluid compact version.
Item {
    id: root

    // Lay the carousel top→bottom for left/right panels (the quick switcher
    // passes !panelRoot._horizontal).
    property bool vertical: false

    readonly property var _cs:  Theming.ColorScheme
    readonly property var _cat: Theming.ThemeCatalog

    // Flavors for the mode the user is actually seeing right now (auto resolves
    // to the current day/night flavor). Only shown when there's a real choice.
    readonly property string _eff: _cs.effectiveMode
    readonly property var _flavors: _cat.flavorsForMode(_cs.family, _eff)
    readonly property string _curFlavor: _eff === "light" ? _cs.flavorLight : _cs.flavorDark
    function _pickFlavor(id) {
        if (_eff === "light") _cs.setFlavorLight(id)
        else                  _cs.setFlavorDark(id)
    }

    readonly property var _accents: _cat.accentsFor(_cs.family)
    readonly property string _activeAccent: _cs.accent || "mauve"

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 6

        // ── Mode toggle ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { id: "dark",  label: "Dark",  glyph: "󰖔" },
                    { id: "light", label: "Light", glyph: "󰖨" },
                    { id: "auto",  label: "Auto",  glyph: "󰃟" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool _on: root._cs.mode === modelData.id
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Commons.Appearance.radius.base
                    color: _on ? Commons.Appearance.colors.accentAlpha
                         : (_mma.containsMouse ? Commons.Appearance.colors.surface0 : Commons.Appearance.colors.base)
                    border.color: _on ? Commons.Appearance.colors.accentBorder : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.glyph
                            color: parent.parent._on ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext0
                            font.pixelSize: 13; font.family: Commons.Appearance.font.family
                        }
                        Text {
                            text: modelData.label
                            color: parent.parent._on ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext0
                            font.pixelSize: Commons.Appearance.font.sizeBase; font.family: Commons.Appearance.font.family
                            font.weight: parent.parent._on ? Font.Medium : Font.Normal
                        }
                    }
                    MouseArea {
                        id: _mma; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._cs.setMode(modelData.id)
                    }
                }
            }
        }

        // ── Contextual rows (flavor + accent) ────────────────────────────────
        // Reserved height when horizontal so the carousel below keeps a constant
        // size whether or not these are shown — switching families never resizes
        // the tiles. Natural height when vertical (tiles size off width there, and
        // the accent dots may wrap to several rows in a narrow panel).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.vertical ? _rows.implicitHeight : 58
            ColumnLayout {
                id: _rows
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 6

        // ── Flavor (only when this family+mode offers a choice) ──────────────
        Flow {
            Layout.fillWidth: true
            visible: root._flavors.length > 1
            spacing: 6
            Repeater {
                model: root._flavors
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool _on: root._curFlavor === modelData.id
                    implicitWidth: _ft.implicitWidth + 22; implicitHeight: 26
                    radius: 13
                    color: _on ? Commons.Appearance.colors.accentAlpha
                         : (_fma.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.surface0)
                    border.color: _on ? Commons.Appearance.colors.accentBorder : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    Text {
                        id: _ft
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent._on ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                    }
                    MouseArea {
                        id: _fma; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._pickFlavor(modelData.id)
                    }
                }
            }
        }

        // ── Accent (accent-capable families only — currently Catppuccin) ─────
        Flow {
            Layout.fillWidth: true
            visible: root._accents.length > 0
            spacing: 8
            Repeater {
                model: root._accents
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool _on: root._activeAccent === modelData
                    readonly property color _swatch: Commons.Appearance.colors[modelData] || Commons.Appearance.colors.accent
                    width: 24; height: 24; radius: 12
                    color: _swatch
                    border.width: _on ? 3 : (_ama.containsMouse ? 2 : 0)
                    border.color: Commons.Appearance.colors.text
                    Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                    MouseArea {
                        id: _ama; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._cs.setAccent(modelData)
                    }
                }
            }
        }
            }   // ColumnLayout _rows
        }       // reserved-height Item

        // ── Family carousel ─────────────────────────────────────────────────
        // Fills the space left after the mode toggle + reserved rows zone. Since
        // that zone is a constant height (horizontal), the carousel's size never
        // changes when the flavor/accent rows appear or vanish. Tiles are capped
        // in the delegate, so a taller panel just centres them with more margin.
        Carousel {
            id: strip
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.vertical ? 200 : 96
            model: root._cat.families
            vertical: root.vertical
            itemSpacing: root.vertical
                ? Math.floor(Math.min(strip.width  - 12, 260) * 2 / 3 * 0.98)
                : Math.floor(Math.min(strip.height - 12, 150) * 3 / 2 * 0.95)

            onModelChanged: _sync()
            Component.onCompleted: _sync()
            // Re-centre when the applied family changes elsewhere.
            Connections {
                target: root._cs
                function onFamilyChanged() { strip._sync() }
            }
            function _sync() {
                var i = root._cat.families.findIndex(function(f) { return f.id === root._cs.family })
                if (i >= 0) currentIndex = i
            }

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool _current: PathView.isCurrentItem
                readonly property bool _active:  root._cs.family === modelData.id
                // Size off the cross-axis; landscape 3:2 either orientation.
                readonly property int  _cross: root.vertical
                    ? Math.min(strip.width  - 12, 260)
                    : Math.min(strip.height - 12, 150)
                readonly property int  _w: root.vertical ? _cross : Math.floor(_cross * 3 / 2)
                readonly property int  _h: root.vertical ? Math.floor(_cross * 2 / 3) : _cross

                width: _w; height: _h
                z: _current ? 2 : 1
                scale:   _current ? 1.0 : 0.72
                opacity: _current ? 1.0 : 0.6
                Behavior on scale   { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

                // Soft cast shadow under the hero (centred) tile only — lifts it
                // off the panel; side tiles stay flat. Gated on shadowStrength.
                RectangularShadow {
                    anchors.fill: parent
                    visible: tile._current
                    radius: Commons.Appearance.radius.md
                    blur:   32
                    offset: Qt.vector2d(0, 12)
                    spread: 2
                    color:  Qt.rgba(0, 0, 0, 0.55 * Commons.Appearance.shadowStrength)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.md
                    color: Commons.Appearance.colors.surface0
                    border.width: tile._active ? 3 : (tile._current ? 2 : 0)
                    border.color: tile._active ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext0
                    Behavior on border.color { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                    Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 6
                        Text {
                            text: tile.modelData.label
                            color: Commons.Appearance.colors.text
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4
                            Repeater {
                                model: tile.modelData.swatch
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 3
                                    color: modelData
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: tile._active
                    anchors { right: parent.right; top: parent.top; margins: 6 }
                    width: 20; height: 20; radius: 10
                    color: Commons.Appearance.colors.accent
                    Text {
                        anchors.centerIn: parent; text: "✓"
                        color: Commons.Appearance.colors.base
                        font.pixelSize: 11; font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // Scroll a side tile to centre to preview; click the centred
                    // tile to apply — same feel as the wallpaper carousel, and it
                    // avoids running theme-switch.py while browsing.
                    onClicked: {
                        if (tile._current) root._cs.setFamily(tile.modelData.id)
                        else strip.currentIndex = tile.index
                    }
                }
            }
        }

    }
}
