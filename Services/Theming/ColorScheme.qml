pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons
import "../Persistence" as Persistence

// Sprint 25 — resolves the user's colour-scheme choices (family + flavor +
// light/dark mode + day-night schedule) into a concrete on-disk variant and
// applies it via theme-switch.py.
//
// Apply is IMPERATIVE: the UI setters (and the auto-schedule timer + boot)
// call _apply() directly. The family/mode/flavor* properties are reactive only
// for the UI to highlight the active choice — driving apply off a reactive
// `activeVariant` binding caused binding-loop re-entrancy (apply writes Config,
// which Config.get bindings depend on), so that approach was dropped.
//
//   mode: "dark" | "light" | "auto"  (auto → manual day-night schedule)
QtObject {
    id: root

    // ── Reactive display state (read by the picker UI) ──────────────────────────
    readonly property string family:      Persistence.Config.get("colorScheme.family", "catppuccin")
    readonly property string mode:        Persistence.Config.get("colorScheme.mode", "dark")
    readonly property string flavorDark:  Persistence.Config.get("colorScheme.flavorDark", "macchiato")
    readonly property string flavorLight: Persistence.Config.get("colorScheme.flavorLight", "latte")
    readonly property string lightStart:  Persistence.Config.get("colorScheme.lightStart", "07:00")
    readonly property string darkStart:   Persistence.Config.get("colorScheme.darkStart",  "19:00")
    // Accent = a palette color name (Catppuccin: "mauve", "blue", …). Empty
    // means "use the variant's built-in accent". Only meaningful for families
    // ThemeCatalog marks accent-capable (those with a non-empty accents list).
    readonly property string accent:      Persistence.Config.get("colorScheme.accent", "")

    property string _now: Qt.formatDateTime(new Date(), "HH:mm")
    readonly property bool isDaytime:
        mode === "auto" ? (_now >= lightStart && _now < darkStart) : (mode === "light")
    readonly property string effectiveMode: {
        var want = (mode === "auto") ? (isDaytime ? "light" : "dark") : mode
        if (want === "light" && !ThemeCatalog.hasLight(family)) return "dark"
        return want
    }

    // ── Resolve (pure read of current config → variant) ─────────────────────────
    function _resolveVariant() {
        var fam = Persistence.Config.get("colorScheme.family", "catppuccin")
        var md  = Persistence.Config.get("colorScheme.mode", "dark")
        var fd  = Persistence.Config.get("colorScheme.flavorDark", "macchiato")
        var fl  = Persistence.Config.get("colorScheme.flavorLight", "latte")
        var ls  = Persistence.Config.get("colorScheme.lightStart", "07:00")
        var ds  = Persistence.Config.get("colorScheme.darkStart", "19:00")
        var eff = md
        if (md === "auto") eff = (root._now >= ls && root._now < ds) ? "light" : "dark"
        if (eff === "light" && !ThemeCatalog.hasLight(fam)) eff = "dark"
        var flavor = eff === "light" ? fl : fd
        var v = ThemeCatalog.variantFor(fam, flavor)
        if (!v) v = ThemeCatalog.variantFor(fam, ThemeCatalog.defaultFlavor(fam, eff))
        return v
    }

    // Resolved accent to pass to theme-switch: the configured accent if the
    // family supports it, else "" (variant keeps its built-in accent).
    function _resolveAccent() {
        var fam = Persistence.Config.get("colorScheme.family", "catppuccin")
        var a   = Persistence.Config.get("colorScheme.accent", "")
        return ThemeCatalog.accentsFor(fam).indexOf(a) >= 0 ? a : ""
    }

    // ── Apply ────────────────────────────────────────────────────────────────────
    // _lastApplied is a "variant|accent" key so an accent-only change (same
    // variant) still re-applies instead of being deduped away.
    property string _lastApplied: ""
    // Queued: a second pick made while theme-switch is still running used to be
    // shown in the UI but never applied (a busy Process ignores running = true).
    property var _applyRunner: Commons.CommandRunner { label: "theme-switch" }

    function _apply() {
        if (!root._booted) return          // boot resolve applies once it can
        var v = _resolveVariant()
        if (!v) return
        var a = _resolveAccent()
        var pack = Commons.Appearance.activePackDir   // "" = base look
        var key = v + "|" + a + "|" + pack
        if (key === root._lastApplied) return
        root._lastApplied = key
        // A theme pack sits atop the hierarchy (adr_027): passing its dir makes
        // theme-switch overlay the pack's palette over the variant across every
        // app; clearing it (base) re-applies the plain variant → reversible.
        var cmd = [Commons.Paths.themeSwitch, v]
        if (a) cmd.push(a)
        if (pack) { cmd.push("--pack"); cmd.push(pack) }
        _applyRunner.run(cmd)
        Persistence.Config.set("theme.variant", v)
        // Persist the applied key so the next boot recognises a steady state and
        // skips theme-switch entirely (it used to re-run on every boot with a pack).
        // The key holds the pack's absolute dir, so moving the shell costs one extra
        // apply on the next boot, after which the stored key matches again.
        Persistence.Config.set("theme.appliedKey", key)
    }

    // Re-apply cross-app theming when the active pack changes (activePackDir is
    // resolved + pushed onto Appearance from shell.qml after pack discovery).
    property var _packConn: Connections {
        target: Commons.Appearance
        function onActivePackDirChanged() {
            if (!root._booted) root._bootResolve()   // the pack boot was waiting for
            else root._apply()
        }
    }

    // Auto-mode clock — re-resolve every minute; applies on day↔night crossing.
    property var _clock: Timer {
        interval: 60000; repeat: true; triggeredOnStart: false
        running: root.mode === "auto"
        onTriggered: { root._now = Qt.formatDateTime(new Date(), "HH:mm"); root._apply() }
    }

    // ── Boot: seed from the applied variant, then resolve once Config is ready ───
    // Boot waits for two things: config.json read (Config.ready) and, if config
    // names a pack, that pack's dir resolved by the pack scan. Resolving before
    // the pack dir was known seeded the dedup key without the pack, so the pack
    // arriving a moment later re-ran theme-switch on every boot. A pack that never
    // resolves (configured but not installed) stops blocking after 5 s.
    property bool _booted: false
    property bool _packWaitExpired: false
    property var _packWait: Timer {
        interval: 5000; repeat: false
        onTriggered: { root._packWaitExpired = true; root._bootResolve() }
    }

    function _bootResolve() {
        if (root._booted || !Persistence.Config.ready) return
        var wantPack = Persistence.Config.get("appearance.activePack", "")
        if (wantPack !== "" && Commons.Appearance.activePackDir === "" && !root._packWaitExpired) {
            if (!_packWait.running) _packWait.start()
            return
        }
        _packWait.stop()
        root._booted = true
        var applied = Persistence.Config.get("theme.variant", "archeotech-macchiato")
        if (Persistence.Config.get("colorScheme.family", "") === "") {
            Persistence.Config.set("colorScheme.family", ThemeCatalog.familyOfVariant(applied))
            var m = ThemeCatalog.modeOfVariant(applied)
            Persistence.Config.set("colorScheme.mode", m)
            if (m === "light") Persistence.Config.set("colorScheme.flavorLight", ThemeCatalog.flavorOfVariant(applied))
            else               Persistence.Config.set("colorScheme.flavorDark",  ThemeCatalog.flavorOfVariant(applied))
        }
        // Seed the dedup key to the on-disk state so a steady-state boot doesn't
        // redundantly re-run the whole switch — but a resolved difference (e.g.
        // auto-mode now resolves to the day flavor) still applies.
        root._lastApplied = Persistence.Config.get("theme.appliedKey",
            applied + "|" + _resolveAccent() + "|" + Commons.Appearance.activePackDir)
        root._apply()
    }
    property var _readyConn: Connections {
        target: Persistence.Config
        function onReadyChanged() { if (Persistence.Config.ready) root._bootResolve() }
    }
    Component.onCompleted: if (Persistence.Config.ready) _bootResolve()

    // ── Optional Zen relaunch ────────────────────────────────────────────────────
    // Zen reads its chrome CSS only at startup, so a theme switch can't hot-reload
    // it. With this on (default), an explicit picker change restarts a *running*
    // Zen — it restores its own session — ~2.5 s after the last change (debounced
    // so clicking through the picker doesn't thrash the browser). Armed only from
    // the user-facing setters via _armZenRestart(): never on boot or the auto
    // day-night clock, which would kill Zen on every login / at sunset.
    // OFF by default: Zen's chrome is its own workspace gradient (userChrome
    // can't recolor it), so restarting Zen on a theme change only refreshes minor
    // accent/text tint — not worth killing the browser for, and the churn left
    // stale profile locks. Toggle in Settings → Appearance → Behavior if you
    // still want it (e.g. once the palette→gradient DB-sync lands and Zen
    // actually follows themes, this becomes worthwhile).
    readonly property bool restartZen: Persistence.Config.get("colorScheme.restartZen", false)
    property var _zenProc: Process { command: []; running: false }
    property var _zenTimer: Timer {
        interval: 2500
        onTriggered: {
            // No-op if Zen isn't running; otherwise kill, wait for a clean exit,
            // then relaunch detached so it outlives this Process.
            // NB: match the process NAME (-x zen-bin), NOT the full cmdline
            // (-f) — this bash command's own cmdline contains "zen-bin", so
            // `pkill -f zen-bin` would kill THIS script before the relaunch line
            // ("kills but doesn't restart"). `-x zen-bin` matches only the
            // browser (comm=zen-bin); this script's comm is "bash".
            root._zenProc.command = ["bash", "-lc",
                "pgrep -x zen-bin >/dev/null 2>&1 || exit 0; pkill -x zen-bin; " +
                "for i in $(seq 1 30); do pgrep -x zen-bin >/dev/null 2>&1 || break; sleep 0.1; done; " +
                "setsid /opt/zen-browser-bin/zen-bin >/dev/null 2>&1 &"]
            root._zenProc.running = true
        }
    }
    function _armZenRestart() { if (root.restartZen) _zenTimer.restart() }

    // ── Setters (the UI calls these) — write config + apply immediately ──────────
    function setFamily(id) {
        Persistence.Config.set("colorScheme.family", id)
        var fd = ThemeCatalog.flavorById(id, root.flavorDark)
        if (!fd || fd.mode !== "dark")
            Persistence.Config.set("colorScheme.flavorDark", ThemeCatalog.defaultFlavor(id, "dark"))
        if (ThemeCatalog.hasLight(id)) {
            var fl = ThemeCatalog.flavorById(id, root.flavorLight)
            if (!fl || fl.mode !== "light")
                Persistence.Config.set("colorScheme.flavorLight", ThemeCatalog.defaultFlavor(id, "light"))
        }
        // Drop the accent if the new family doesn't offer it (e.g. catppuccin
        // "blue" → dracula, which has no accents) so we don't apply a stale one.
        if (ThemeCatalog.accentsFor(id).indexOf(root.accent) < 0)
            Persistence.Config.set("colorScheme.accent", "")
        _apply(); _armZenRestart()
    }
    function setMode(m)        { Persistence.Config.set("colorScheme.mode", m); _apply(); _armZenRestart() }
    function setFlavorDark(f)  { Persistence.Config.set("colorScheme.flavorDark", f); _apply(); _armZenRestart() }
    function setFlavorLight(f) { Persistence.Config.set("colorScheme.flavorLight", f); _apply(); _armZenRestart() }
    function setAccent(a)      { Persistence.Config.set("colorScheme.accent", a); _apply(); _armZenRestart() }
    function setLightStart(t)  { Persistence.Config.set("colorScheme.lightStart", t); _apply() }
    function setDarkStart(t)   { Persistence.Config.set("colorScheme.darkStart", t); _apply() }
    function setRestartZen(b)  { Persistence.Config.set("colorScheme.restartZen", b) }
}
