import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons

// SystemStatus face: "compact" — the SMALLEST view. Dense numbers only: a colored
// dot + label + value, four stats in a 2×2 grid. No bars, rings, or history.
// Binds to `card`.
GridLayout {
    id: face
    property var card
    columns: 2
    rowSpacing: 8
    columnSpacing: 18

    component Stat: RowLayout {
        required property string label
        required property int    value
        required property color  col
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            width: 8; height: 8; radius: 4; color: col
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            text: label
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
        }
        Item { Layout.fillWidth: true }
        Text {
            text: value + "%"
            color: Commons.Appearance.colors.text
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.bold: true
        }
    }

    Stat { label: "CPU";  value: face.card ? face.card.cpu  : 0; col: Commons.Appearance.colors.blue }
    Stat { label: "RAM";  value: face.card ? face.card.ram  : 0; col: Commons.Appearance.colors.mauve }
    Stat { label: "Disk"; value: face.card ? face.card.disk : 0; col: Commons.Appearance.colors.peach }
    Stat {
        label: "Bat"
        value: face.card ? face.card.bat : 0
        col: (face.card && face.card.bat > 20) ? Commons.Appearance.colors.green : Commons.Appearance.colors.red
    }
}
