import QtQuick
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

DashCard {
    id: root
    title: "SYSTEM STATUS"

    property int    cpu:       0
    property int    ram:       0
    property int    disk:      0
    property int    bat:       0
    property string batStatus: "Unknown"

    // Rolling history (last _histMax samples) for the "sparkline" face. Grows one
    // sample per refresh while the dashboard is open; faces read these arrays.
    property var cpuHist:  []
    property var ramHist:  []
    property var diskHist: []
    property var batHist:  []
    readonly property int _histMax: 60
    function _push(arr, v) {
        var a = arr.slice()
        a.push(v)
        while (a.length > _histMax) a.shift()
        return a
    }

    Component.onCompleted: _refresh()

    property bool _dashOpen: false

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            root._dashOpen = ShellServices.ShellState.isOpenAnywhere("dashboard")
            if (root._dashOpen) root._refresh()
        }
    }

    // 1s cadence, but ONLY while the dashboard is open (running: _dashOpen) — zero
    // cost when closed. Fast enough that the sparkline buffer fills in ~30s. Peers
    // gate the same way (refcount/visibility) rather than persisting to disk.
    Timer {
        interval: 1000
        repeat: true
        running: root._dashOpen
        onTriggered: root._refresh()
    }

    function _refresh() {
        if (!statsProc.running) statsProc.running = true
    }

    Process {
        id: statsProc
        running: false
        command: ["bash", "-c",
            "c1=$(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8;i=$5;print t,i;exit}' /proc/stat); sleep 0.3; " +
            "c2=$(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8;i=$5;print t,i;exit}' /proc/stat); " +
            "t1=${c1% *}; i1=${c1#* }; t2=${c2% *}; i2=${c2#* }; " +
            "dt=$((t2-t1)); di=$((i2-i1)); cpu=0; [ $dt -gt 0 ] && cpu=$((100*(dt-di)/dt)); " +
            "echo cpu:$cpu; " +
            "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print \"ram:\" int((t-a)*100/t)}' /proc/meminfo; " +
            "pct=$(df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'); echo disk:${pct:-0}; " +
            "cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0); " +
            "st=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown); " +
            "echo bat:$cap:$st"
        ]
        stdout: SplitParser {
            onRead: line => {
                var sep = line.indexOf(":")
                if (sep < 0) return
                var key = line.slice(0, sep)
                var val = line.slice(sep + 1)
                if (key === "cpu")  { root.cpu  = parseInt(val) || 0; root.cpuHist  = root._push(root.cpuHist,  root.cpu)  }
                if (key === "ram")  { root.ram  = parseInt(val) || 0; root.ramHist  = root._push(root.ramHist,  root.ram)  }
                if (key === "disk") { root.disk = parseInt(val) || 0; root.diskHist = root._push(root.diskHist, root.disk) }
                if (key === "bat") {
                    var p = val.split(":")
                    root.bat       = parseInt(p[0]) || 0
                    root.batStatus = p[1] || "Unknown"
                    root.batHist   = root._push(root.batHist, root.bat)
                }
            }
        }
    }

    // ── Faces (req_003 / task_030) ───────────────────────────────────────────
    // Presentation is delegated to interchangeable faces over the same cpu/ram/
    // disk/bat data; the card keeps the data + poller (+ history) above. `face`
    // selects one (default = gauges). Wave 3 persists this choice.
    //   gauges    — radial rings (current value)
    //   bars      — labelled bars (current value)
    //   sparkline — detailed trend charts (uses rolling history)
    //   compact   — dense numbers only (smallest footprint)
    face: "gauges"
    faces: [
        { id: "gauges",    label: "Gauges",    file: Qt.resolvedUrl("faces/SystemStatusGauges.qml") },
        { id: "bars",      label: "Bars",      file: Qt.resolvedUrl("faces/SystemStatusBars.qml") },
        { id: "sparkline", label: "Sparkline", file: Qt.resolvedUrl("faces/SystemStatusSparkline.qml") },
        { id: "compact",   label: "Compact",   file: Qt.resolvedUrl("faces/SystemStatusCompact.qml") }
    ]
}
