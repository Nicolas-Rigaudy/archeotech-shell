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
        SLabel { text: "MODE" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { id: "dark",  label: "Dark",  glyph: "󰖔" },
                    { id: "light", label: "Light", glyph: "󰖨" },
                    { id: "auto",  label: "Auto",  glyph: "󰃟" }
                ]
                delegate: GlassButton {
                    id: modeBtn
                    required property var modelData
                    readonly property bool _on: root._cs.mode === modelData.id
                    Layout.fillWidth: true
                    active: _on
                    onClicked: root._cs.setMode(modelData.id)
                    RowLayout {
                        spacing: 6
                        Text {
                            text: modeBtn.modelData.glyph
                            color: modeBtn._on ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext0
                            font.pixelSize: 13; font.family: Commons.Appearance.font.family
                        }
                        Text {
                            text: modeBtn.modelData.label
                            color: modeBtn._on ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext0
                            font.pixelSize: Commons.Appearance.font.sizeBase; font.family: Commons.Appearance.font.family
                            font.weight: modeBtn._on ? Font.Medium : Font.Normal
                        }
                    }
                }
            }
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

                    RectangularShadow {
                        anchors.fill: famBg
                        radius: famBg.radius
                        blur: 10; offset: Qt.vector2d(0, 3); spread: 0
                        color: Qt.rgba(0, 0, 0, 0.5)
                    }
                    Rectangle {
                        id: famBg
                        anchors.fill: parent
                        radius: Commons.Appearance.radius.md
                        antialiasing: true
                        border.width: famCard._on ? 2 : 1
                        border.color: famCard._on ? Commons.Appearance.colors.accent : Commons.Appearance.colors.glassBorder
                        // Top-lit gradient for depth — accent when selected.
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: famCard._on ? Qt.lighter(Commons.Appearance.colors.accent, 1.08) : Qt.lighter(Commons.Appearance.colors.surfaceCard, 1.12) }
                            GradientStop { position: 1.0; color: famCard._on ? Qt.darker(Commons.Appearance.colors.accent, 1.06)  : Commons.Appearance.colors.surfaceCard }
                        }
                        Behavior on border.color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

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
                            Text {
                                visible: famCard._on
                                text: "✓"; color: Commons.Appearance.colors.accent
                                font.pixelSize: 13; font.bold: true
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
                        color: Qt.rgba(0, 0, 0, 0.5)
                    }
                    Rectangle {
                        id: dot
                        anchors.fill: parent
                        radius: 13
                        antialiasing: true
                        // Top-lit sphere shading.
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(swatch._swatch, 1.18) }
                            GradientStop { position: 1.0; color: Qt.darker(swatch._swatch, 1.12) }
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
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: fr.flavors
                delegate: GlassButton {
                    id: flavorPill
                    required property var modelData
                    active: fr.current === modelData.id
                    text: modelData.label
                    onClicked: fr.pick(flavorPill.modelData.id)
                }
            }
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
