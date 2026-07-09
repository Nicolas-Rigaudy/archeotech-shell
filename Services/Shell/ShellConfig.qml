pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root

    readonly property var _defaults: ({
        sides: {
            top: {
                type: "bar",
                size: 30,
                zones: {
                    left:   ["workspaces", "title", "media"],
                    center: ["clock"],
                    right:  ["mic", "volume", "brightness", "network", "bluetooth", "battery", "notifications", "settings", "power"]
                }
            },
            right:  { type: "strip", size: 10, expanded: 44, icons: ["settings", "nc"] },
            bottom: { type: "strip", size: 10, expanded: 44, icons: ["dashboard", "media", "wallpaper"] },
            left:   { type: "strip", size: 10, expanded: 44, icons: ["launcher"] }
        },
        corners: { radius: 12, pillMode: false, pillGap: 6 },
        outerGap: 6,
        perScreen: {}
    })

    property var data: _defaults
    property bool ready: false

    // Captured from the loaded file so edit-mode writes preserve the
    // self-documenting "$schema" comment line.
    property string _schemaNote: ""

    function side(name, screenName) {
        var base = (data.sides && data.sides[name]) || _defaults.sides[name] || { type: "none" }
        if (screenName && data.perScreen && data.perScreen[screenName] && data.perScreen[screenName].sides && data.perScreen[screenName].sides[name]) {
            var override = data.perScreen[screenName].sides[name]
            var merged = {}
            for (var k in base) merged[k] = base[k]
            for (var k2 in override) merged[k2] = override[k2]
            return merged
        }
        return base
    }

    function sideType(name, screenName) {
        return side(name, screenName).type
    }

    // Sprint 26 — per-instance config. Entries are { id, config } objects; a bare
    // string id is the legacy form (pre-S26 shell-config.json). Normalize on read
    // so both forms load and old files keep working untouched.
    function _normEntry(e) {
        if (typeof e === "string") return { id: e, config: {} }
        if (e && typeof e === "object") return { id: e.id, config: e.config || {} }
        return { id: "", config: {} }
    }

    // ── Unified per-side content model (Sprint 26-C, phase 3) ────────────────────
    // A side is one ordered list `content: [{ id, config, align }]`. `align` is the
    // bar zone ("left"|"center"|"right"); "" means the strip/holder icon list.
    // `_sideContent` is the read-time shim: it reads `content` if present, else
    // flattens the legacy `zones{left,center,right}` (bar) / `icons[]` (strip) into
    // the same shape — so old files load untouched and mutators can write `content`
    // going forward. A single side may legitimately hold both flavours at once
    // (align "" plus align L/C/R): that's how a bar↔strip type flip stays
    // non-destructive — each renderer reads only the align matching its type.
    function _normContentEntry(e, defAlign) {
        var n = _normEntry(e)
        var a = (e && typeof e === "object" && e.align !== undefined) ? e.align : defAlign
        return { id: n.id, config: n.config, align: a }
    }
    function _sideContent(s) {
        if (!s) return []
        if (s.content) return s.content.map(function(e) { return root._normContentEntry(e, "") })
        var out = []
        if (s.zones) {
            var order = ["left", "center", "right"]
            for (var i = 0; i < order.length; i++) {
                var z = s.zones[order[i]] || []
                for (var j = 0; j < z.length; j++) out.push(root._normContentEntry(z[j], order[i]))
            }
        }
        if (s.icons)
            for (var k = 0; k < s.icons.length; k++) out.push(root._normContentEntry(s.icons[k], ""))
        return out
    }
    // Canonical accessor — the whole side as [{ id, config, align }] (phase 4 uses
    // this directly; phase 3 derives the legacy zone/strip views from it).
    function contentEntries(sideName, screenName) {
        return _sideContent(side(sideName, screenName))
    }

    // Re-group a content list so bar zones stay clustered (left, center, right),
    // then the strip list ("") and anything else in original order. filter() is
    // order-preserving, so this is a stable regroup without relying on sort().
    function _regroup(content) {
        var order = ["left", "center", "right"]
        var out = []
        for (var i = 0; i < order.length; i++)
            out = out.concat(content.filter(function(e) { return e.align === order[i] }))
        return out.concat(content.filter(function(e) { return order.indexOf(e.align) === -1 }))
    }

    // ── Derived legacy views — config-aware consumers (loaders, edit mode) keep
    // working over the split model while the renderers migrate (phase 4). A bar
    // zone is the content filtered by align; the strip list is align "" only. ──
    function zoneEntries(sideName, zone, screenName) {
        return contentEntries(sideName, screenName)
            .filter(function(e) { return e.align === zone })
            .map(function(e) { return { id: e.id, config: e.config } })
    }

    function stripEntries(sideName, screenName) {
        return contentEntries(sideName, screenName)
            .filter(function(e) { return e.align === "" })
            .map(function(e) { return { id: e.id, config: e.config } })
    }

    // Ids only — legacy id-consumers keep working regardless of file format.
    function zoneWidgets(sideName, zone, screenName) {
        return zoneEntries(sideName, zone, screenName).map(function(e) { return e.id })
    }

    function stripIcons(sideName, screenName) {
        return stripEntries(sideName, screenName).map(function(e) { return e.id })
    }

    function sideSize(sideName, screenName) {
        var s = side(sideName, screenName)
        return s.size !== undefined ? s.size : 10
    }

    function sideExpanded(sideName, screenName) {
        var s = side(sideName, screenName)
        return s.expanded !== undefined ? s.expanded : 56
    }

    // 0 for "none" sides, collapsed size otherwise. Drives ShellSurface side
    // margins, Panel cross-axis offsets, FrameBackground band geometry — anywhere
    // we need "how much room does this side reserve when at rest".
    //
    // A "holder" (Sprint 21) is hidden at rest — it reserves no space and
    // shows no chrome until revealed on hover/shortcut — so it reports 0 too.
    function sideGap(sideName, screenName) {
        var t = sideType(sideName, screenName)
        if (t === "none" || t === "holder") return 0
        return sideSize(sideName, screenName)
    }

    function cornerRadius() {
        return (data.corners && data.corners.radius !== undefined) ? data.corners.radius : _defaults.corners.radius
    }

    // Sprint 22 — global frame style. false = framed (sides hug the screen
    // edges; an end with no active neighbour rounds only its content-facing
    // corner; active neighbours join via concave blend). true = pill (every
    // side floats off the edge by a small gap and fully rounds all four corners;
    // no blends).
    function pillMode() {
        return (data.corners && data.corners.pillMode !== undefined)
            ? data.corners.pillMode : _defaults.corners.pillMode
    }

    // Gap between a floating pill-mode side and its screen edge. Also added to
    // the exclusion zone in pill mode so tiled windows keep matching clearance
    // on the side's inner edge.
    function pillGap() {
        return (data.corners && data.corners.pillGap !== undefined)
            ? data.corners.pillGap : _defaults.corners.pillGap
    }

    function outerGap() {
        return (data.outerGap !== undefined) ? data.outerGap : _defaults.outerGap
    }

    // ── Mutators (Sprint 21 — edit mode writes config back to disk) ─────────────
    // Every edit deep-clones `data`, reassigns it (fires onDataChanged → the
    // live Bar/Strip re-sync from config), then serializes to shell-config.json.
    // The FileView watch re-reads the same data and rebuilds `data`; it never
    // calls _save(), so there is no write loop (same pattern as Persistence/Config).
    function _save() {
        var out = {
            sides:     data.sides,
            corners:   data.corners,
            outerGap:  data.outerGap,
            perScreen: data.perScreen
        }
        if (_schemaNote) out["$schema"] = _schemaNote
        _file.setText(JSON.stringify(out, null, 2))
    }

    function _mutate(fn) {
        var d = JSON.parse(JSON.stringify(data))
        if (!d.sides) d.sides = {}
        fn(d)
        data = d
        _save()
    }

    // Strip↔bar entry compatibility (Sprint 26-C). A strip hosts panel-opener
    // icons; a bar hosts widgets. Panel-openers map both ways: a strip icon
    // becomes a bar entry (a dedicated widget where one exists, else the opener
    // id itself), and vice-versa. Bar widgets with no strip form (clock, volume,
    // …) map to null and are dropped on the way to a strip. Used to seed the
    // target flavour on a type switch so the side isn't empty after flipping.
    // Panel-opener ids are shared across holders (dashboard/launcher/wallpaper/
    // media/settings). Only nc differs — the bar opens it via the notifications
    // widget. Everything else on a bar (clock, volume, …) has no strip form.
    readonly property var _stripToBarWidget: ({ nc: "notifications" })
    readonly property var _barToStripPanel:  ({ notifications: "nc" })
    readonly property var _stripCapable: ({ nc: 1, dashboard: 1, media: 1, launcher: 1, wallpaper: 1, settings: 1 })
    // Convert a content entry to the other flavour, tagging the target align.
    // Bar seeds default to the right zone; strip seeds to the icon list ("").
    function _contentToBar(e) {
        if (_stripToBarWidget[e.id]) return { id: _stripToBarWidget[e.id], config: {}, align: "right" }
        return { id: e.id, config: e.config || {}, align: "right" }   // opener id is the same on a bar
    }
    function _contentToStrip(e) {
        if (e.id === "panel-opener")
            return (e.config && e.config.panelId) ? { id: e.config.panelId, config: {}, align: "" } : null
        if (_barToStripPanel[e.id]) return { id: _barToStripPanel[e.id], config: {}, align: "" }
        if (_stripCapable[e.id])    return { id: e.id, config: e.config || {}, align: "" }
        return null
    }
    function _compact(list) { return list.filter(function(x) { return !!x }) }

    // Switch a side's type (bar | strip | holder | none). The side keeps its one
    // `content` list; a flip only *seeds* the target flavour when that flavour is
    // empty, by converting the other flavour's compatible entries (panel-openers
    // carry across, incompatible widgets are dropped). The originals are kept, so
    // each renderer reads only its own align and toggling back and forth is
    // non-destructive and never duplicates.
    function setSideType(sideName, type) {
        _mutate(function(d) {
            var s = d.sides[sideName] || {}
            var content = root._sideContent(s)
            s.type = type
            if (type === "bar") {
                s.size = 30
                var hasBar = content.some(function(e) { return e.align === "left" || e.align === "center" || e.align === "right" })
                if (!hasBar)
                    content = content.concat(root._compact(
                        content.filter(function(e) { return e.align === "" }).map(root._contentToBar)))
            } else if (type === "strip" || type === "holder") {
                s.size = 10
                if (s.expanded === undefined) s.expanded = 240
                var hasStrip = content.some(function(e) { return e.align === "" })
                if (!hasStrip)
                    content = content.concat(root._compact(
                        content.filter(function(e) { return e.align !== "" }).map(root._contentToStrip)))
            }
            s.content = root._regroup(content)
            delete s.zones; delete s.icons
            d.sides[sideName] = s
        })
    }

    // Assign / reorder / clear a bar zone (left | center | right). Accepts
    // { id, config } entries or bare id strings (normalized either way), so
    // callers can pass entries to preserve per-instance config through reorder.
    // Rewrites the side's `content`: replace this zone's entries, keep the rest.
    function setZoneWidgets(sideName, zone, entries) {
        _mutate(function(d) {
            var s = d.sides[sideName] || { type: "bar" }
            var content = root._sideContent(s).filter(function(e) { return e.align !== zone })
            var add = entries.map(function(e) {
                var n = root._normEntry(e); return { id: n.id, config: n.config, align: zone }
            })
            s.content = root._regroup(content.concat(add))
            delete s.zones; delete s.icons
            d.sides[sideName] = s
        })
    }

    // Toggle the global pill/framed frame style (S22).
    function setPillMode(v) {
        _mutate(function(d) {
            if (!d.corners) d.corners = { radius: _defaults.corners.radius }
            d.corners.pillMode = v
        })
    }

    // Inner-corner radius of the frame (S24 — Shell settings). Routes through
    // shell-config so FrameBackground re-reads it and redraws consistently.
    function setCornerRadius(r) {
        _mutate(function(d) {
            if (!d.corners) d.corners = {}
            d.corners.radius = Math.round(r)
        })
    }

    // Breathing gap between the shell and tiled windows (drives exclusionZone).
    function setOuterGap(g) {
        _mutate(function(d) { d.outerGap = Math.round(g) })
    }

    // Assign / reorder / clear the icon list of a strip or holder side (align "").
    // Same { id, config } | bare-string normalization as setZoneWidgets. Keeps any
    // bar-flavour (align L/C/R) entries so a strip↔bar round trip is preserved.
    function setStripIcons(sideName, entries) {
        _mutate(function(d) {
            var s = d.sides[sideName] || { type: "strip" }
            var content = root._sideContent(s).filter(function(e) { return e.align !== "" })
            var add = entries.map(function(e) {
                var n = root._normEntry(e); return { id: n.id, config: n.config, align: "" }
            })
            s.content = root._regroup(content.concat(add))
            delete s.zones; delete s.icons
            d.sides[sideName] = s
        })
    }

    // Write per-instance config onto one entry, addressed by (align, position).
    // zone === "" (or null) targets the strip/holder icon list; otherwise a bar
    // zone — index is the position *within* that align's sublist (matches how the
    // renderer + edit-mode index the split view).
    function setEntryConfig(sideName, zone, index, config) {
        _mutate(function(d) {
            var s = d.sides[sideName]
            if (!s) return
            var target = zone || ""
            var content = root._sideContent(s)
            var seen = -1, at = -1
            for (var i = 0; i < content.length; i++) {
                if (content[i].align === target) { seen++; if (seen === index) { at = i; break } }
            }
            if (at === -1) return
            content[at].config = config || {}
            s.content = content
            delete s.zones; delete s.icons
            d.sides[sideName] = s
        })
    }

    property FileView _file: FileView {
        path: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/quickshell/shell-config.json"
        watchChanges: true
        preload: true
        printErrors: false
        onTextChanged: {
            var content = text()
            if (!content || !content.trim()) {
                root.data = root._defaults
                root.ready = true
                console.log("[ShellConfig] empty file, using defaults")
                return
            }
            try {
                var parsed = JSON.parse(content)
                root._schemaNote = parsed["$schema"] || ""
                root.data = {
                    sides:     parsed.sides     || root._defaults.sides,
                    corners:   parsed.corners   || root._defaults.corners,
                    outerGap:  parsed.outerGap  !== undefined ? parsed.outerGap : root._defaults.outerGap,
                    perScreen: parsed.perScreen || {}
                }
                root.ready = true
                console.log("[ShellConfig] loaded shell-config.json — sides:",
                    Object.keys(root.data.sides).map(function(k) { return k + "=" + root.data.sides[k].type }).join(" "))
            } catch (e) {
                console.warn("[ShellConfig] parse error, using defaults:", e)
                root.data = root._defaults
                root.ready = true
            }
        }
    }
}
