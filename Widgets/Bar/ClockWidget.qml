import QtQuick
import "../../Commons" as Commons

// Time + date. Horizontal: single rich-text line, hover opens the calendar.
// Vertical (thin side bar): HH over MM stacked (DMS pattern — never rotate
// text), no date/calendar (the calendar popup anchors horizontally).
Item {
    id: root
    required property var holderRoot
    property string widgetId
    // Sprint 26 — per-instance config (schema in WidgetRegistry._builtinSchemas):
    //   format: "24h" | "12h"    showSeconds: bool
    property var config: ({})

    readonly property bool _horizontal: holderRoot && holderRoot.horizontal

    function _timeFmt() {
        var h = (config && config.format === "12h") ? "h:mm" : "HH:mm"
        if (config && config.showSeconds === true) h += ":ss"
        return (config && config.format === "12h") ? h + " AP" : h
    }
    function _hourFmt() { return (config && config.format === "12h") ? "h" : "HH" }

    visible: holderRoot
    implicitWidth:  _horizontal ? centerClock.implicitWidth : (holderRoot ? holderRoot.thickness : 30)
    implicitHeight: _horizontal ? Commons.Appearance.bar.height : vClock.implicitHeight

    // ── Horizontal — rich single line + calendar hover ──────────────────────────
    Text {
        id: centerClock
        visible: root._horizontal
        anchors.centerIn: parent
        textFormat: Text.RichText
        text: clockText()
        font.pixelSize: Commons.Appearance.font.sizeMd
        font.family: Commons.Appearance.font.family

        function clockText() {
            return "<span style='color:" + Commons.Appearance.colors.text + ";font-weight:600'>"
                + Qt.formatDateTime(new Date(), root._timeFmt())
                + "</span>"
                + "<span style='color:" + Commons.Appearance.colors.surface1 + "'> &nbsp;·&nbsp; </span>"
                + "<span style='color:" + Commons.Appearance.colors.subtext0 + "'>"
                + Qt.formatDateTime(new Date(), "ddd d MMM")
                + "</span>"
        }
        Timer { interval: 1000; running: root._horizontal; repeat: true
                onTriggered: centerClock.text = centerClock.clockText() }
    }

    // ── Vertical — HH / MM stacked ───────────────────────────────────────────────
    Column {
        id: vClock
        visible: !root._horizontal
        anchors.centerIn: parent
        spacing: 0
        property var _now: new Date()
        Timer { interval: 1000; running: !root._horizontal; repeat: true
                onTriggered: vClock._now = new Date() }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(vClock._now, root._hourFmt())
            color: Commons.Appearance.colors.text
            font.pixelSize: Commons.Appearance.font.sizeMd; font.weight: Font.DemiBold
            font.family: Commons.Appearance.font.family
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(vClock._now, "mm")
            color: Commons.Appearance.colors.subtext0
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
