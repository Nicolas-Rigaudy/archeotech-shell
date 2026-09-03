pragma Singleton
import QtQuick

QtObject {
    property string settingsOpenPane:         ""

    // Sprint 21 — visual builder. When true, every ShellSurface shows the
    // EditOverlay (click-to-assign editor). Toggled via `editmode` IPC /
    // Super+Shift+E.
    property bool   editMode:                 false
}
