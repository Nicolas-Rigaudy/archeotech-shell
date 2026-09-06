pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root

    // ── Aesthetic mode ───────────────────────────────────────────────────────
    // flatMode drops the DEPTH cues — no sheen gradient, no drop shadows — for a
    // flatter look. It does NOT touch opacity: the shell stays translucent glass in
    // both modes (transparency + blur are always on); flat is just glass minus the
    // skeuomorphic 3D. Opacity is a separate, PACK-driven decision (packMaterialFlat
    // → opaque slab) — see the glassBg/surfaceCard tokens. Set from shell.qml (bound
    // to Persistence.Config "appearance.flatMode"); Commons can't import a Service,
    // so it's a plain settable prop driven from above. depthFlat/shadowStrength gate
    // the shading branches; shared primitives multiply shadowStrength into shadow
    // alpha (1 = 3D, 0 = flat).
    property bool flatMode: false
    // depthFlat = "no depth cues" (sheen + shadows off). A "matte" pack is OPAQUE
    // but still DIMENSIONAL, so it keeps depth (depthFlat false) while packMaterialFlat
    // makes it opaque. With no matte pack, depthFlat == flatMode.
    readonly property bool depthFlat: flatMode && !root.packMaterialMatte
    readonly property real shadowStrength: depthFlat ? 0.0 : 1.0

    // Sheen helpers — the gradient-side twin of shadowStrength. A top-lit fill
    // (lighter top → darker bottom) reads as a raised, glossy surface; in
    // depthFlat mode that sheen must collapse so the fill reads as a flat slab,
    // just as shadowStrength zeroes the drop shadow. Pass the base fill + the
    // lighten/darken amount a surface already uses; depthFlat returns the bare
    // base, flattening the sheen while keeping the exact same colour. Called from
    // GradientStop bindings, so toggling flatMode re-evaluates them live.
    function sheenHi(base, amt) { return root.depthFlat ? base : Qt.lighter(base, amt) }
    function sheenLo(base, amt) { return root.depthFlat ? base : Qt.darker(base, amt) }

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
        var p = root._mergedPack
        if (p && p.colors && p.colors[key] !== undefined && p.colors[key] !== null)
            return p.colors[key]
        var d = root._data
        return (d && d.colors && d.colors[key]) || fallback
    }

    // Palette color name that drives `accent` (Sprint 25 accent picker). The
    // theme's top-level `accent` key holds a color name (e.g. "blue"); falls
    // back to "mauve" so themes without the key behave as before.
    readonly property string _accentName:
        (root._mergedPack && root._mergedPack.accent)
        || (root._data && root._data.accent) || "mauve"

    // A pack that ships its own palette (colors{}) owns the theme — the Catppuccin
    // family/flavor/accent pickers don't apply (Settings hides them; the pack's own
    // controls, e.g. a faction register, drive its colours instead).
    readonly property bool packOwnsPalette: !!(root._mergedPack && root._mergedPack.colors)

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

    // Pack-scoped settings (adr_027 Layer D): a flat map { "<dotted token path>":
    // value } persisted under Config `packs.<id>` and pushed here from shell.qml
    // (Commons can't import a Service). Each entry OVERRIDES that path in the
    // pack's token data, so a settings slider/toggle drives the real look through
    // the same getters below — no separate wiring, no fake toggles.
    property var packSettings: ({})

    // Active pack tokens with pack-settings overrides applied. Everything
    // pack-aware (_c, _accentName, _tok, fx, packWindow) reads THIS, not the raw
    // _packData, so overrides reach colours, tokens, fx and window decor alike.
    // Active pack tokens = pack base → active REGISTER overlay → pack-settings.
    // Registers (adr_027) re-livery the pack per faction (Legion / Ordos / Forge):
    // each deep-merges its colours + panels.steel over the base.
    readonly property var _mergedPack: {
        var m = root._packData ? JSON.parse(JSON.stringify(root._packData)) : ({})
        var reg = (root.packSettings && root.packSettings.register)
                  ? root.packSettings.register
                  : (m.defaultRegister || "")
        if (reg && m.registers && m.registers[reg]) root._deepMerge(m, m.registers[reg])
        if (root.packSettings) for (var k in root.packSettings) root._setPath(m, k, root.packSettings[k])
        return m
    }

    // Registers the active pack ships, and which one is live (for the pack's
    // palette selector — replaces the inert base colour selectors under a pack).
    readonly property var registers: (root._packData && root._packData.registers) ? root._packData.registers : ({})
    readonly property string activeRegister:
        (root.packSettings && root.packSettings.register) ? root.packSettings.register
        : ((root._packData && root._packData.defaultRegister) || "")

    function _deepMerge(target, src) {
        for (var k in src) {
            if (src[k] && typeof src[k] === "object" && !Array.isArray(src[k])) {
                if (typeof target[k] !== "object" || target[k] === null) target[k] = ({})
                root._deepMerge(target[k], src[k])
            } else target[k] = src[k]
        }
        return target
    }
    function _setPath(obj, path, val) {
        var parts = String(path).split(".")
        var o = obj
        for (var i = 0; i < parts.length - 1; i++) {
            if (typeof o[parts[i]] !== "object" || o[parts[i]] === null) o[parts[i]] = {}
            o = o[parts[i]]
        }
        o[parts[parts.length - 1]] = val
    }

    // Non-colour token lookup with pack overlay: pack[group][key] wins, else the
    // base literal supplied by the caller. Used by radius/spacing/font/bar below.
    function _tok(group, key, fallback) {
        var p = root._mergedPack
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

    // Corner style for the frame + popups: "chamfer" cuts the corner at 45° instead
    // of an arc. Consumed by FrameBackground (shape geometry) and popup cards so the
    // whole shell shares one corner language. Reads _mergedPack.frame.corners.
    readonly property bool frameChamfer: !!(root._mergedPack && root._mergedPack.frame
                                            && root._mergedPack.frame.corners === "chamfer")

    // Decorator/FX block from the active pack (adr_027 Wave 2). Consumed by the
    // FrameFx overlay: { glow{}, brackets{}, texture{} }, each optional. Empty
    // object when no pack (or no fx) — the base look stays untouched. Re-evaluates
    // on pack change (reads _packData) so the overlay reacts live.
    readonly property var fx: (root._mergedPack && root._mergedPack.fx) ? root._mergedPack.fx : ({})

    // Window-decoration block from the active pack (adr_027 — theme touches real
    // windows): { cornerRadius, borderWidth }. Applied to the compositor from
    // shell.qml (Commons can't import a Service). Empty ⇒ base window decoration.
    readonly property var packWindow: (root._mergedPack && root._mergedPack.window) ? root._mergedPack.window : ({})

    // Pack chrome surface (metal plating): a pack may ship a 9-slice plate asset
    // that the shared MetalSurface primitive renders behind cards/panels/pills so
    // the material propagates shell-wide. "" (no pack asset) → components use their
    // plain themed fill. Absolute file:// URL; `panels.surface` is pack-relative.
    readonly property string panelPlate:
        (root.activePackDir && root._mergedPack && root._mergedPack.panels && root._mergedPack.panels.surface)
            ? ("file://" + root.activePackDir + root._mergedPack.panels.surface) : ""

    // Flat welded-steel family (Grimdark). The frame (FrameFx) defines the
    // look; this single-sources its tones so the popups/cards/buttons match the
    // bezel instead of re-hardcoding. Pack `panels.steel` overrides; defaults
    // mirror the frame. Only consumed under a chamfer/matte pack — base look
    // never reads these. hi=top-lit, md=body, lo=lower, edge=recess/cut shadow,
    // lip=lit machined lip.
    function _steelTok(key, fb) {
        var p = root._mergedPack
        if (p && p.panels && p.panels.steel && p.panels.steel[key] !== undefined && p.panels.steel[key] !== null)
            return p.panels.steel[key]
        return fb
    }
    readonly property QtObject steel: QtObject {
        readonly property color hi:   root._steelTok("hi",   "#333f4d")
        readonly property color md:   root._steelTok("md",   "#28313d")
        readonly property color lo:   root._steelTok("lo",   "#1c232d")
        readonly property color edge: root._steelTok("edge", "#05080d")
        readonly property color lip:  root._steelTok("lip",  "#9fb0c2")
    }

    // Pack material (adr_027 / item_083): a pack may drop the base frosted-glass
    // look for a flat/matte "slab" (dataslate). Drives flatMode from shell.qml so
    // all the existing glass/flat branches follow — no per-component work.
    readonly property bool packMaterialFlat:
        !!(root._mergedPack && (root._mergedPack.material === "flat" || root._mergedPack.material === "matte"))
    // "matte" = opaque like flat (flatMode gates opacity), but KEEPS depth
    // (shadows + gradients) via depthFlat staying false. Dimensional plating.
    readonly property bool packMaterialMatte:
        !!(root._mergedPack && root._mergedPack.material === "matte")

    // ── Component style delegates (adr_027 Layer C) ──────────────────────────────
    // Current shell version, checked against a pack's minShellVersion before its
    // style delegates are honoured (the delegate prop contract is versioned).
    readonly property string shellVersion: "0.3.0"
    // Component ids the active pack ships a style delegate for, pushed from
    // shell.qml (PackRegistry, minShellVersion-gated — Commons can't import a
    // Service). A StyleDelegate loads `<packDir>/styles/<id>.qml` for these.
    property var activePackStyles: []
    // Resolve a component's pack style delegate URL, or "" to use the base visual.
    function styleUrl(componentId) {
        if (!root.activePackDir || root.activePackStyles.indexOf(componentId) === -1) return ""
        return "file://" + root.activePackDir + "styles/" + componentId + ".qml"
    }

    // Resolve an fx colour string: a palette name ("accent","mauve",…) maps to
    // the live theme colour; anything else is passed through as a literal colour.
    function fxColor(name, fallback) {
        if (!name) return fallback
        if (name === "accent") return root.colors.accent
        if (root.colors.hasOwnProperty(name)) return root.colors[name]
        return name
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
        // Lit copper — peach lightened (saturation kept) to the frame trim's PEACHY
        // read (its bright highlight lifts the same base). Panels use this for their
        // flat copper so they match the frame instead of showing the raw orange base.
        readonly property color copperLit: Qt.lighter(peach, 1.2)
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
        // Opacity is a PACK MATERIAL decision, not the user's flat toggle: only a
        // pack `material:"flat"|"matte"` (→ packMaterialFlat) makes the fills fully
        // OPAQUE (a solid slab, no wallpaper bleed). The base look — glass OR the
        // user's flat toggle — stays translucent; flat just drops the sheen/shadows.
        readonly property color glassBg:      root.packMaterialFlat ? root._c("mantle", "#1e2030") : root._rgba("mantle", "#1e2030", 0.96)
        readonly property color glassBgLight: root.packMaterialFlat ? root._c("mantle", "#1e2030") : root._rgba("mantle", "#1e2030", 0.93)
        readonly property color glassBorder:  root._rgba("surface0", "#363a4f", 0.90)

        // Liquid-glass sheen — endpoints for a subtle top-lit vertical gradient
        // (see FrameBackground). SAME alpha as glassBgLight (no transparency
        // change); only lightness varies: lifted toward surface1 at the top,
        // sunk toward crust at the bottom.
        readonly property color glassSheenTop: {
            // Truly flat: both stops collapse to the panel fill → no sheen gradient.
            // Matte keeps the top-lit gradient but OPAQUE (alpha 1) — grimdark plate.
            if (root.depthFlat) return glassBg
            var c = root._blend(root._c("mantle", "#1e2030"),
                                root._c("surface2", "#5b6078"), 0.38)
            return Qt.rgba(c.r, c.g, c.b, root.packMaterialFlat ? 1.0 : 0.93)
        }
        readonly property color glassSheenBot: {
            if (root.depthFlat) return glassBg
            // crust is barely darker than mantle, so sink toward black instead.
            var c = root._blend(root._c("mantle", "#1e2030"), "#000000", 0.22)
            return Qt.rgba(c.r, c.g, c.b, root.packMaterialFlat ? 1.0 : 0.93)
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
            // Opaque ONLY when a pack material demands it (flat/matte slab): un-tinted
            // surface0, no bleed. The base look — glass OR the user's flat toggle —
            // keeps the translucent card below; flat just drops sheen/shadow (depth).
            // NB: _c() returns a hex STRING; go through _rgba (which Qt.color-wraps
            // it) — Qt.rgba(str.r,…) would be Qt.rgba(undefined,…) = solid black.
            if (root.packMaterialFlat)
                return root._rgba("surface0", "#363a4f", 1.0)   // opaque slab, no bleed
            var c = root._blend(root._c("surface0", "#363a4f"),
                                root._c(root._accentName, "#c6a0f6"), 0.06)
            return Qt.rgba(c.r, c.g, c.b, 0.58)
        }
    }

    // ── Typography ─────────────────────────────────────────────────────────────
    // Font hook (adr_027 / item_083): a pack MAY ship its own display face for
    // headers (gothic/blackletter for a grimdark pack) while body text stays the mono
    // base for legibility. `font.displayFile` (pack-relative .ttf/.otf) is loaded
    // here via FontLoader; `font.displayFamily` names an already-installed family.
    // `font.display` resolves loaded-file → declared-family → body family.
    property FontLoader _displayFont: FontLoader {
        source: (root.activePackDir && root._mergedPack.font && root._mergedPack.font.displayFile)
                ? ("file://" + root.activePackDir + root._mergedPack.font.displayFile) : ""
    }

    readonly property QtObject font: QtObject {
        readonly property string family: root._tok("font", "family", "FiraCode Nerd Font")
        // Display/header face — falls back to the body family when the pack ships none.
        readonly property string display:
            (root._displayFont.status === FontLoader.Ready && root._displayFont.name)
                ? root._displayFont.name
                : root._tok("font", "displayFamily", family)
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
        // Console structure (adr_027 / item_083): a pack can segment the bar with
        // vertical seam dividers flanking the centre gauge, so it reads as bolted
        // instrument-panel sections. Off for the base look.
        readonly property bool dividers: root._tok("bar", "dividers", false)
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
