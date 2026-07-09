import QtQuick

// Example panel-content module (Sprint 21 Chunk 2; theming updated Sprint 26).
//
// Assigned to a strip, it gets an auto-generated opener icon; clicking toggles
// a panel whose content is this entry. `panelRoot` is injected (call
// panelRoot.close() to dismiss). Panel size comes from module.json
// `panel: { size, axisSize }`.
//
// Theming: loaded by absolute file:// URL, so `import "../../Commons"` won't
// resolve — declare `property var appearance`; the strip injects the shell's
// theme tokens. Guard uses (`_a ? … : fallback`) until it's set.
Item {
    id: root
    property var panelRoot
    property var appearance
    readonly property var _a: appearance

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            text: "󰎞  Quick Notes"
            color: _a ? _a.colors.accent : "#b4befe"
            font.family: _a ? _a.font.family : "sans-serif"
            font.pixelSize: _a ? _a.font.sizeLg : 16
            font.bold: true
        }

        Rectangle {
            width: parent.width; height: 1
            color: _a ? _a.colors.surface0 : "#313244"
        }

        Text {
            width: parent.width
            text: "This panel is a community module — a folder with a module.json + this QML, dropped into ~/.config/quickshell/modules/. It was discovered by ModuleRegistry, assigned to a strip in edit mode, and mounted here by the Strip card."
            color: _a ? _a.colors.subtext1 : "#bac2de"
            font.family: _a ? _a.font.family : "sans-serif"
            font.pixelSize: _a ? _a.font.sizeBase : 13
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }
}
