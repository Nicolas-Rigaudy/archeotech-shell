pragma Singleton
import QtQuick
import Quickshell

// CompositorService — the compositor-agnostic facade (item_070).
//
// Detects the active compositor once at startup and routes a single stable API
// to the matching backend singleton (MangoService / HyprlandService). Every
// widget talks to THIS, never to a backend directly, so the shell renders the
// same across compositors and a new backend only has to implement this contract.
//
// Detection: Hyprland exports HYPRLAND_INSTANCE_SIGNATURE into the session; its
// absence means the wlroots/MangoWC path. Niri/Sway are post-1.0 (add a backend
// + extend this ternary).
QtObject {
    id: root

    readonly property bool isHyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    readonly property string compositor: isHyprland ? "hyprland" : "mango"

    // The active backend. Both are singletons in this directory; each self-gates
    // so only the running compositor's backend does real work — this just picks
    // which one answers. Swapping it needs NO widget-level change (AC3).
    readonly property QtObject backend: isHyprland ? HyprlandService : MangoService

    // ── Delegated state ─────────────────────────────────────────────────────────
    readonly property string focusedOutput: backend.focusedOutput

    // ── Delegated queries (per monitor name) ─────────────────────────────────────
    // Workspaces/tags as [{num, selected, occupied, urgent}] for the bar.
    function tagsFor(name)    { return backend.tagsFor(name) }
    function titleFor(name)   { return backend.titleFor(name) }
    function layoutFor(name)  { return backend.layoutFor(name) }
    function clientsFor(name) { return backend.clientsFor(name) }

    // ── Delegated actions ─────────────────────────────────────────────────────────
    function switchTag(outputName, tagNum)  { backend.switchTag(outputName, tagNum) }
    function dispatch(command)              { backend.dispatch(command) }
    function setProportion(p)               { backend.setProportion(p) }
    function setDefaultProportion(p)        { backend.setDefaultProportion(p) }
    function applyWindowDecor(radius, bpx)  { backend.applyWindowDecor(radius, bpx) }
}
