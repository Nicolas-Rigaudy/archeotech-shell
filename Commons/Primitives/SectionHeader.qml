import QtQuick
import ".." as Commons

Text {
    property string label: ""
    text: label

    color: Commons.Appearance.colors.overlay0
    font.pixelSize: Commons.Appearance.font.sizeSm - 1
    font.family: Commons.Appearance.font.family
    font.letterSpacing: 1.5
    font.weight: Font.Bold
    topPadding: 4
    bottomPadding: 2
}
