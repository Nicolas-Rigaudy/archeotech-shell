import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Services/Compositor" as CompositorServices

// Tiling-layout picker (ROADMAP: "Tiling-layout picker with visual previews").
// A grid of cards, each a cheap static mini-diagram (Rectangles arranged the way
// that layout tiles windows) + name + keybind chip (doubles as a quicksheet) +
// a one-line description on hover. Clicking a card sets the layout on the focused
// output via CompositorService.dispatch("setlayout <name>"). Shows the full mango
// layout set — the extensive stack is the whole point of the feature. (Layouts are
// a MangoWC concept; under Hyprland the dispatch is a no-op.)
Item {
    id: root

    property var panelRoot: null
    property bool embedded: false
    // vertical: the quick panel passes !panelRoot._horizontal for left/right holders.
    property bool vertical: false

    readonly property var _mango: CompositorServices.CompositorService

    // Highlight reflects what we last set (authoritative). On open we seed from
    // the compositor's `layout_symbol` (the JSON has no layout *name*) via the
    // full symbol→name map below — all 14 verified unique by cycling this mango
    // 0.15 build in a headless session. Unknown symbol → nothing seeded; the
    // first pick corrects it.
    property string _setLayout: ""
    readonly property var _symbolToName: ({
        "S":  "scroller",          "T":  "tile",       "DW": "dwindle",
        "G":  "grid",              "M":  "monocle",    "F":  "fair",
        "K":  "deck",              "CT": "center_tile","RT": "right_tile",
        "VT": "vertical_tile",     "VS": "vertical_scroller",
        "VG": "vertical_grid",     "VK": "vertical_deck", "VF": "vertical_fair"
    })
    readonly property string _activeName:
        _setLayout !== "" ? _setLayout
                          : (_symbolToName[_mango.layoutFor(_mango.focusedOutput)] || "")

    function _apply(name) {
        root._setLayout = name
        _mango.dispatch("setlayout " + name)
    }

    // Grab keyboard focus when the panel opens so arrows move the cursor and
    // Enter/Space set the highlighted layout. The Strip also takes activeFocus on
    // open (for its Esc handler), so claim it back via Qt.callLater to win that
    // race — Esc still works because the grid doesn't handle it, so it bubbles up
    // to the Strip. Start the cursor on the currently-active layout.
    function _focusGrid() {
        var i = _layouts.findIndex(function(l) { return l.name === root._activeName })
        if (i >= 0) grid.currentIndex = i
        grid.forceActiveFocus()
    }
    Connections {
        target: root.panelRoot
        ignoreUnknownSignals: true
        function onPanelOpenChanged() {
            if (root.panelRoot && root.panelRoot.panelOpen) Qt.callLater(root._focusGrid)
        }
    }
    Component.onCompleted: if (panelRoot && panelRoot.panelOpen) Qt.callLater(_focusGrid)

    // ── Layout catalogue ────────────────────────────────────────────────────────
    // rects: normalised 0..1 boxes in the diagram; m=master (accent), o=opacity
    // (deck pile fades). key: the mango keybind, or "" → reachable via Super+T cycle.
    readonly property real _G: 0.06   // diagram gap between tiles (normalised)
    readonly property var _layouts: [
        { name: "scroller",          label: "Scroller",     key: "Super+Space",
          desc: "Horizontal scrolling strip (PaperWM)",
          rects: [ {x:0,y:.1,w:.1,h:.8}, {x:.16,y:0,w:.68,h:1,m:true}, {x:.9,y:.1,w:.1,h:.8} ] },
        { name: "tile",              label: "Tile",         key: "Super+Alt+Space",
          desc: "Master + side stack (Hyprland master). Super+Return promotes focus to master.",
          rects: [ {x:0,y:0,w:.55,h:1,m:true}, {x:.55,y:0,w:.45,h:.5}, {x:.55,y:.5,w:.45,h:.5} ] },
        { name: "dwindle",           label: "Dwindle",      key: "Super+Alt+S",
          desc: "Recursive BSP splits (spiral)",
          rects: [ {x:0,y:0,w:.6,h:1,m:true}, {x:.6,y:0,w:.4,h:.5}, {x:.6,y:.5,w:.2,h:.5}, {x:.8,y:.5,w:.2,h:.5} ] },
        { name: "grid",              label: "Grid",         key: "Super+Alt+G",
          desc: "Even grid of equal tiles",
          rects: [ {x:0,y:0,w:.5,h:.5,m:true}, {x:.5,y:0,w:.5,h:.5}, {x:0,y:.5,w:.5,h:.5}, {x:.5,y:.5,w:.5,h:.5} ] },
        { name: "monocle",           label: "Monocle",      key: "Super+Alt+M",
          desc: "One window, fullscreen",
          rects: [ {x:0,y:0,w:1,h:1,m:true} ] },
        { name: "fair",              label: "Fair",         key: "",
          desc: "Balanced grid; master absorbs the remainder (3→1+2, 4→2×2, 5→1+grid)",
          rects: [ {x:0,y:0,w:.5,h:1,m:true}, {x:.5,y:0,w:.25,h:.5}, {x:.75,y:0,w:.25,h:.5}, {x:.5,y:.5,w:.25,h:.5}, {x:.75,y:.5,w:.25,h:.5} ] },
        { name: "deck",              label: "Deck",         key: "Super+Alt+D",
          desc: "Master + a stacked pile (focused comes to front)",
          rects: [ {x:0,y:0,w:.55,h:1,m:true}, {x:.62,y:.12,w:.34,h:.76,o:.4}, {x:.66,y:.16,w:.34,h:.76,o:.65}, {x:.7,y:.2,w:.3,h:.72} ] },
        { name: "center_tile",       label: "Center Tile",  key: "Super+Alt+C",
          desc: "Master centered, stack on both sides",
          rects: [ {x:0,y:.15,w:.22,h:.7}, {x:.24,y:0,w:.52,h:1,m:true}, {x:.78,y:.15,w:.22,h:.7} ] },
        { name: "right_tile",        label: "Right Tile",   key: "Super+Alt+R",
          desc: "Master on the right, stack on the left",
          rects: [ {x:0,y:0,w:.45,h:.5}, {x:0,y:.5,w:.45,h:.5}, {x:.45,y:0,w:.55,h:1,m:true} ] },
        { name: "vertical_tile",     label: "Vert Tile",    key: "",
          desc: "Master on top, stack below",
          rects: [ {x:0,y:0,w:1,h:.55,m:true}, {x:0,y:.55,w:.5,h:.45}, {x:.5,y:.55,w:.5,h:.45} ] },
        { name: "vertical_scroller", label: "Vert Scroller",key: "Super+Alt+V",
          desc: "Vertical scrolling strip",
          rects: [ {x:.1,y:0,w:.8,h:.1}, {x:0,y:.16,w:1,h:.68,m:true}, {x:.1,y:.9,w:.8,h:.1} ] },
        { name: "vertical_grid",     label: "Vert Grid",    key: "",
          desc: "Even grid, fills columns first",
          rects: [ {x:0,y:0,w:.5,h:.5,m:true}, {x:0,y:.5,w:.5,h:.5}, {x:.5,y:0,w:.5,h:.5}, {x:.5,y:.5,w:.5,h:.5} ] },
        { name: "vertical_deck",     label: "Vert Deck",    key: "",
          desc: "Master on top + a stacked pile below",
          rects: [ {x:0,y:0,w:1,h:.55,m:true}, {x:.12,y:.62,w:.76,h:.34,o:.4}, {x:.16,y:.66,w:.76,h:.34,o:.65}, {x:.2,y:.7,w:.72,h:.3} ] },
        { name: "vertical_fair",     label: "Vert Fair",    key: "",
          desc: "Balanced grid, vertical bias; master absorbs the remainder",
          rects: [ {x:0,y:0,w:1,h:.5,m:true}, {x:0,y:.5,w:.5,h:.25}, {x:.5,y:.5,w:.5,h:.25}, {x:0,y:.75,w:.5,h:.25}, {x:.5,y:.75,w:.5,h:.25} ] }
    ]

    // ── UI ────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.embedded ? 0 : Commons.Appearance.spacing.lg
        spacing: Commons.Appearance.spacing.md

        // Header — title + count. Dropped in embedded mode (host provides chrome).
        Item {
            visible: !root.embedded
            Layout.fillWidth: true
            Layout.preferredHeight: root.embedded ? 0 : 40

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "󰕰  Tiling Layouts"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.family: Commons.Appearance.font.family
                font.weight: Font.Medium
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Super+T cycles all · click to set"
                color: Commons.Appearance.colors.subtext0
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true

            model: root._layouts
            readonly property int _cols: Math.max(2, Math.floor(width / 168))
            cellWidth:  Math.floor(width / _cols)
            cellHeight: 150

            // Keyboard: arrows move the cursor (native), Enter/Space sets it.
            keyNavigationWraps: true
            Keys.onReturnPressed: if (currentItem) root._apply(currentItem._name)
            Keys.onEnterPressed:  if (currentItem) root._apply(currentItem._name)
            Keys.onSpacePressed:  if (currentItem) root._apply(currentItem._name)
            // Esc closes. The grid holds activeFocus (for arrows), so it swallows
            // Escape before it can bubble to the Strip's handler — close here.
            Keys.onEscapePressed: if (root.panelRoot) root.panelRoot.close()
            highlightMoveDuration: Commons.Appearance.anim.fast

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property string _name: modelData.name
                readonly property bool _active: root._activeName === modelData.name
                readonly property bool _cursor: GridView.isCurrentItem
                property bool _hov: false

                width: grid.cellWidth
                height: grid.cellHeight

                // Soft lift so cards read as raised surfaces on the panel (matches
                // the launcher tiles); gated on shadowStrength so flat mode drops it.
                RectangularShadow {
                    anchors.fill: card
                    radius: card.radius
                    blur:   8
                    offset: Qt.vector2d(0, 2)
                    spread: 0
                    color:  Qt.rgba(0, 0, 0, 0.30 * Commons.Appearance.shadowStrength)
                }
                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.margins: Commons.Appearance.spacing.sm
                    radius: Commons.Appearance.radius.lg
                    // Selected = surfaceWarm + accent border (below), NOT an accent
                    // fill — so the accent label/diagram read clearly, not accent-
                    // on-accent. The 3px accent border marks active vs hover.
                    color: cell._active ? Commons.Appearance.colors.surfaceWarm
                         : (cell._hov ? Commons.Appearance.colors.surfaceWarm
                                      : Commons.Appearance.colors.surfaceCard)
                    border.width: cell._active ? 3 : (cell._hov || cell._cursor ? 2 : 1)
                    border.color: cell._active ? Commons.Appearance.colors.accent
                                : (cell._cursor ? Commons.Appearance.colors.accentBorder
                                                : Commons.Appearance.colors.surface0)
                    Behavior on color        { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                    Behavior on border.color { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                    Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Commons.Appearance.spacing.md
                        spacing: Commons.Appearance.spacing.sm

                        // Mini-diagram — the layout drawn as little rectangles.
                        Item {
                            id: diagram
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            readonly property real _gap: root._G * Math.min(width, height)

                            Repeater {
                                model: cell.modelData.rects
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool _m: modelData.m === true
                                    x:      modelData.x * diagram.width  + diagram._gap / 2
                                    y:      modelData.y * diagram.height + diagram._gap / 2
                                    width:  modelData.w * diagram.width  - diagram._gap
                                    height: modelData.h * diagram.height - diagram._gap
                                    radius: 3
                                    opacity: modelData.o !== undefined ? modelData.o : 1
                                    color: _m ? Commons.Appearance.colors.accent
                                              : Commons.Appearance.colors.surface1
                                    border.width: _m ? 0 : 1
                                    border.color: Commons.Appearance.colors.surface0
                                }
                            }
                        }

                        // Name + keybind chip / description-on-hover.
                        Text {
                            Layout.fillWidth: true
                            text: cell.modelData.label
                            color: cell._active ? Commons.Appearance.colors.accent
                                                : Commons.Appearance.colors.text
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                            font.weight: cell._active ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                        }

                        // Keybind chip normally; the one-line description on hover.
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16

                            Rectangle {
                                visible: !cell._hov && cell.modelData.key !== ""
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: keyText.implicitWidth + 10
                                height: 16
                                radius: Commons.Appearance.radius.sm
                                color: Commons.Appearance.colors.surface0Alpha
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: cell.modelData.key
                                    color: Commons.Appearance.colors.subtext0
                                    font.pixelSize: Commons.Appearance.font.sizeSm - 1
                                    font.family: Commons.Appearance.font.family
                                }
                            }
                            Text {
                                visible: !cell._hov && cell.modelData.key === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↻ Super+T"
                                color: Commons.Appearance.colors.subtext0
                                font.pixelSize: Commons.Appearance.font.sizeSm - 1
                                font.family: Commons.Appearance.font.family
                                opacity: 0.7
                            }
                            Text {
                                visible: cell._hov
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: cell.modelData.desc
                                color: Commons.Appearance.colors.subtext1
                                font.pixelSize: Commons.Appearance.font.sizeSm - 1
                                font.family: Commons.Appearance.font.family
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { cell._hov = true; grid.currentIndex = cell.index }
                        onExited:  cell._hov = false
                        onClicked: root._apply(cell._name)
                    }
                }
            }
        }
    }
}
