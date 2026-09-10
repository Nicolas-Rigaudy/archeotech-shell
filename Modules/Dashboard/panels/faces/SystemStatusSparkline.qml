import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons

// SystemStatus face: "sparkline" — the DETAILED view. One row per stat: label +
// a mini trend chart of the rolling history + the current %. Uses the card's
// cpuHist/ramHist/… arrays (built while the dashboard is open). Binds to `card`.
ColumnLayout {
    id: face
    property var card
    spacing: 8

    component StatSpark: Item {
        required property string label
        required property var    hist
        required property int    value
        required property color  col
        // Small implicit height (4×22 ≈ the gauges face's 112) so switching to
        // sparkline never makes the card taller than its row-mate → the panel
        // can't grow and overlap the bottom toolbar. Layout.fillHeight then lets
        // the rows expand to fill whatever height the row actually gives.
        implicitHeight: 22

        Text {
            id: lbl
            text: label
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 42
            anchors.verticalCenter: parent.verticalCenter
        }

        Canvas {
            id: spark
            // Fill the row height (rows fillHeight in the card) so charts read as
            // proper trends rather than thin stranded lines.
            anchors { left: lbl.right; leftMargin: 8; right: valLbl.left; rightMargin: 8
                      top: parent.top; bottom: parent.bottom; topMargin: 5; bottomMargin: 5 }
            property var series: hist
            property color line: col
            onSeriesChanged: requestPaint()
            onLineChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var arr = (series && series.length) ? series : [value]
                var w = width, h = height, pad = 3
                // Auto-scale to the series' OWN range (peers show relative trend, not
                // an absolute 0–100 axis where real variance looks flat). A floor on
                // the span stops small noise being amplified into fake drama; a flat
                // series centers instead of pinning to an edge.
                var lo = arr[0], hi = arr[0]
                for (var k = 1; k < arr.length; k++) { lo = Math.min(lo, arr[k]); hi = Math.max(hi, arr[k]) }
                var span = Math.max(hi - lo, 6)   // lower floor → small real moves still show
                var mid = (lo + hi) / 2
                var yLo = mid - span / 2, yHi = mid + span / 2
                function xy(i, v) {
                    var x = arr.length > 1 ? i / (arr.length - 1) * w : w / 2
                    var norm = (v - yLo) / (yHi - yLo)          // 0..1 within the auto range
                    var y = h - pad - Math.max(0, Math.min(norm, 1)) * (h - 2 * pad)
                    return [x, y]
                }
                // Soft area fill under the line (only worth it with real shape).
                if (arr.length > 2) {
                    ctx.beginPath()
                    ctx.moveTo(0, h)
                    for (var i = 0; i < arr.length; i++) { var p = xy(i, arr[i]); ctx.lineTo(p[0], p[1]) }
                    ctx.lineTo(w, h)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(line.r, line.g, line.b, 0.10)
                    ctx.fill()
                }
                // The trend line.
                ctx.strokeStyle = line
                ctx.lineWidth = 1.75
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.beginPath()
                for (var j = 0; j < arr.length; j++) {
                    var q = xy(j, arr[j])
                    if (j === 0) ctx.moveTo(q[0], q[1]); else ctx.lineTo(q[0], q[1])
                }
                if (arr.length === 1) ctx.lineTo(w, xy(0, arr[0])[1])  // flat line for a single sample
                ctx.stroke()
                // Dot at the latest value — anchors the eye to "now".
                var last = xy(arr.length - 1, arr[arr.length - 1])
                ctx.fillStyle = line
                ctx.beginPath(); ctx.arc(last[0], last[1], 2.5, 0, Math.PI * 2); ctx.fill()
            }
        }

        Text {
            id: valLbl
            text: value + "%"
            color: Commons.Appearance.colors.text
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 36
            horizontalAlignment: Text.AlignRight
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        }
    }

    StatSpark { Layout.fillWidth: true; Layout.fillHeight: true; label: "CPU";  hist: face.card ? face.card.cpuHist  : []; value: face.card ? face.card.cpu  : 0; col: Commons.Appearance.colors.blue }
    StatSpark { Layout.fillWidth: true; Layout.fillHeight: true; label: "RAM";  hist: face.card ? face.card.ramHist  : []; value: face.card ? face.card.ram  : 0; col: Commons.Appearance.colors.mauve }
    StatSpark { Layout.fillWidth: true; Layout.fillHeight: true; label: "Disk"; hist: face.card ? face.card.diskHist : []; value: face.card ? face.card.disk : 0; col: Commons.Appearance.colors.peach }
    StatSpark {
        Layout.fillWidth: true; Layout.fillHeight: true
        label: "Bat"
        hist: face.card ? face.card.batHist : []
        value: face.card ? face.card.bat : 0
        col: (face.card && face.card.bat > 20) ? Commons.Appearance.colors.green : Commons.Appearance.colors.red
    }
}
