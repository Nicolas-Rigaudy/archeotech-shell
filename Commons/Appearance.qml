pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root

    // ── Aesthetic mode ───────────────────────────────────────────────────────
    // flatMode flips the shell from the default "liquid glass" look to a flatter
    // one: no sheen gradient, no drop shadows, flatter cards. Set from shell.qml
    // (bound to Persistence.Config "appearance.flatMode"); Commons can't import a
    // Service without inverting layers, so it's a plain settable prop driven from
    // above. Tokens below branch on it; shared primitives multiply shadowStrength
    // into their shadow alpha (1 = glass, 0 = flat). ponytail: spike wires the
    // shared primitives (GlassButton/SettingsCard/DashCard) — one-off surfaces
    // still shadow until the polish rollout routes them through this too.
    property bool flatMode: false
    readonly property real shadowStrength: flatMode ? 0.0 : 1.0

    // ── Theme hot-reload ───────────────────────────────────────────────────────
    property var _data: ({})

    readonly property string _themePath:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/archeotech/theme.json"

    property FileView _themeFile: FileView {
        path: root._themePath
        watchChanges: true
        preload: true
        printErrors: false
        onTextChanged: {
            var content = text()
            if (!content || !content.trim()) return
            try { root._data = JSON.parse(content) } catch (_) {}
        }
    }

    // Colour lookup with pack overlay (adr_027 Layer A): the active pack's tokens
    // win, then base theme.json, then the hardcoded fallback.
    function _c(key, fallback) {
        var p = root._packData
        if (p && p.colors && p.colors[key] !== undefined && p.colors[key] !== null)
            return p.colors[key]
        var d = root._data
        return (d && d.colors && d.colors[key]) || fallback
    }

    // Palette color name that drives `accent` (Sprint 25 accent picker). The
    // theme's top-level `accent` key holds a color name (e.g. "blue"); falls
    // back to "mauve" so themes without the key behave as before.
    readonly property string _accentName:
        (root._packData && root._packData.accent)
        || (root._data && root._data.accent) || "mauve"

    function _rgba(key, fallback, alpha) {
        var c = Qt.color(root._c(key, fallback))
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    // Linear blend between two theme colors (t=0 → a, t=1 → b), preserving
    // alpha. Used for accent-tinted "surface container" warmth (§18.2 warmth).
    function _blend(a, b, t) {
        var ca = Qt.color(a), cb = Qt.color(b)
        return Qt.rgba(ca.r + (cb.r - ca.r) * t,
                       ca.g + (cb.g - ca.g) * t,
                       ca.b + (cb.b - ca.b) * t,
                       ca.a + (cb.a - ca.a) * t)
    }

    // Called by IpcHandler when theme-switch.sh writes a new theme.json.
    // Resets the file path to force FileView to re-read (watchChanges alone is unreliable).
    function reload() {
        var p = root._themePath
        root._themeFile.path = ""
        root._themeFile.path = p
    }

    // ── Active theme pack (adr_027 Layer A: token overlay) ───────────────────────
    // A pack is a plugin-style dir under $XDG_DATA_HOME
    // (~/.local/share/archeotech/packs/<id>/) shipping a tokens.json that OVERLAYS
    // the base theme.json. `activePack` is a plain settable prop driven from
    // shell.qml (bound to Persistence.Config "appearance.activePack"), same wiring
    // as flatMode. Empty string = base look, no overlay. `inherits` chaining is not
    // resolved yet — single-level overlay for now (Wave 1).
    property string activePack: ""       // pack id (informational; set from shell.qml)
    // Absolute pack dir (trailing slash), resolved from PackRegistry in shell.qml
    // and pushed here — Commons can't import a Service. Empty = base look.
    property string activePackDir: ""
    property var _packData: ({})
    onActivePackDirChanged: root._packData = ({})   // reset; _packFile repopulates from the new dir

    property FileView _packFile: FileView {
        path: root.activePackDir ? (root.activePackDir + "tokens.json") : ""
        watchChanges: true
        preload: true
        printErrors: false
        onTextChanged: {
            var content = text()
            if (!content || !content.trim()) { root._packData = ({}); return }
            try { root._packData = JSON.parse(content) } catch (_) { root._packData = ({}) }
        }
    }

    // Non-colour token lookup with pack overlay: pack[group][key] wins, else the
    // base literal supplied by the caller. Used by radius/spacing/font/bar below.
    function _tok(group, key, fallback) {
        var p = root._packData
        if (p && p[group] && p[group][key] !== undefined && p[group][key] !== null)
            return p[group][key]
        return fallback
    }

    // Frame corner radius override for the active pack (adr_027 Wave 2: shape).
    // The bar/strip corner connections are always-visible chrome, so a pack's
    // shape wins over the user's Settings→Shell corner radius; -1 = pack unset,
    // ShellConfig.cornerRadius() then falls back to the user config value.
    // Reads _packData so callers binding through cornerRadius() re-evaluate on
    // pack change (FrameBackground rebuilds imperatively — see its Connections).
    function packFrameRadius() {
        return root._tok("frame", "cornerRadius", -1)
    }

    // ── Palette (Macchiato defaults; all bindings re-evaluate on _data change) ─
    readonly property QtObject colors: QtObject {
        // Base surfaces
        readonly property color base:     root._c("base",     "#24273a")
        readonly property color mantle:   root._c("mantle",   "#1e2030")
        readonly property color crust:    root._c("crust",    "#181926")
        readonly property color surface0: root._c("surface0", "#363a4f")
        readonly property color surface1: root._c("surface1", "#494d64")
        readonly property color surface2: root._c("surface2", "#5b6078")

        // Text
        readonly property color text:     root._c("text",     "#cad3f5")
        readonly property color subtext1: root._c("subtext1", "#b8c0e0")
        readonly property color subtext0: root._c("subtext0", "#a5adcb")
        readonly property color overlay2: root._c("overlay2", "#939ab7")
        readonly property color overlay1: root._c("overlay1", "#8087a2")
        readonly property color overlay0: root._c("overlay0", "#6e738d")

        // Accents
        readonly property color mauve:    root._c("mauve",    "#c6a0f6")
        readonly property color blue:     root._c("blue",     "#8aadf4")
        readonly property color sapphire: root._c("sapphire", "#7dc4e4")
        readonly property color sky:      root._c("sky",      "#91d7e3")
        readonly property color teal:     root._c("teal",     "#8bd5ca")
        readonly property color green:    root._c("green",    "#a6da95")
        readonly property color yellow:   root._c("yellow",   "#eed49f")
        readonly property color peach:    root._c("peach",    "#f5a97f")
        readonly property color maroon:   root._c("maroon",   "#ee99a0")
        readonly property color red:      root._c("red",      "#ed8796")
        readonly property color pink:     root._c("pink",     "#f5bde6")
        readonly property color flamingo: root._c("flamingo", "#f0c6c6")
        readonly property color rosewater:root._c("rosewater","#f4dbd6")
        readonly property color lavender: root._c("lavender", "#b7bdf8")

        // Semantic aliases. The accent is the palette color named by the
        // theme's top-level `accent` key (Sprint 25 accent picker) — defaults
        // to mauve when unset (e.g. dark Catppuccin / non-accent families).
        readonly property color accent:  root._c(root._accentName, "#c6a0f6")
        readonly property color error:   red
        readonly property color warning: yellow
        readonly property color success: green
        readonly property color info:    blue

        // Transparent variants
        readonly property color baseAlpha:     root._rgba("base",     "#24273a", 0.85)
        readonly property color mantleAlpha:   root._rgba("mantle",   "#1e2030", 0.90)
        readonly property color surface0Alpha: root._rgba("surface0", "#363a4f", 0.60)
        readonly property color accentAlpha:   root._rgba(root._accentName, "#c6a0f6", 0.15)
        readonly property color accentBorder:  root._rgba(root._accentName, "#c6a0f6", 0.40)

        // Glass panel backgrounds
        readonly property color glassBg:      root._rgba("mantle",   "#1e2030", 0.96)
        readonly property color glassBgLight: root._rgba("mantle",   "#1e2030", 0.93)
        readonly property color glassBorder:  root._rgba("surface0", "#363a4f", 0.90)

        // Liquid-glass sheen — endpoints for a subtle top-lit vertical gradient
        // (see FrameBackground). SAME alpha as glassBgLight (no transparency
        // change); only lightness varies: lifted toward surface1 at the top,
        // sunk toward crust at the bottom.
        readonly property color glassSheenTop: {
            // Flat mode: both stops collapse to the panel fill → no sheen gradient.
            if (root.flatMode) return glassBg
            var c = root._blend(root._c("mantle", "#1e2030"),
                                root._c("surface2", "#5b6078"), 0.38)
            return Qt.rgba(c.r, c.g, c.b, 0.93)
        }
        readonly property color glassSheenBot: {
            if (root.flatMode) return glassBg
            // crust is barely darker than mantle, so sink toward black instead.
            var c = root._blend(root._c("mantle", "#1e2030"), "#000000", 0.22)
            return Qt.rgba(c.r, c.g, c.b, 0.93)
        }

        // ── Warmth (§18.2) — accent-tinted surfaces, not flat grey. ──
        // Resting container = surface0 pulled toward the accent, and more opaque
        // than surface0Alpha (0.60) so cards read as solid raised surfaces over
        // the glass rather than another sheet of the same grey. The M3 8%/0.60
        // values were invisible on our dark glass — dialled up during the
        // launcher taste-test (2026-07-17).
        readonly property color surfaceWarm: {
            var c = root._blend(root._c("surface0", "#363a4f"),
                                root._c(root._accentName, "#c6a0f6"), 0.15)
            return Qt.rgba(c.r, c.g, c.b, 0.85)
        }
        // State-layer tints (accent-hued). Punchier than the M3 0.08/0.12
        // canon — that wash didn't register on the dark palette.
        readonly property color stateHover:   root._rgba(root._accentName, "#c6a0f6", 0.20)
        readonly property color statePressed: root._rgba(root._accentName, "#c6a0f6", 0.30)

        // Elevated card surface (dashboard): a LIGHTER translucent glass than the
        // panel (surface0 > mantle) so it lifts off with the shadow, but stays
        // glassy — not opaque/plasticky. Only a whisper of accent warmth (0.06);
        // surfaceWarm's 0.15 was too much for a wall of cards.
        readonly property color surfaceCard: {
            // Flat mode: opaque, un-tinted surface0 — no glassy translucency or
            // accent warmth, so cards read as plain panels (shadow also off).
            // NB: _c() returns a hex STRING; go through _rgba (which Qt.color-wraps
            // it) — Qt.rgba(str.r,…) would be Qt.rgba(undefined,…) = solid black.
            if (root.flatMode)
                return root._rgba("surface0", "#363a4f", 0.90)
            var c = root._blend(root._c("surface0", "#363a4f"),
                                root._c(root._accentName, "#c6a0f6"), 0.06)
            return Qt.rgba(c.r, c.g, c.b, 0.58)
        }
    }

    // ── Typography ─────────────────────────────────────────────────────────────
    readonly property QtObject font: QtObject {
        readonly property string family: root._tok("font", "family", "FiraCode Nerd Font")
        readonly property int sizeSm:   root._tok("font", "sizeSm",   11)
        readonly property int sizeBase: root._tok("font", "sizeBase", 12)
        readonly property int sizeMd:   root._tok("font", "sizeMd",   13)
        readonly property int sizeLg:   root._tok("font", "sizeLg",   14)
        readonly property int sizeXl:   root._tok("font", "sizeXl",   16)
        readonly property int sizeIcon: root._tok("font", "sizeIcon", 16)
    }

    // ── Geometry ───────────────────────────────────────────────────────────────
    readonly property QtObject radius: QtObject {
        readonly property int sm:   root._tok("radius", "sm",   6)
        readonly property int base: root._tok("radius", "base", 8)
        readonly property int md:   root._tok("radius", "md",   10)
        readonly property int lg:   root._tok("radius", "lg",   14)
        readonly property int xl:   root._tok("radius", "xl",   18)
        readonly property int pill: root._tok("radius", "pill", 999)
    }

    readonly property QtObject spacing: QtObject {
        readonly property int xs:   root._tok("spacing", "xs",   4)
        readonly property int sm:   root._tok("spacing", "sm",   6)
        readonly property int base: root._tok("spacing", "base", 8)
        readonly property int md:   root._tok("spacing", "md",   10)
        readonly property int lg:   root._tok("spacing", "lg",   12)
        readonly property int xl:   root._tok("spacing", "xl",   16)
    }

    // ── Bar geometry ───────────────────────────────────────────────────────────
    readonly property QtObject bar: QtObject {
        readonly property int height:       root._tok("bar", "height",       30)
        readonly property int marginTop:    root._tok("bar", "marginTop",     0)
        readonly property int marginSide:   root._tok("bar", "marginSide",    0)
        readonly property int innerPadding: root._tok("bar", "innerPadding",  4)
    }

    // ── Animation ─────────────────────────────────────────────────────────────
    // Durations. Kept `fast`/`base`/`panel` as-is (used across ~125 call sites);
    // dropped the never-referenced `slow`/`spring`. New semantic names follow the
    // §18.2 converged ranges: effects (opacity/colour) short, spatial (move/size)
    // longer, and the enter/exit split ("enter gently, leave briskly").
    // Durations route through _tok so a pack's `anim` group can retune the whole
    // shell's motion (adr_027 Wave 2) — components already read these tokens.
    readonly property QtObject anim: QtObject {
        readonly property int fast:   root._tok("anim", "fast",   100)
        readonly property int base:   root._tok("anim", "base",   200)
        // Strip popup → panel transitions (perp + axis growth).
        readonly property int panel:  root._tok("anim", "panel",  240)

        // Effects — opacity / colour crossfades.
        readonly property int effectsFast: root._tok("anim", "effectsFast", 150)
        readonly property int effectsMed:  root._tok("anim", "effectsMed",  200)
        readonly property int effectsSlow: root._tok("anim", "effectsSlow", 300)
        // Spatial — position / size moves.
        readonly property int spatialFast:    root._tok("anim", "spatialFast",    350)
        readonly property int spatialDefault: root._tok("anim", "spatialDefault", 500)
        readonly property int spatialSlow:    root._tok("anim", "spatialSlow",    650)
        // Enter/exit asymmetry defaults.
        readonly property int enter: root._tok("anim", "enter", 400)
        readonly property int exit:  root._tok("anim", "exit",  200)
    }

    // ── Motion curves (§18.2) ────────────────────────────────────────────────
    // M3 bezier control-point lists for `easing.bezierCurve` (with
    // `easing.type: Easing.BezierSpline`). The `expressive*Spatial` curves have
    // a control-point y > 1 → overshoot-and-settle (no physics engine); use them
    // ONLY on spatial props (position/size), never on colour/opacity (they'd
    // flash). Effects/enter/exit pairs give the asymmetric "enter decel, exit
    // accel" idiom.
    // A pack's `curve` group may override any bezier control-point list (adr_027
    // Wave 2) — _tok returns the pack array when present, else the M3 default.
    readonly property QtObject curve: QtObject {
        readonly property var standard:      root._tok("curve", "standard",      [0.2, 0, 0, 1, 1, 1])
        readonly property var standardAccel: root._tok("curve", "standardAccel", [0.3, 0, 1, 1, 1, 1])
        readonly property var standardDecel: root._tok("curve", "standardDecel", [0, 0, 0, 1, 1, 1])

        readonly property var emphasized:      root._tok("curve", "emphasized",      [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1])
        readonly property var emphasizedAccel: root._tok("curve", "emphasizedAccel", [0.3, 0, 0.8, 0.15, 1, 1])
        readonly property var emphasizedDecel: root._tok("curve", "emphasizedDecel", [0.05, 0.7, 0.1, 1, 1, 1])

        readonly property var expressiveFastSpatial:    root._tok("curve", "expressiveFastSpatial",    [0.42, 1.67, 0.21, 0.90, 1, 1])
        readonly property var expressiveDefaultSpatial: root._tok("curve", "expressiveDefaultSpatial", [0.38, 1.21, 0.22, 1.00, 1, 1])
        readonly property var expressiveSlowSpatial:    root._tok("curve", "expressiveSlowSpatial",    [0.39, 1.29, 0.35, 0.98, 1, 1])
        readonly property var expressiveEffects:        root._tok("curve", "expressiveEffects",        [0.34, 0.80, 0.34, 1.00, 1, 1])
    }
}
