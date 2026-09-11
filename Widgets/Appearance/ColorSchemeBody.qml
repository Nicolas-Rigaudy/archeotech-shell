import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Commons/Primitives"
import "../../Services/Theming" as Theming

// Sprint 25 — hierarchical theme picker (family → flavor + light/dark mode +
// day-night schedule). Shared by Settings → Appearance and the bottom
// Appearance switcher (`compact: true` drops the schedule + tightens). Drives
// the ColorScheme service; that service applies the resolved variant.
Item {
    id: root
    property bool compact: false
    implicitHeight: col.implicitHeight

    readonly property var _cs:  Theming.ColorScheme
    readonly property var _cat: Theming.ThemeCatalog

    readonly property var _darkFlavors:  _cat.flavorsForMode(_cs.family, "dark")
    readonly property var _lightFlavors: _cat.flavorsForMode(_cs.family, "light")

    // Accent picker state (accent-capable families only — currently Catppuccin).
    readonly property var _accents: _cat.accentsFor(_cs.family)
    // Active accent: the explicit choice, else the family's default (mauve).
    readonly property string _activeAccent: _cs.accent || "mauve"

    readonly property var _modes: [
        { id: "dark",  label: "Dark",  glyph: "󰖔" },
        { id: "light", label: "Light", glyph: "󰖨" },
        { id: "auto",  label: "Auto",  glyph: "󰃟" }
    ]

    // 48 half-hour options for the schedule pickers.
    readonly property var _times: {
        var t = []
        for (var h = 0; h < 24; h++)
            for (var m = 0; m < 60; m += 30)
                t.push((h < 10 ? "0" + h : "" + h) + ":" + (m === 0 ? "00" : "30"))
        return t
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: root.compact ? 5 : 10

        // ── Mode ────────────────────────────────────────────────────────────────
        // Shared segmented control — same language as the quick-switcher, base
        // glyph/label on the accent pill (no accent-on-accent contrast issue).
        SLabel { text: "MODE" }
        SegmentedControl {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            model: root._modes
            currentIndex: Math.max(0, root._modes.findIndex(function(m) { return m.id === root._cs.mode }))
            onActivated: index => root._cs.setMode(root._modes[index].id)
        }

        // ── Family ──────────────────────────────────────────────────────────────
        SLabel { text: "THEME" }
        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.floor(width / (root.compact ? 150 : 168)))
            rowSpacing: 8; columnSpacing: 8
            Repeater {
                model: root._cat.families
                delegate: Item {
                    id: famCard
                    required property var modelData
                    readonly property bool _on: root._cs.family === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 50 : 64

                    RectangularShadow {              // soft glow — base packs only (reads modern on steel)
                        anchors.fill: famBg
                        visible: !Commons.Appearance.frameChamfer
                        radius: famBg.radius
                        blur: 10; offset: Qt.vector2d(0, 3); spread: 0
                        color: Qt.rgba(0, 0, 0, 0.5 * Commons.Appearance.shadowStrength)
                    }
                    Rectangle {
                        id: famBg
                        anchors.fill: parent
                        // Steel pack: a square-cut machined plate (copper hairline, teal when
                        // selected); base packs keep the rounded grey card.
                        radius: Commons.Appearance.frameChamfer ? 1 : Commons.Appearance.radius.md
                        antialiasing: true
                        border.width: famCard._on ? (Commons.Appearance.frameChamfer ? 1.6 : 3) : 1
                        border.color: famCard._on
                            ? (Commons.Appearance.frameChamfer ? Qt.lighter(Commons.Appearance.colors.accent, 1.25) : Commons.Appearance.colors.accent)
                            : (Commons.Appearance.frameChamfer
                               ? Qt.rgba(Commons.Appearance.colors.peach.r, Commons.Appearance.colors.peach.g, Commons.Appearance.colors.peach.b, 0.32)
                               : Commons.Appearance.colors.glassBorder)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Commons.Appearance.frameChamfer ? Commons.Appearance.steel.hi : Commons.Appearance.sheenHi(Commons.Appearance.colors.surfaceCard, Commons.Appearance.sheen.surface.hi) }
                            GradientStop { position: 0.5; color: Commons.Appearance.frameChamfer ? Commons.Appearance.steel.md : Commons.Appearance.sheenHi(Commons.Appearance.colors.surfaceCard, Commons.Appearance.sheen.surface.hi) }
                            GradientStop { position: 1.0; color: Commons.Appearance.frameChamfer ? Commons.Appearance.steel.lo : Commons.Appearance.sheenLo(Commons.Appearance.colors.surfaceCard, Commons.Appearance.sheen.surface.lo) }
                        }
                        Behavior on border.color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: famCard.modelData.label
                                color: Commons.Appearance.colors.text
                                font.pixelSize: Commons.Appearance.font.sizeBase
                                font.family: Commons.Appearance.font.family
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: famCard._on
                                width: 18; height: 18; radius: 9
                                color: Commons.Appearance.colors.accent
                                Text {
                                    anchors.centerIn: parent; text: "✓"
                                    color: Commons.Appearance.colors.base
                                    font.pixelSize: 10; font.bold: true
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Repeater {
                                model: famCard.modelData.swatch
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 14
                                    radius: 3
                                    color: modelData
                                }
                            }
                        }
                    }
                    StateLayer {
                        anchors.fill: parent
                        onClicked: root._cs.setFamily(famCard.modelData.id)
                    }
                    }
                }
            }
        }

        // ── Dark flavor (when a choice exists & dark is reachable) ────────────────
        FlavorRow {
            label: root._cs.mode === "auto" ? "DARK FLAVOR" : "FLAVOR"
            visible: (root._cs.mode === "dark" || root._cs.mode === "auto") && root._darkFlavors.length >= 1
            flavors: root._darkFlavors
            current: root._cs.flavorDark
            onPick: id => root._cs.setFlavorDark(id)
        }

        // ── Light flavor ──────────────────────────────────────────────────────────
        FlavorRow {
            label: root._cs.mode === "auto" ? "LIGHT FLAVOR" : "FLAVOR"
            visible: (root._cs.mode === "light" || root._cs.mode === "auto") && root._lightFlavors.length >= 1
            flavors: root._lightFlavors
            current: root._cs.flavorLight
            onPick: id => root._cs.setFlavorLight(id)
        }

        // Shown when the chosen family has no light flavor but light is requested.
        SLabel {
            text: "No light variant for this family yet"
            visible: (root._cs.mode === "light" || root._cs.mode === "auto") && root._lightFlavors.length === 0
        }

        // ── Accent (accent-capable families only — currently Catppuccin) ──────────
        SLabel { text: "ACCENT"; visible: root._accents.length > 0 }
        Flow {
            Layout.fillWidth: true
            visible: root._accents.length > 0
            spacing: 8
            Repeater {
                model: root._accents
                delegate: Item {
                    id: swatch
                    required property string modelData
                    readonly property bool _on: root._activeAccent === modelData
                    readonly property color _swatch: Commons.Appearance.colors[modelData] || Commons.Appearance.colors.accent
                    width: 26; height: 26

                    // Raised dot — sibling shadow + press-pulse (toggle-knob recipe).
                    RectangularShadow {
                        anchors.fill: dot
                        radius: dot.radius
                        blur: 7; offset: Qt.vector2d(0, 1.5); spread: 0
                        color: Qt.rgba(0, 0, 0, 0.5 * Commons.Appearance.shadowStrength)
                    }
                    Rectangle {
                        id: dot
                        anchors.fill: parent
                        radius: 13
                        antialiasing: true
                        // Top-lit sphere shading.
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Commons.Appearance.sheenHi(swatch._swatch, Commons.Appearance.sheen.control.hi) }
                            GradientStop { position: 1.0; color: Commons.Appearance.sheenLo(swatch._swatch, Commons.Appearance.sheen.control.lo) }
                        }
                        border.width: swatch._on ? 3 : (_ama.containsMouse ? 2 : 0)
                        border.color: Commons.Appearance.colors.text
                        Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                        scale: _ama.pressed ? 0.92 : (_ama.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                        // Inner ring to separate the border from the swatch fill.
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -3
                            radius: width / 2; color: "transparent"
                            border.width: swatch._on ? 1 : 0
                            border.color: Commons.Appearance.colors.base
                            visible: swatch._on
                        }
                    }
                    MouseArea {
                        id: _ama; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._cs.setAccent(swatch.modelData)
                    }
                }
            }
        }

        // ── Schedule (auto only, full pane only) ──────────────────────────────────
        SLabel { text: "DAY / NIGHT SCHEDULE"; visible: root._cs.mode === "auto" && !root.compact }
        RowLayout {
            Layout.fillWidth: true
            visible: root._cs.mode === "auto" && !root.compact
            spacing: 12
            TimePick {
                label: "󰖨  Light from"
                value: root._cs.lightStart
                onPicked: t => root._cs.setLightStart(t)
            }
            TimePick {
                label: "󰖔  Dark from"
                value: root._cs.darkStart
                onPicked: t => root._cs.setDarkStart(t)
            }
        }
    }

    // ── Inline components ─────────────────────────────────────────────────────────
    component SLabel: Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        color: Commons.Appearance.colors.overlay0
        font.pixelSize: 10
        font.family: Commons.Appearance.font.family
        font.weight: Font.Medium
        font.letterSpacing: 1.5
    }

    component FlavorRow: ColumnLayout {
        id: fr
        property string label: ""
        property var flavors: []
        property string current: ""
        signal pick(string id)
        Layout.fillWidth: true
        spacing: 6
        SLabel { text: fr.label }
        SegmentedControl {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            model: fr.flavors
            currentIndex: Math.max(0, fr.flavors.findIndex(function(f) { return f.id === fr.current }))
            onActivated: index => fr.pick(fr.flavors[index].id)
        }
    }

    component TimePick: RowLayout {
        id: tp
        property string label: ""
        property string value: ""
        signal picked(string t)
        spacing: 8
        Text {
            text: tp.label
            color: Commons.Appearance.colors.subtext0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
        }
        ComboBox {
            id: _cb
            Layout.preferredWidth: 96
            model: root._times
            currentIndex: Math.max(0, root._times.indexOf(tp.value))
            onActivated: tp.picked(root._times[_cb.currentIndex])
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
        }
    }
}
