import QtQuick

// Example bar-zone module (Sprint 21 Chunk 2; theming updated Sprint 26).
//
// A module's entry follows the same contract as a built-in bar widget: it
// receives `holderRoot` + `widgetId` injected via Loader.setSource, and may use
// holderRoot's popup API (see docs/WIDGET_API.md).
//
// Theming: a module loaded from a modules dir is mounted by absolute file://
// URL, so `import "../../Commons"` does NOT resolve. Instead declare
// `property var appearance` — the loader injects the shell's theme tokens
// (colors / font / radius / spacing / anim). Guard uses until it arrives
// (`_a ? … : fallback`), since it's set just after the object is created.
Item {
    id: root
    required property var    holderRoot
    required property string widgetId
    property var appearance
    readonly property var _a: appearance

    implicitWidth:  label.implicitWidth + 14
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: _a ? _a.radius.sm : 6
        color: (ma.containsMouse && _a) ? _a.colors.surface0Alpha : "transparent"
        Behavior on color { ColorAnimation { duration: _a ? _a.anim.fast : 120 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: "󰜗 hello"
            color: _a ? _a.colors.text : "#cdd6f4"
            font.family: _a ? _a.font.family : "sans-serif"
            font.pixelSize: _a ? _a.font.sizeBase : 13
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.holderRoot.showPopup(root, "Hello", "An example bar-zone module", "Sprint 21 · Chunk 2", "")
            onExited:  root.holderRoot.hidePopup(root)
        }
    }
}
