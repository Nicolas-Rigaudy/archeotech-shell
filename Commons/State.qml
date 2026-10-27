pragma Singleton
import QtQuick

QtObject {
    property string settingsOpenPane:         ""
    // Settings search (item_138): the row to reveal once its pane is shown. The
    // SearchTarget whose key matches scrolls to its row, pulses it and clears this;
    // the serial re-fires a pick of the same key twice.
    property string settingsFocusKey:         ""
    property int    settingsFocusSerial:      0

    // Keyboard panel (Super+K): which tab is shown, "shortcuts" or "characters".
    // Set by the `keybinds` IPC (Super+Shift+K opens Characters) and the tabs.
    property string keyboardTab:              "shortcuts"

    // Hover/click popups opened without a pointer (`ipc call popup open <name>`,
    // `shot.sh --state popup:<name>`): "wifi" | "bt" | "calendar" | "hover" | "strip"
    // | "". Lets headless renders check popups that otherwise need a mouse (item_116).
    property string popupProbe:               ""

    // Launcher pre-fill (`ipc call launcher search <text>`): the text the launcher
    // starts with on its next open (or at once if open). It takes it and clears it.
    property string launcherQuery:            ""

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
