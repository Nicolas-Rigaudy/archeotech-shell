import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices

// Slim full-width strip at the dashboard bottom — a single line, no title.
DashCard {
    id: root

    property string tip:    ""
    property var    _lines: []

    FileView {
        // tips.txt is bundled in the shell repo's assets/ (moved there in the
        // repo split) — resolve relative to this file, not ~/.config/quickshell.
        path: Qt.resolvedUrl("../../../assets/tips.txt").toString().replace(/^file:\/\//, "")
        preload: true
        printErrors: false
        onTextChanged: {
            root._lines = text().split("\n").filter(l => l.trim().length > 0)
            root._pickTip()
        }
    }

    function _pickTip() {
        if (_lines.length > 0)
            tip = _lines[Math.floor(Math.random() * _lines.length)]
    }

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            if (ShellServices.ShellState.isOpenAnywhere("dashboard")) root._pickTip()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "TIP"
            color: Commons.Appearance.colors.accent
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.letterSpacing: 1.5
            opacity: 0.85
        }
        Text {
            Layout.fillWidth: true
            text: root.tip || "loading…"
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.italic: root.tip === ""
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
