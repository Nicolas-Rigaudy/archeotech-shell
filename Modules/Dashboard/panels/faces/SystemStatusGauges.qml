import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons

// SystemStatus face: "gauges" — the same cpu/ram/disk/bat data as a 2×2 grid of
// radial gauges. A structurally different render tree from "bars" (config can't
// express this), justifying a face rather than a toggle. Binds to `card`.
GridLayout {
    id: face
    property var card
    columns: 2
    rowSpacing: 14
    columnSpacing: 14

    readonly property int _bat: card ? card.bat : 0

    component Gauge: Item {
        required property string label
        required property int    value
        required property color  col
        Layout.fillWidth: true
        implicitHeight: 112

        Canvas {
            id: cv
            width: 96; height: 72
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            property real v: Math.max(0, Math.min(value, 100))
            property color fill: col
            property color track: Commons.Appearance.colors.recessedTrack
            onVChanged: requestPaint()
            onFillChanged: requestPaint()
            onTrackChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = 40, r = 32
                var start = Math.PI * 0.75, end = Math.PI * 2.25
                ctx.lineWidth = 8
                ctx.lineCap = "round"
                ctx.strokeStyle = track
                ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
                ctx.strokeStyle = fill
                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + (end - start) * v / 100); ctx.stroke()
            }
            Behavior on v { NumberAnimation { duration: Commons.Appearance.anim.base } }
        }

        Text {
            text: parent.value + "%"
            color: Commons.Appearance.colors.text
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeLg
            font.bold: true
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 26 }
        }
        Text {
            text: parent.label
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeSm
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 84 }
        }
    }

    Gauge { label: "CPU";  value: face.card ? face.card.cpu : 0;  col: Commons.Appearance.colors.blue }
    Gauge { label: "RAM";  value: face.card ? face.card.ram : 0;  col: Commons.Appearance.colors.mauve }
    Gauge { label: "Disk"; value: face.card ? face.card.disk : 0; col: Commons.Appearance.colors.peach }
    Gauge {
        label: "Bat"
        value: face._bat
        col: face._bat > 20 ? Commons.Appearance.colors.green : Commons.Appearance.colors.red
    }
}
