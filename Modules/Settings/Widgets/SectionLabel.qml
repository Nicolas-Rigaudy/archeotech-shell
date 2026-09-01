import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

// Shared settings section label (Sprint 24) — small uppercase caption above a
// group of rows. Replaces the per-pane inline `component SectionLabel` copies.
Text {
    Layout.fillWidth: true
    color: Commons.Appearance.colors.overlay0
    // Display face for section captions (Cinzel under a 40K pack; body family otherwise).
    // Slightly larger than the mono caption so the inscriptional caps stay legible.
    readonly property bool _disp: Commons.Appearance.font.display !== Commons.Appearance.font.family
    font.pixelSize: _disp ? 12 : 10
    font.family: Commons.Appearance.font.display
    font.weight: Font.Medium
    font.letterSpacing: _disp ? 1.0 : 1.5
}
