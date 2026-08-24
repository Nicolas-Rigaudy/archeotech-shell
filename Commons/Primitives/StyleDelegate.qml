import QtQuick
import ".." as Commons

// Curated component style-delegate loader (adr_027 Layer C).
//
// A load-bearing component keeps its behaviour, props and slots (the STABLE
// contract) and delegates only its VISUAL to a pack-supplied QML resolved by
// filename convention — `<packDir>/styles/<componentId>.qml`. When the active
// pack ships no delegate for this id (or is minShellVersion-incompatible),
// `source` is "" and nothing loads: `active` stays false and the component draws
// its own base visual. So packs are purely additive and the base always works.
//
// The delegate receives ONE forward-compatible property: `api` — an object the
// host component fills with the state the visual needs (see docs/STYLE_API.md).
// Passing a single object (not N individual props) lets the contract grow new
// fields without breaking older delegates. Keep this Item behind the component's
// interactive layer (StateLayer etc. stay in the base component — this is chrome
// only, never interaction).
Loader {
    id: root

    // Which curated component this is (e.g. "GlassButton"), and the state object
    // the delegate reads. `api` is re-pushed whenever the host rebinds it.
    property string componentId: ""
    property var api: ({})

    source: Commons.Appearance.styleUrl(componentId)
    asynchronous: false

    // True only when a pack delegate actually loaded — the host hides its base
    // visual on this, so a failed/absent load safely falls back to the base.
    readonly property bool active: status === Loader.Ready && item !== null

    onLoaded: if (item) item.api = Qt.binding(function() { return root.api })
}
