import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons
import "../../../../Services/Persistence" as Persistence
import "../../../Settings" as Stg

// Sprint 24 — Settings as a unified shell panel (replaces the standalone
// FloatingWindow). Mounted inside the bottom-strip card via PanelRegistry,
// so it shares the glass chrome + popup→panel animation + ShellState
// single-open exclusion with every other panel.
//
// Layout mirrors the old Settings.qml: vertical nav sidebar | divider |
// pane carousel. Deep-linking (Commons.State.settingsOpenPane) and last-pane
// memory (Persistent.settingsActivePaneIndex) are preserved.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot: null

    function _applyDeepLink() {
        if (Commons.State.settingsOpenPane !== "") {
            sidebar.activeIndex = Stg.PaneRegistry.indexFor(Commons.State.settingsOpenPane)
            Commons.State.settingsOpenPane = ""
            return true
        }
        return false
    }

    // The content is recreated on every open (Loader gated by panelOpen), so
    // a deep-link pending at construction wins immediately; otherwise the
    // sidebar's initial binding (below) already starts on the remembered pane —
    // no post-paint jump, so no Appearance flash on reopen.
    Component.onCompleted: _applyDeepLink()

    // Deep-link request arriving while the panel is already mounted.
    Connections {
        target: Commons.State
        function onSettingsOpenPaneChanged() { root._applyDeepLink() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Stg.SettingsSidebar {
            id: sidebar
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            // Initial value at construction = the remembered pane, so the first
            // painted frame is already correct (fixes the reopen flash).
            activeIndex: Persistence.Persistent.settingsActivePaneIndex
            onActiveIndexChanged: Persistence.Persistent.settingsActivePaneIndex = activeIndex
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Commons.Appearance.colors.surface0
        }

        Stg.SettingsContent {
            Layout.fillWidth: true
            Layout.fillHeight: true
            activeIndex: sidebar.activeIndex
        }
    }
}
