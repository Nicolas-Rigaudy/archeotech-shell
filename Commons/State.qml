pragma Singleton
import QtQuick

QtObject {
    property string settingsOpenPane:         ""

    // Keyboard panel (Super+K): which tab is shown, "shortcuts" or "characters".
    // Set by the `keybinds` IPC (Super+Shift+K opens Characters) and the tabs.
    property string keyboardTab:              "shortcuts"

    // Sprint 21 — visual builder. When true, every ShellSurface shows the
    // EditOverlay (click-to-assign editor). Toggled via `editmode` IPC /
    // Super+Shift+E.
    property bool   editMode:                 false

    // task_027 — Visual Builder drag-and-drop (adr_028). Global drag state lives
    // here, not in the Drag.mimeData payload: Wayland MIME handling is flaky, so
    // Drag.mimeData carries only a small "side:zone:index" locator and the real
    // widget key/source ride these singleton props (Caffyne "globals-not-payload"
    // trick). Only the EditOverlay writes them; they reset when a drag ends.
    property bool   dragActive:               false
    property string draggedKey:               ""   // widget id currently dragged
    property string draggedSource:            ""   // "side:zone:index" origin locator
}
