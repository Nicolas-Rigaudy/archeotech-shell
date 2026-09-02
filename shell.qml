//@ pragma UseQApplication
// QApplication mode (QtWidgets) is required for platform menus — the tray
// widget's right-click context menu (QsMenuAnchor) needs it. Harmless for the
// rest of the shell (QApplication is a superset of QGuiApplication).
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "Commons" as Commons
import "Services/Media" as MediaServices
import "Services/Hardware" as HardwareServices
import "Services/Networking" as NetworkServices
import "Services/Compositor" as CompositorServices
import "Services/System" as SystemServices
import "Services/Persistence" as Persistence
import "Services/Shell" as ShellServices
import "Services/Theming" as ThemeServices
import "Modules/OSD"
import "Modules/Shell" as Shell
import "Modules/NotificationCenter"

ShellRoot {
    id: shell

    // ── Singleton instantiation ────────────────────────────────────────────────
    property var _audio:         MediaServices.Audio
    property var _battery:       HardwareServices.Battery
    property var _network:       NetworkServices.Network
    property var _bt:            NetworkServices.Bluetooth
    property var _vpn:           NetworkServices.VPN
    property var _mango:         CompositorServices.MangoWC
    property var _brightness:    HardwareServices.Brightness
    property var _mpris:         MediaServices.MprisService
    property var _notifications: SystemServices.Notifications
    property var _config:        Persistence.Config
    property var _persistent:    Persistence.Persistent
    property var _shellConfig:   ShellServices.ShellConfig
    property var _shellState:    ShellServices.ShellState
    property var _panelRegistry: ShellServices.PanelRegistry
    property var _moduleRegistry: ShellServices.ModuleRegistry
    property var _colorScheme:   ThemeServices.ColorScheme

    Component.onCompleted: {
        console.log("[Sprint 17] shellConfig.ready =", _shellConfig.ready,
                    "  shellState screens =", Object.keys(_shellState.stateMap).join(","))
        // Touch a ColorScheme property to force eager singleton instantiation
        // (Quickshell singletons are lazy — a bare reference never runs their
        // Component.onCompleted, so the day-night/boot apply would never arm).
        _colorScheme.effectiveMode
    }

    // Drive the flat/glass aesthetic from the persisted setting. Commons can't
    // import a Service without inverting layers, so the token flag is set from
    // here (reactive: Config.get re-evaluates when the value changes).
    Binding {
        target: Commons.Appearance
        property: "flatMode"
        // The active pack's material can force flat/matte (drops glass) — adr_027;
        // else the persisted user toggle. (flatMode → base-pack setting is a later
        // refactor; the OR keeps the user toggle working until then.)
        value: Persistence.Config.get("appearance.flatMode", false) || Commons.Appearance.packMaterialFlat
    }

    // Drive the active theme pack (adr_027 Layer A) from the persisted setting,
    // same reason/wiring as flatMode. Empty string = base look (no token overlay).
    // activePackDir is resolved via PackRegistry here (Commons can't import a
    // Service); the binding re-evaluates when discovery finishes (packs changes).
    Binding {
        target: Commons.Appearance
        property: "activePack"
        value: Persistence.Config.get("appearance.activePack", "")
    }
    Binding {
        target: Commons.Appearance
        property: "activePackDir"
        value: ShellServices.PackRegistry.dirFor(Persistence.Config.get("appearance.activePack", ""))
    }
    // Component style-delegate ids for the active pack (adr_027 Layer C),
    // minShellVersion-gated in PackRegistry. Empty ⇒ base visuals everywhere.
    Binding {
        target: Commons.Appearance
        property: "activePackStyles"
        value: ShellServices.PackRegistry.stylesCompatible(
                   Persistence.Config.get("appearance.activePack", ""),
                   Commons.Appearance.shellVersion)
    }
    // Feed the running shell version to ModuleRegistry so it can gate plugins
    // whose minShellVersion the shell doesn't satisfy (Plugins pane + placement).
    Binding {
        target: ShellServices.ModuleRegistry
        property: "shellVersion"
        value: Commons.Appearance.shellVersion
    }
    // Pack-scoped settings (adr_027 Layer D): the active pack's Config object
    // { "<dotted token path>": value }, overriding matching pack token paths.
    Binding {
        target: Commons.Appearance
        property: "packSettings"
        value: {
            var id = Persistence.Config.get("appearance.activePack", "")
            return id ? Persistence.Config.get("packs." + id, ({})) : ({})
        }
    }

    // Apply the active pack's window decoration to the compositor (adr_027 — the
    // theme reaching the real windows: corner radius + border). Fires when the
    // pack (re)loads or changes; MangoWC.applyWindowDecor is idempotent (only
    // seds + reloads mango when a value actually differs), so no-op cases —
    // including every base-look startup — cost nothing. No `window` block ⇒ base
    // decoration (radius 12, border 2), so switching back to base restores it.
    Item {
        id: _winDecor
        function apply() {
            var w  = Commons.Appearance.packWindow
            var r  = (w && w.cornerRadius !== undefined) ? w.cornerRadius : 12
            var bp = (w && w.borderWidth  !== undefined) ? w.borderWidth  : 2
            CompositorServices.MangoWC.applyWindowDecor(r, bp)
        }
        Component.onCompleted: apply()
        Connections {
            target: Commons.Appearance
            function on_PackDataChanged()   { _winDecor.apply() }
            function onActivePackChanged()  { _winDecor.apply() }
            function onPackSettingsChanged() { _winDecor.apply() }   // window.* pack settings
        }
    }

    // ── IPC handlers ───────────────────────────────────────────────────────────

    IpcHandler {
        target: "theme"
        function reload() { Commons.Appearance.reload() }
    }

    IpcHandler {
        target: "notifications"
        function toggle() {
            if (ShellServices.ShellState.isOpenAnywhere("nc")) {
                ShellServices.ShellState.closeAllAcross()
            } else {
                ShellServices.ShellState.openGlobal("nc")
                SystemServices.Notifications.unreadCount = 0
            }
        }
        function open() {
            ShellServices.ShellState.openGlobal("nc")
            SystemServices.Notifications.unreadCount = 0
        }
        function close() { ShellServices.ShellState.closeAllAcross() }
    }

    IpcHandler {
        target: "launcher"
        function toggle() { ShellServices.ShellState.toggleGlobal("launcher") }
        function open()   { ShellServices.ShellState.openGlobal("launcher")  }
        function close()  { ShellServices.ShellState.closeAllAcross()        }
    }

    IpcHandler {
        target: "settings"
        function toggle()               { ShellServices.ShellState.toggleGlobal("settings") }
        function open()                 { ShellServices.ShellState.openGlobal("settings")  }
        function close()                { ShellServices.ShellState.closeAllAcross()         }
        function openPane(pane: string) { Commons.State.settingsOpenPane = pane; ShellServices.ShellState.openGlobal("settings") }
    }

    IpcHandler {
        target: "dashboard"
        function toggle()   { ShellServices.ShellState.toggleGlobal("dashboard") }
        function open()     { ShellServices.ShellState.openGlobal("dashboard")  }
        function close()    { ShellServices.ShellState.closeAllAcross()         }
        function openAuto() {
            Commons.State.dashboardAutoOpen = true
            ShellServices.ShellState.openGlobal("dashboard")
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() { ShellServices.ShellState.toggleGlobal("wallpaper") }
        function open()   { ShellServices.ShellState.openGlobal("wallpaper")  }
        function close()  { ShellServices.ShellState.closeAllAcross()         }
    }

    IpcHandler {
        target: "media"
        function toggle() { ShellServices.ShellState.toggleGlobal("media") }
        function open()   { ShellServices.ShellState.openGlobal("media")  }
        function close()  { ShellServices.ShellState.closeAllAcross()     }
    }

    // Tiling-layout picker (Super+Shift+T). Visual alternative to the Super+T cycle.
    IpcHandler {
        target: "layout"
        function toggle() { ShellServices.ShellState.toggleGlobal("layout") }
        function open()   { ShellServices.ShellState.openGlobal("layout")  }
        function close()  { ShellServices.ShellState.closeAllAcross()      }
    }

    // Sprint 21 — visual builder edit mode (Super+Shift+E). Closes any open
    // panel when entering so the editor has the surface to itself.
    IpcHandler {
        target: "editmode"
        function toggle() { shell._setEditMode(!Commons.State.editMode) }
        function open()   { shell._setEditMode(true)  }
        function close()  { shell._setEditMode(false) }
    }

    function _setEditMode(on) {
        if (on) ShellServices.ShellState.closeAllAcross()
        Commons.State.editMode = on
    }

    // Settings is now a ShellState panel (Sprint 24), so single-open exclusion
    // is handled by ShellState itself — the old settings↔panels mutual-exclusion
    // Connections were removed.

    // ── Toast queue ────────────────────────────────────────────────────────────
    property var _toastQueue: []

    Connections {
        target: SystemServices.Notifications
        function onArrived(notification) {
            if (!SystemServices.Notifications.dndEnabled) {
                shell._toastQueue = shell._toastQueue.concat([{
                    appIcon:       notification.appIcon       || "",
                    appName:       notification.appName       || "",
                    summary:       notification.summary       || "",
                    body:          notification.body          || "",
                    urgency:       notification.urgency       || 0,
                    expireTimeout: notification.expireTimeout || -1
                }])
            }
        }
    }

    // ── OSD — one per screen ──────────────────────────────────────────────────
    Variants {
        id: osdVariants
        model: Quickshell.screens
        delegate: Osd {
            required property var modelData
            screen: modelData
        }
    }

    function _osdShow(type) {
        var items = osdVariants.instances
        for (var i = 0; i < items.length; i++)
            items[i].show(type)
    }

    IpcHandler {
        target: "osd"
        function volume()     { shell._osdShow("volume") }
        function brightness() { shell._osdShow("brightness") }
    }

    // Full-screen overlay per monitor — hosts the 4 sides (bar/strip/none),
    // the frame background, and panels (NC/Launcher/Dashboard/Wallpaper/
    // Settings) as siblings in one coordinate space.
    Shell.ShellSurface  {}

    // Thin compositor-exclusion windows, one per active side per monitor.
    // exclusiveZone = sideSize + outerGap.
    Shell.ShellExclusions {}

    // ── Toast layer ───────────────────────────────────────────────────────────
    PanelWindow {
        id: toastWindow
        visible: shell._toastQueue.length > 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:toasts"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; right: true }
        // +48 (24 each side) so the toast cards' drop shadow can bleed instead
        // of being clipped hard by the layer-surface edge.
        implicitWidth:  316 + 48
        implicitHeight: toastStack.implicitHeight
                      + Commons.Appearance.bar.marginTop
                      + Commons.Appearance.bar.height
                      + 48
        color: "transparent"

        Column {
            id: toastStack
            anchors.right:      parent.right
            anchors.rightMargin: 24
            anchors.top:        parent.top
            anchors.topMargin:  Commons.Appearance.bar.marginTop + Commons.Appearance.bar.height + 16
            width: 316
            spacing: 8

            Repeater {
                model: shell._toastQueue
                delegate: Item {
                    required property int index
                    required property var modelData
                    width: 316
                    height: _toast.height

                    NotifToast {
                        id: _toast
                        width: 316
                        notification: parent.modelData
                        onDismissClicked: {
                            var q = shell._toastQueue.slice()
                            q.splice(parent.index, 1)
                            shell._toastQueue = q
                        }
                        onTimedOut: {
                            var q = shell._toastQueue.slice()
                            q.splice(parent.index, 1)
                            shell._toastQueue = q
                        }
                    }
                }
            }
        }
    }

}
