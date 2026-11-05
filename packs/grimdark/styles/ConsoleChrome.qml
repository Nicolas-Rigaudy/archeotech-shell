import QtQuick
import QtQuick.Shapes

// Grimdark: bolted-instrument-console hardware for popup and panel chrome
// (adr_027 Layer C style delegate for ConsoleChrome). Drawn ON TOP of the
// card's steel fill, it makes a popup read as a machined console bolted onto
// the bar/strip:
//   • copper molded edge-trim (NMM: dark seat + body + lit inner hairline)
//   • a recessed inner screen line (the well the content sits in)
//   • corner gussets, each with a domed bolt (free corners only)
//   • a collar along `attachSide`: a seam groove and two copper cleats near
//     the ends, fastening the panel to the bar/strip.
// Copper is single-sourced from the palette (peach / copperLit); teal is
// deliberately absent (reserved as a pinpoint on live content values).
// No Commons import: everything arrives through `api`.
Item {
    id: chrome
    property var api: ({})

    // Host properties (Commons/Primitives/ConsoleChrome.qml documents them).
    readonly property string attachSide:  api.attachSide !== undefined ? api.attachSide : "bottom"
    readonly property real   radius:      api.radius !== undefined ? api.radius : 3
    readonly property bool   showCollar:  api.showCollar !== false
    readonly property bool   showTrim:    api.showTrim !== false
    readonly property bool   showGussets: api.showGussets !== false
    readonly property real   inset:       api.inset !== undefined ? api.inset : 2

    // ── Copper NMM ramp ─────────────────────────────────────────────────────────
    // Lit copper (matches the frame trim's peachy read), so panel copper ≠ raw orange.
    // api arrives just after creation: guard every read so the first pass is quiet.
    readonly property var   _pal:   api.palette
    readonly property var   _steel: api.steel
    readonly property color _cuMid: _pal ? _pal.copperLit : "transparent"
    readonly property color _cuLo:  _pal ? Qt.darker(_pal.peach, 2.3) : "transparent"
    readonly property color _cuHi:  _pal ? Qt.lighter(_pal.copperLit, 1.5) : "transparent"
    readonly property color _edge:  _steel ? _steel.edge : "transparent"
    readonly property color _lip:   _steel ? _steel.lip : "transparent"
    readonly property real  _spec:  api.specular !== undefined ? api.specular : 0.9

    readonly property bool _horiz: attachSide === "top" || attachSide === "bottom"

    // ── Copper molded edge-trim ────────────────────────────────────────────────
    Rectangle {                                  // dark seat (outermost)
        visible: chrome.showTrim
        anchors.fill: parent; anchors.margins: chrome.inset
        radius: chrome.radius; color: "transparent"
        border.width: 1; border.color: chrome._cuLo; antialiasing: true
    }
    Rectangle {                                  // copper body
        visible: chrome.showTrim
        anchors.fill: parent; anchors.margins: chrome.inset + 1
        radius: Math.max(1, chrome.radius - 1); color: "transparent"
        border.width: 1.4; border.color: chrome._cuMid; antialiasing: true
    }
    Rectangle {                                  // recessed screen line (well the content sits in)
        visible: chrome.showTrim
        anchors.fill: parent; anchors.margins: chrome.inset + 4
        radius: Math.max(1, chrome.radius - 1); color: "transparent"
        border.width: 1; border.color: chrome._edge; antialiasing: true
    }
    Rectangle {                                  // faint lit lip just inside the recess
        visible: chrome.showTrim
        anchors.fill: parent; anchors.margins: chrome.inset + 5
        radius: Math.max(1, chrome.radius - 2); color: "transparent"
        border.width: 1
        border.color: Qt.rgba(chrome._lip.r, chrome._lip.g, chrome._lip.b, 0.12)
        antialiasing: true
    }

    // ── Domed bolt (reusable) ──────────────────────────────────────────────────
    Component {
        id: boltComp
        Item {
            property real s: 9
            width: s; height: s
            Rectangle {                          // seated head
                anchors.fill: parent; radius: width / 2
                color: chrome._cuMid
                border.width: Math.max(1, parent.s * 0.13); border.color: chrome._cuLo
                antialiasing: true
            }
            Rectangle {                          // top-left specular → domed, not flat
                width: parent.s * 0.32; height: parent.s * 0.32; radius: width / 2
                x: parent.s * 0.2; y: parent.s * 0.18
                color: chrome._cuHi; opacity: chrome._spec; antialiasing: true
            }
        }
    }

    // ── Corner gussets (L-bracket + bolt) ──────────────────────────────────────
    // Local coords: outer corner at (0,0), arms run +x and +y; per corner we place
    // the Item at that screen corner and rotate so the arms hug the two edges.
    readonly property real _ga: 14               // arm length
    readonly property real _gt: 4                // arm thickness
    // Gussets on the FREE corners only — never the two on `attachSide` (that edge
    // belongs to the strip icon rail / bar, and short popups' icons reach those
    // corners and collide with a bracket there).
    readonly property var _corners: [
        { x: inset,          y: inset,          rot: 0,   edges: ["top", "left"]     },
        { x: width - inset,  y: inset,          rot: 90,  edges: ["top", "right"]    },
        { x: width - inset,  y: height - inset, rot: 180, edges: ["bottom", "right"] },
        { x: inset,          y: height - inset, rot: 270, edges: ["bottom", "left"]  }
    ].filter(function (c) { return c.edges.indexOf(chrome.attachSide) === -1 })
    Repeater {
        model: chrome.showGussets ? chrome._corners : []
        delegate: Item {
            required property var modelData
            x: modelData.x; y: modelData.y
            transformOrigin: Item.TopLeft
            rotation: modelData.rot
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: chrome._cuMid
                    strokeColor: chrome._cuLo; strokeWidth: 1
                    joinStyle: ShapePath.MiterJoin
                    PathSvg { path: "M 0 0 L " + chrome._ga + " 0 L " + chrome._ga + " " + chrome._gt
                                    + " L " + chrome._gt + " " + chrome._gt + " L " + chrome._gt + " " + chrome._ga
                                    + " L 0 " + chrome._ga + " Z" }
                }
                // lit inner edge of the L
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.rgba(chrome._cuHi.r, chrome._cuHi.g, chrome._cuHi.b, 0.7)
                    strokeWidth: 1
                    PathSvg { path: "M " + chrome._gt + " " + chrome._ga + " L " + chrome._gt + " " + chrome._gt
                                    + " L " + chrome._ga + " " + chrome._gt }
                }
            }
            Loader {
                sourceComponent: boltComp
                onLoaded: { item.s = 9; item.x = chrome._gt + 2.5; item.y = chrome._gt + 2.5 }
            }
        }
    }

    // ── Collar along the attach edge ────────────────────────────────────────────
    // A recessed seam groove running the whole join + two short copper mounting
    // bars (cleats) near the ENDS — no bolts. Reads as a panel seated at its
    // shoulders; the centre stays clear for the strip's icon rail.
    readonly property real _axisLen: chrome._horiz ? width : height
    readonly property real _perpEdge:
          attachSide === "bottom" ? height - inset - 5
        : attachSide === "top"    ? inset + 5
        : attachSide === "left"   ? inset + 5
        :                           width - inset - 5     // right
    readonly property real _seamPad: chrome.inset + 12
    readonly property real _lipOff: (attachSide === "top" || attachSide === "left") ? 1.5 : -1.5

    Rectangle {                                  // seam groove (dark)
        visible: chrome.showCollar; antialiasing: true; radius: 1
        color: chrome._edge
        width:  chrome._horiz ? Math.max(0, chrome._axisLen - 2 * chrome._seamPad) : 2
        height: chrome._horiz ? 2 : Math.max(0, chrome._axisLen - 2 * chrome._seamPad)
        x: chrome._horiz ? chrome._seamPad : chrome._perpEdge
        y: chrome._horiz ? chrome._perpEdge : chrome._seamPad
    }
    Rectangle {                                  // lit lip just inboard of the groove
        visible: chrome.showCollar; antialiasing: true
        color: Qt.rgba(chrome._lip.r, chrome._lip.g, chrome._lip.b, 0.16)
        width:  chrome._horiz ? Math.max(0, chrome._axisLen - 2 * chrome._seamPad) : 1
        height: chrome._horiz ? 1 : Math.max(0, chrome._axisLen - 2 * chrome._seamPad)
        x: chrome._horiz ? chrome._seamPad : chrome._perpEdge + chrome._lipOff
        y: chrome._horiz ? chrome._perpEdge + chrome._lipOff : chrome._seamPad
    }

    // two copper mounting bars near each end — top-lit like real molding, no bolts
    Repeater {
        model: chrome.showCollar ? [{ a: 0.06, b: 0.30 }, { a: 0.70, b: 0.94 }] : []
        delegate: Rectangle {
            required property var modelData
            readonly property real _s:   modelData.a * chrome._axisLen
            readonly property real _len: (modelData.b - modelData.a) * chrome._axisLen
            antialiasing: true; radius: 2
            border.width: 1; border.color: chrome._cuLo
            width:  chrome._horiz ? _len : 6
            height: chrome._horiz ? 6 : _len
            x: chrome._horiz ? _s : chrome._perpEdge - 3
            y: chrome._horiz ? chrome._perpEdge - 3 : _s
            gradient: Gradient {
                orientation: chrome._horiz ? Gradient.Vertical : Gradient.Horizontal
                GradientStop { position: 0.0; color: chrome._cuHi }
                GradientStop { position: 0.5; color: chrome._cuMid }
                GradientStop { position: 1.0; color: Qt.darker(chrome._cuMid, 1.5) }
            }
        }
    }
}
