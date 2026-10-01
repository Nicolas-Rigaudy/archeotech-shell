import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

// Shared settings section label (Sprint 24) — small uppercase caption above a
// group of rows. Replaces the per-pane inline `component SectionLabel` copies.
Text {
    Layout.fillWidth: true
    color: Commons.Appearance.colors.textMuted
    // Display face for section captions (Cinzel under a grimdark pack; body family otherwise).
    // Slightly larger than the mono caption so the inscriptional caps stay legible.
    readonly property bool _disp: Commons.Appearance.font.display !== Commons.Appearance.font.family
    font.pixelSize: _disp ? Commons.Appearance.font.sizeBase : Commons.Appearance.font.size2xs
    font.family: Commons.Appearance.font.display
    font.weight: Commons.Appearance.font.weightMedium
    font.letterSpacing: _disp ? Commons.Appearance.font.trackingDisplay : Commons.Appearance.font.trackingLabel
}
