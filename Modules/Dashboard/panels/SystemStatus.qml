import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

Rectangle {
    id: root
    implicitHeight: col.implicitHeight + 24
    color: Commons.Appearance.colors.mantle
    border.color: Commons.Appearance.colors.surface0
    border.width: 1
    radius: Commons.Appearance.radius.md

    property int    cpu:       0
    property int    ram:       0
    property int    disk:      0
    property int    bat:       0
    property string batStatus: "Unknown"

    Component.onCompleted: _refresh()

    property bool _dashOpen: false

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            root._dashOpen = ShellServices.ShellState.isOpenAnywhere("dashboard")
            if (root._dashOpen) root._refresh()
        }
    }

    Timer {
        interval: 5000
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
                if (key === "cpu")  root.cpu  = parseInt(val) || 0
                if (key === "ram")  root.ram  = parseInt(val) || 0
                if (key === "disk") root.disk = parseInt(val) || 0
                if (key === "bat") {
                    var p = val.split(":")
                    root.bat       = parseInt(p[0]) || 0
                    root.batStatus = p[1] || "Unknown"
                }
            }
        }
    }

    component StatRow: Item {
        required property string label
        required property int    value
        required property color  barColor
        height: 22

        Text {
            id: lbl
            text: label
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 42
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            anchors { left: lbl.right; leftMargin: 8; right: valLbl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: 5
            radius: 3
            color: Commons.Appearance.colors.surface0

            Rectangle {
                width: parent.width * Math.min(value, 100) / 100
                height: parent.height
                radius: parent.radius
                color: barColor
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            id: valLbl
            text: value + "%"
            color: Commons.Appearance.colors.text
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 32
            horizontalAlignment: Text.AlignRight
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        Text {
            text: "SYSTEM STATUS"
            color: Commons.Appearance.colors.accent
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.letterSpacing: 1.5
            opacity: 0.85
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

        StatRow { Layout.fillWidth: true; label: "CPU";  value: root.cpu;  barColor: Commons.Appearance.colors.blue }
        StatRow { Layout.fillWidth: true; label: "RAM";  value: root.ram;  barColor: Commons.Appearance.colors.mauve }
        StatRow { Layout.fillWidth: true; label: "Disk"; value: root.disk; barColor: Commons.Appearance.colors.peach }
        StatRow {
            Layout.fillWidth: true
            label: "Bat " + (root.batStatus === "Charging" ? "↑" : root.batStatus === "Discharging" ? "↓" : "─")
            value: root.bat
            barColor: root.bat > 20 ? Commons.Appearance.colors.green : Commons.Appearance.colors.red
        }
    }
}
