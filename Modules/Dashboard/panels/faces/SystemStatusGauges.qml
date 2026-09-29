import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons

// SystemStatus face: "gauges" — the same cpu/ram/disk/bat data as a single ROW of
// four radial gauges. A row (not a 2×2 grid) keeps the card height close to the
// "bars" face so the dashboard panel doesn't overflow; each gauge fills its cell
// so the rings read large. Binds to `card`.
RowLayout {
    id: face
    property var card
    spacing: 10

    readonly property int _bat: card ? card.bat : 0

    component Gauge: Item {
        required property string label
        required property int    value
        required property color  col
        Layout.fillWidth: true
        implicitHeight: ring.height + lbl.height + 6

        Canvas {
            id: ring
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 84)
            height: width
            property real v: Math.max(0, Math.min(value, 100))
            property color fill: col
            property color track: Commons.Appearance.colors.recessedTrack
            onVChanged: requestPaint()
            onFillChanged: requestPaint()
            onTrackChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                var cx = width / 2, cy = height / 2
                var r = Math.max(1, width / 2 - Math.max(6, width * 0.09))
                var start = Math.PI * 0.75, end = Math.PI * 2.25
                ctx.lineWidth = Math.max(6, width * 0.10)
                ctx.lineCap = "round"
                ctx.strokeStyle = track
                ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
                ctx.strokeStyle = fill
                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + (end - start) * v / 100); ctx.stroke()
            }
            Behavior on v { NumberAnimation { duration: Commons.Appearance.anim.base } }

            // % centered IN the ring.
            Text {
                anchors.centerIn: parent
                text: value + "%"
                color: Commons.Appearance.colors.textPrimary
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.bold: true
            }
        }

        Text {
            id: lbl
            anchors.top: ring.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.label
            color: Commons.Appearance.colors.textSecondary
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeSm
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
