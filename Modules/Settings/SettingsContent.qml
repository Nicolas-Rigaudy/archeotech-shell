import QtQuick
import QtQuick.Layouts
import "./Panes"

// Shows the active settings pane. Panes are LAZY-loaded (Sprint 26 follow-up):
// opening Settings builds only the visible pane, not all 9 synchronously —
// that upfront build (Appearance's theme grid + wallpaper, Connections, Audio,
// Plugins…) was the open-delay. Each pane latches `seen` the first time it
// becomes current and stays loaded after, so re-switching is instant with no
// flash (the S24 StackLayout guarantee) — we only drop the upfront cost.
Item {
    id: root
    property int activeIndex: 0
    clip: true

    StackLayout {
        anchors.fill: parent
        currentIndex: root.activeIndex

        Repeater {
            model: root._paneComps.length
            delegate: Loader {
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property bool paneCurrent: StackLayout.isCurrentItem
                property bool seen: false
                onPaneCurrentChanged: if (paneCurrent) seen = true
                Component.onCompleted: if (paneCurrent) seen = true
                active: seen
                sourceComponent: root._paneComps[index]
            }
        }
    }

    // Order MUST match PaneRegistry.panes exactly (activeIndex selects by index).
    readonly property var _paneComps: [
        _appearance, _shell, _display, _notifications, _connections, _audio, _plugins, _power, _about
    ]
    Component { id: _appearance;    AppearancePane    {} }
    Component { id: _shell;         ShellPane         {} }
    Component { id: _display;       DisplayPane       {} }
    Component { id: _notifications; NotificationsPane {} }
    Component { id: _connections;   ConnectionsPane   {} }
    Component { id: _audio;         AudioPane         {} }
    Component { id: _plugins;       PluginsPane       {} }
    Component { id: _power;         PowerPane         {} }
    Component { id: _about;         AboutPane         {} }
}
