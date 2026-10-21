import QtQuick
import Quickshell
import "../../Commons" as Commons
import "../../Commons/Primitives" as Prim
import "../../Services/Persistence" as Persistence
import "../../Services/System/ClockLogic.js" as Clock

// Time + date. Horizontal: single rich-text line, hover opens the calendar.
// Vertical (thin side bar): HH over MM stacked (DMS pattern — never rotate
// text), no date/calendar (the calendar popup anchors horizontally).
// Format = the global clock setting (Settings → Shell → Clock, "clock.*").
Item {
    id: root
    required property var holderRoot
    property string widgetId
    readonly property bool _horizontal: holderRoot && holderRoot.horizontal

    readonly property string _format:  Persistence.Config.get("clock.format")
    readonly property string _timeFmt: Clock.timeFormat(_format, Persistence.Config.get("clock.seconds"))
    readonly property string _dateFmt: Clock.dateFormat(Persistence.Config.get("clock.date"))

    // Ticks on the wall-clock boundary (a free-running 1 s Timer showed the new
    // minute up to a second late), per second only when seconds are shown.
    SystemClock {
        id: sysClock
        precision: root._horizontal && Persistence.Config.get("clock.seconds")
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    visible: holderRoot
    // Bolted console segment (steel pack, horizontal bar) — the centre gauge in its
    // own panel; pad the readout balanced inside, clear of the end rivets.
    readonly property bool _seg: _horizontal && holderRoot._consoleOn === true
        && Commons.Appearance.frameChamfer
    readonly property int _pad: _seg ? 26 : 0
    implicitWidth:  _horizontal ? centerClock.implicitWidth + 2 * _pad : (holderRoot ? holderRoot.thickness : 30)
    implicitHeight: _horizontal ? Commons.Appearance.bar.height : vClock.implicitHeight

    Prim.BarSegment { z: -1; visible: root._seg; anchors.fill: parent }

    // ── Horizontal — rich single line + calendar hover ──────────────────────────
    Text {
        id: centerClock
        visible: root._horizontal
        anchors.centerIn: parent
        textFormat: Text.RichText
        // Bound (never assigned), so a Settings change shows at once.
        text: clockText(sysClock.date, root._timeFmt, root._dateFmt)
        font.pixelSize: Commons.Appearance.font.sizeMd
        font.family: Commons.Appearance.font.family

        function clockText(now, timeFmt, dateFmt) {
            var time = "<span style='color:" + Commons.Appearance.colors.textPrimary + ";font-weight:600'>"
                + Qt.formatDateTime(now, timeFmt)
                + "</span>"
            if (!dateFmt) return time
            return time
                + "<span style='color:" + Commons.Appearance.colors.surface1 + "'> &nbsp;·&nbsp; </span>"
                + "<span style='color:" + Commons.Appearance.colors.textSecondary
                + ";font-family:\"" + Commons.Appearance.font.display + "\""
                + ";font-size:" + (Commons.Appearance.font.sizeMd + 2) + "px'>"
                + Qt.formatDateTime(now, dateFmt)
                + "</span>"
        }
    }

    // ── Vertical — HH / MM stacked ───────────────────────────────────────────────
    Column {
        id: vClock
        visible: !root._horizontal
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(sysClock.date, Clock.hourFormat(root._format))
            color: Commons.Appearance.colors.textPrimary
            font.pixelSize: Commons.Appearance.font.sizeMd; font.weight: Commons.Appearance.font.weightSemibold
            font.family: Commons.Appearance.font.family
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(sysClock.date, "mm")
            color: Commons.Appearance.colors.textSecondary
            font.pixelSize: Commons.Appearance.font.sizeMd
            font.family: Commons.Appearance.font.family
        }
    }

    MouseArea {
        anchors.centerIn: parent
        width: centerClock.implicitWidth + 24
        height: parent.height
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: root._horizontal
        z: 2
        onEntered: {
            if (!root.holderRoot) return
            root.holderRoot._calendarYear  = new Date().getFullYear()
            root.holderRoot._calendarMonth = new Date().getMonth() + 1
            root.holderRoot._popupVisible      = false
            root.holderRoot._wifiPopupVisible  = false
            root.holderRoot._btPopupVisible    = false
            root.holderRoot._calendarVisible   = true
        }
        onExited: if (root.holderRoot) root.holderRoot.hideCalendar(root)
    }
}
