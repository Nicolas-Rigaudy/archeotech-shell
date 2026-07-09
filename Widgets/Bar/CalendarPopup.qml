import QtQuick
import QtQuick.Shapes
import "../../Commons" as Commons

// Month calendar dropped from the bar's center. Same ear+arc shape as
// HoverCard so it merges with the pill. Visibility + month state driven
// by holderRoot._calendarVisible / _calendarMonth / _calendarYear.
Shape {
    id: card
    required property var holderRoot

    property real cellW: 28
    property real cellH: 22
    property real _r:    Commons.Appearance.radius.xl
    property real _rb:   Commons.Appearance.radius.md
    property real _bw:   cellW * 7 + 24

    x: Math.max(
           Commons.Appearance.bar.marginSide + 4,
           Math.min((holderRoot ? holderRoot.width / 2 : 0) - (_bw + _r * 2) / 2,
                    (holderRoot ? holderRoot.width : 0) - (_bw + _r * 2) - Commons.Appearance.bar.marginSide - 4))
    y: Commons.Appearance.bar.marginTop + Commons.Appearance.bar.height
    width:  _bw + _r * 2
    height: _calCol.implicitHeight + 20

    layer.enabled: true
    layer.samples: 8

    transformOrigin: Item.Top
    scale:   (holderRoot && holderRoot._calendarVisible) ? 1.0 : 0.85
    opacity: (holderRoot && holderRoot._calendarVisible) ? 1.0 : 0.0
    visible: holderRoot && holderRoot.side === "top" && opacity > 0.01

    Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function _monthName(m) {
        return ["January","February","March","April","May","June",
                "July","August","September","October","November","December"][m - 1]
    }
    function _calendarDays(year, month) {
        var days = []
        var first = (new Date(year, month - 1, 1).getDay() + 6) % 7
        var total = new Date(year, month, 0).getDate()
        for (var i = 0; i < first; i++) days.push(0)
        for (var j = 1; j <= total; j++) days.push(j)
        return days
    }

    ShapePath {
        fillColor:   Commons.Appearance.colors.glassBgLight
        strokeWidth: 0
        strokeColor: "transparent"

        startX: 0; startY: 0
        PathLine { x: card._bw + card._r * 2; y: 0 }
        PathArc  { x: card._bw + card._r;     y: card._r
                   radiusX: card._r; radiusY: card._r
                   direction: PathArc.Counterclockwise }
        PathLine { x: card._bw + card._r;     y: card.height - card._rb }
        PathArc  { x: card._bw + card._r - card._rb; y: card.height
                   radiusX: card._rb; radiusY: card._rb
                   direction: PathArc.Clockwise }
        PathLine { x: card._r + card._rb;     y: card.height }
        PathArc  { x: card._r;                y: card.height - card._rb
                   radiusX: card._rb; radiusY: card._rb
                   direction: PathArc.Clockwise }
        PathLine { x: card._r;                y: card._r }
        PathArc  { x: 0;                      y: 0
                   radiusX: card._r; radiusY: card._r
                   direction: PathArc.Counterclockwise }
        PathLine { x: 0;                      y: 0 }
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true
        onEntered: if (card.holderRoot) card.holderRoot.keepPopupsAlive()
        onExited:  if (card.holderRoot) card.holderRoot.hideCalendar(card)
    }

    Column {
        id: _calCol
        x: card._r + 12; y: 10
        width: card._bw - 24
        spacing: 4

        Row {
            width: parent.width
            Text {
                text: "‹"
                color: Commons.Appearance.colors.subtext1
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.family: Commons.Appearance.font.family
                width: 20; horizontalAlignment: Text.AlignHCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!card.holderRoot) return
                        if (card.holderRoot._calendarMonth === 1) {
                            card.holderRoot._calendarMonth = 12
                            card.holderRoot._calendarYear--
                        } else {
                            card.holderRoot._calendarMonth--
                        }
                    }
                }
            }
            Text {
                text: card.holderRoot
                    ? card._monthName(card.holderRoot._calendarMonth) + " " + card.holderRoot._calendarYear
                    : ""
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.family: Commons.Appearance.font.family
                font.weight: Font.Medium
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: "›"
                color: Commons.Appearance.colors.subtext1
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.family: Commons.Appearance.font.family
                width: 20; horizontalAlignment: Text.AlignHCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!card.holderRoot) return
                        if (card.holderRoot._calendarMonth === 12) {
                            card.holderRoot._calendarMonth = 1
                            card.holderRoot._calendarYear++
                        } else {
                            card.holderRoot._calendarMonth++
                        }
                    }
                }
            }
        }

        Row {
            spacing: 0
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text {
                    required property string modelData
                    text: modelData
                    width: card.cellW
                    horizontalAlignment: Text.AlignHCenter
                    color: Commons.Appearance.colors.overlay1
                    font.pixelSize: Commons.Appearance.font.sizeSm - 1
                    font.family: Commons.Appearance.font.family
                }
            }
        }

        Grid {
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: card.holderRoot
                    ? card._calendarDays(card.holderRoot._calendarYear, card.holderRoot._calendarMonth)
                    : []
                delegate: Item {
                    required property int modelData
                    property bool isToday: {
                        var now = new Date()
                        return modelData > 0
                            && card.holderRoot
                            && modelData === now.getDate()
                            && card.holderRoot._calendarMonth === (now.getMonth() + 1)
                            && card.holderRoot._calendarYear  === now.getFullYear()
                    }
                    width: card.cellW
                    height: card.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        radius: Commons.Appearance.radius.pill
                        color: parent.isToday ? Commons.Appearance.colors.accent : "transparent"
                        visible: parent.modelData > 0
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? parent.modelData : ""
                        color: parent.isToday ? Commons.Appearance.colors.base : Commons.Appearance.colors.text
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                        font.weight: parent.isToday ? Font.Medium : Font.Normal
                    }
                }
            }
        }
    }
}
