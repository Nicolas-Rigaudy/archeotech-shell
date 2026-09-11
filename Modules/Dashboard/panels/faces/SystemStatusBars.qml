import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons

// SystemStatus face: "bars" (default) — labelled recessed track + sheened fill,
// one row per stat. Extracted verbatim from the pre-face SystemStatus card so the
// default look is unchanged. Binds to the owning card's data via `card`.
ColumnLayout {
    id: face
    property var card
    spacing: 8

    readonly property int _cpu: card ? card.cpu : 0
    readonly property int _ram: card ? card.ram : 0
    readonly property int _disk: card ? card.disk : 0
    readonly property int _bat: card ? card.bat : 0
    readonly property string _batStatus: card ? card.batStatus : "Unknown"

    component StatRow: Item {
        required property string label
        required property int    value
        required property color  barColor
        implicitHeight: 24

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
            height: 8
            radius: 4
            color: Commons.Appearance.colors.recessedTrack

            Rectangle {
                width: parent.width * Math.min(value, 100) / 100
                height: parent.height
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Commons.Appearance.sheenHi(barColor, Commons.Appearance.sheen.control.hi) }
                    GradientStop { position: 1.0; color: Commons.Appearance.sheenLo(barColor, Commons.Appearance.sheen.control.lo) }
                }
                Behavior on width { Commons.Anim {} }
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

    StatRow { Layout.fillWidth: true; label: "CPU";  value: face._cpu;  barColor: Commons.Appearance.colors.blue }
    StatRow { Layout.fillWidth: true; label: "RAM";  value: face._ram;  barColor: Commons.Appearance.colors.mauve }
    StatRow { Layout.fillWidth: true; label: "Disk"; value: face._disk; barColor: Commons.Appearance.colors.peach }
    StatRow {
        Layout.fillWidth: true
        label: "Bat " + (face._batStatus === "Charging" ? "↑" : face._batStatus === "Discharging" ? "↓" : "─")
        value: face._bat
        barColor: face._bat > 20 ? Commons.Appearance.colors.green : Commons.Appearance.colors.red
    }
}
