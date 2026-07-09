import QtQuick
import QtQuick.Layouts
import "../../Commons" as Commons

// Shared bar-widget capsule (Sprint 26-C). The single place the horizontal↔
// vertical fork lives, so individual widgets stay orientation-blind — they
// just supply an `icon`, an optional `text` value, colours, and hook the
// `clicked` / `wheel` / `entered` / `exited` signals for their behaviour.
//
// Modelled on Noctalia's BarPill and DMS's BasePill (see ANALYSIS.md / the
// S26 research): flip which dimension the pill owns on orientation, never
// rotate text — a vertical bar is thin, so it shows the icon only (the value
// text hides). Hover popups are horizontal-only for now (a vertical bar's
// popup anchoring is a later pass); widgets guard showPopup on
// `holderRoot.horizontal` themselves.
Item {
    id: pill

    required property var holderRoot
    property string widgetId

    readonly property bool horizontal: holderRoot && holderRoot.horizontal

    // ── Content ────────────────────────────────────────────────────────────────
    property string icon:      ""
    property color  iconColor: Commons.Appearance.colors.subtext1
    property color  hoverColor: Commons.Appearance.colors.accent
    property int    iconSize:  18
    // Value shown next to the icon on a horizontal bar; hidden when vertical
    // (thin bar) or empty. e.g. "82%", "18:30".
    property string text:      ""
    property color  textColor: Commons.Appearance.colors.overlay1

    property bool interactive: true
    // When true the icon adopts hoverColor while hovered (the usual behaviour);
    // widgets that drive icon colour entirely from state can set this false.
    property bool highlightOnHover: true

    // Rounded highlight behind the icon (Sprint 26-C phase 4 — absorbed from
    // StripIconBase): a strip icon shows an accent fill when its panel is active
    // and a subtle fill on hover. Off by default so bar pills stay flat.
    property bool showActiveBg: false
    property bool active:       false
    property int  activeBgSize: 44

    readonly property bool hovered: _ma.containsMouse
    readonly property color _iconColor: (interactive && highlightOnHover && hovered)
                                        ? hoverColor : iconColor

    Rectangle {
        anchors.centerIn: parent
        visible: pill.showActiveBg
        width:  pill.activeBgSize
        height: pill.activeBgSize
        radius: Commons.Appearance.radius.md
        color: pill.active  ? Commons.Appearance.colors.accentAlpha
             : pill.hovered ? Commons.Appearance.colors.surface0Alpha
             :                "transparent"
        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
    }

    signal clicked()
    signal wheel(int delta)
    signal entered()
    signal exited()

    // Horizontal: size to content, full bar height. Vertical: bar-thickness
    // wide, a square-ish icon cell tall (drives the ColumnLayout position).
    readonly property int _cell: 36
    implicitWidth:  horizontal ? (_row.implicitWidth + 10)
                               : (holderRoot ? holderRoot.thickness : 30)
    implicitHeight: horizontal ? Commons.Appearance.bar.height : _cell
    Layout.alignment: horizontal ? Qt.AlignVCenter : Qt.AlignHCenter

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 4
        Text {
            id: _icon
            text: pill.icon
            color: pill._iconColor
            font.pixelSize: pill.iconSize
            font.family: Commons.Appearance.font.family
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
        }
        Text {
            visible: pill.horizontal && pill.text !== ""
            text: pill.text
            color: pill.textColor
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: _ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pill.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: pill.interactive ? Qt.LeftButton : Qt.NoButton
        onClicked: pill.clicked()
        onEntered: pill.entered()
        onExited:  pill.exited()
        onWheel: w => pill.wheel(w.angleDelta.y > 0 ? 1 : -1)
    }
}
