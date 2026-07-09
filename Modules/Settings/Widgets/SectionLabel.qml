import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

// Shared settings section label (Sprint 24) — small uppercase caption above a
// group of rows. Replaces the per-pane inline `component SectionLabel` copies.
Text {
    Layout.fillWidth: true
    color: Commons.Appearance.colors.overlay0
    font.pixelSize: 10
    font.family: Commons.Appearance.font.family
    font.weight: Font.Medium
    font.letterSpacing: 1.5
}
