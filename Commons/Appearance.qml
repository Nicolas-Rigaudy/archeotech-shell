pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root

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

    function _c(key, fallback) {
        var d = root._data
        return (d && d.colors && d.colors[key]) || fallback
    }

    // Palette color name that drives `accent` (Sprint 25 accent picker). The
    // theme's top-level `accent` key holds a color name (e.g. "blue"); falls
    // back to "mauve" so themes without the key behave as before.
    readonly property string _accentName: (root._data && root._data.accent) || "mauve"

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

        // ── Warmth (§18.2) — accent-tinted surfaces, not flat grey. ──
        // Resting container = surface0 nudged toward the accent, at the same
        // 0.60 alpha as surface0Alpha so it drops in as a warm replacement.
        readonly property color surfaceWarm: {
            var c = root._blend(root._c("surface0", "#363a4f"),
                                root._c(root._accentName, "#c6a0f6"), 0.08)
            return Qt.rgba(c.r, c.g, c.b, 0.60)
        }
        // State-layer tints (M3 overlay alphas, accent-hued for warmth).
        readonly property color stateHover:   root._rgba(root._accentName, "#c6a0f6", 0.10)
        readonly property color statePressed: root._rgba(root._accentName, "#c6a0f6", 0.16)
    }

    // ── Typography ─────────────────────────────────────────────────────────────
    readonly property QtObject font: QtObject {
        readonly property string family: "FiraCode Nerd Font"
        readonly property int sizeSm:   11
        readonly property int sizeBase: 12
        readonly property int sizeMd:   13
        readonly property int sizeLg:   14
        readonly property int sizeXl:   16
        readonly property int sizeIcon: 16
    }

    // ── Geometry ───────────────────────────────────────────────────────────────
    readonly property QtObject radius: QtObject {
        readonly property int sm:   6
        readonly property int base: 8
        readonly property int md:   10
        readonly property int lg:   14
        readonly property int xl:   18
        readonly property int pill: 999
    }

    readonly property QtObject spacing: QtObject {
        readonly property int xs:  4
        readonly property int sm:  6
        readonly property int base: 8
        readonly property int md:  10
        readonly property int lg:  12
        readonly property int xl:  16
    }

    // ── Bar geometry ───────────────────────────────────────────────────────────
    readonly property QtObject bar: QtObject {
        readonly property int height:      30
        readonly property int marginTop:    0
        readonly property int marginSide:   0
        readonly property int innerPadding: 4
    }

    // ── Animation ─────────────────────────────────────────────────────────────
    // Durations. Kept `fast`/`base`/`panel` as-is (used across ~125 call sites);
    // dropped the never-referenced `slow`/`spring`. New semantic names follow the
    // §18.2 converged ranges: effects (opacity/colour) short, spatial (move/size)
    // longer, and the enter/exit split ("enter gently, leave briskly").
    readonly property QtObject anim: QtObject {
        readonly property int fast:   100
        readonly property int base:   200
        // Strip popup → panel transitions (perp + axis growth).
        readonly property int panel:  240

        // Effects — opacity / colour crossfades.
        readonly property int effectsFast: 150
        readonly property int effectsMed:  200
        readonly property int effectsSlow: 300
        // Spatial — position / size moves.
        readonly property int spatialFast:    350
        readonly property int spatialDefault: 500
        readonly property int spatialSlow:    650
        // Enter/exit asymmetry defaults.
        readonly property int enter: 400
        readonly property int exit:  200
    }

    // ── Motion curves (§18.2) ────────────────────────────────────────────────
    // M3 bezier control-point lists for `easing.bezierCurve` (with
    // `easing.type: Easing.BezierSpline`). The `expressive*Spatial` curves have
    // a control-point y > 1 → overshoot-and-settle (no physics engine); use them
    // ONLY on spatial props (position/size), never on colour/opacity (they'd
    // flash). Effects/enter/exit pairs give the asymmetric "enter decel, exit
    // accel" idiom.
    readonly property QtObject curve: QtObject {
        readonly property var standard:      [0.2, 0, 0, 1, 1, 1]
        readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property var standardDecel: [0, 0, 0, 1, 1, 1]

        readonly property var emphasized:      [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1]
        readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]

        readonly property var expressiveFastSpatial:    [0.42, 1.67, 0.21, 0.90, 1, 1]
        readonly property var expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property var expressiveSlowSpatial:    [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var expressiveEffects:        [0.34, 0.80, 0.34, 1.00, 1, 1]
    }
}
