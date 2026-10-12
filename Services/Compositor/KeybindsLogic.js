.pragma library
// Keybind sheet logic (item_145): MangoWC config text → grouped, readable rows
// for the Super+K shortcuts panel. Pure (no Quickshell), tested in tests/qml.
//
// A row: { category, keys: [[label…] per chord], chips, desc, action, line }
//   keys        one entry per merged bind, e.g. [["Super","←"],["Super","→"]]
//   desc        first line of the comment just above the bind (trimmed of its
//               technical aside), else a description generated from the action
// Consecutive binds with the same modifiers, action and description merge into
// one row (Super + ←/→/↑/↓ "Focus movement", Super + 1…9 "Switch to tag").
// Categories come from WHAT a bind does (its mango function / command), so the
// sheet stays sensible for any config, not just a carefully commented one.
// Reads the one file it is given: `source=` includes are not followed.

var CATEGORY_ORDER = ["Apps", "Shell", "Windows", "Tags", "Monitors", "Layouts",
                      "Groups", "Tools", "Media & hardware", "System", "Mouse & gestures"]

// US labels for physical key codes (code:N), and AZERTY ones where they differ.
var CODE_US = { 10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9",
                19: "0", 20: "-", 21: "=", 34: "[", 35: "]", 49: "`", 51: "\\" }
var CODE_FR = { 10: "&", 11: "é", 12: "\"", 13: "'", 14: "(", 15: "-", 16: "è", 17: "_", 18: "ç",
                19: "à", 20: ")", 21: "=", 34: "^", 35: "$", 49: "²", 51: "*" }

var KEY_NAMES = {
    left: "←", right: "→", up: "↑", down: "↓", return: "Enter", space: "Space", tab: "Tab",
    semicolon: ";", comma: ",", period: ".", slash: "/", backslash: "\\", minus: "-", equal: "=",
    grave: "`", apostrophe: "'", bracketleft: "[", bracketright: "]", escape: "Esc",
    print: "Print", home: "Home", end: "End", delete: "Del", backspace: "Backspace",
    xf86audioraisevolume: "Vol +", xf86audiolowervolume: "Vol −", xf86audiomute: "Mute",
    xf86audiomicmute: "Mic mute", xf86audioplay: "Play/Pause", xf86audionext: "Next track",
    xf86audioprev: "Prev track", xf86monbrightnessup: "Bright +", xf86monbrightnessdown: "Bright −",
    btn_left: "Left click", btn_right: "Right click", btn_middle: "Middle click"
}
var MOD_NAMES = { super: "Super", shift: "Shift", ctrl: "Ctrl", alt: "Alt", none: "" }

function keyLabel(key) {
    var m = /^code:(\d+)$/.exec(key)
    if (m) {
        var us = CODE_US[m[1]], fr = CODE_FR[m[1]]
        if (!us) return "key " + m[1]
        return fr && fr !== us ? us + " / " + fr : us
    }
    var n = KEY_NAMES[key.toLowerCase()]
    if (n) return n
    return key.length === 1 ? key.toUpperCase() : key
}

function chord(mods, key) {
    var out = mods.split("+").map(x => MOD_NAMES[x.trim().toLowerCase()] !== undefined
                                       ? MOD_NAMES[x.trim().toLowerCase()] : x.trim())
                  .filter(x => x !== "")
    out.push(keyLabel(key))
    return out
}

// A comment line, minus its technical aside: a short "Label:" prefix gives way
// to the text after it; cut at " — ", " - ", ";" or a sentence end (outside
// parentheses); drop parentheticals longer than three words and an unbalanced "(".
function cleanDesc(text) {
    var t = text.replace(/^#+\s*/, "").trim()
    var colon = /^([^:()]+):\s+(\S.*)$/.exec(t)
    if (colon && colon[1].split(/\s+/).length <= 3) t = colon[2].charAt(0).toUpperCase() + colon[2].slice(1)
    var depth = 0
    for (var i = 0; i < t.length; i++) {
        var c = t[i]
        if (c === "(") depth++
        else if (c === ")") depth = Math.max(0, depth - 1)
        else if (depth === 0 && (t.substr(i, 3) === " — " || t.substr(i, 3) === " - " || c === ";"
                                 || (c === "." && (i === t.length - 1 || t[i + 1] === " ")))) {
            t = t.substr(0, i); break
        }
    }
    t = t.replace(/\s*\(([^()]*)\)/g, (all, inner) => inner.trim().split(/\s+/).length > 3 ? "" : all).trim()
    var open = t.lastIndexOf("("), close = t.lastIndexOf(")")
    if (open > close) t = t.substr(0, open).trim()
    t = t.replace(/:$/, "").trim()
    return t.charAt(0).toUpperCase() + t.slice(1)
}

// The description from the comment block directly above a bind: the first
// line, unless it is a short heading followed by a specific line ("# System
// controls" / "# Reload config"); later lines of a long explanation are
// continuations, not descriptions.
function pickDesc(block) {
    var useful = block.filter(b => !/^#\s*[a-z_]+:/.test(b))   // "# toggle_named_scratchpad: arg1=…" notes
    if (!useful.length) return ""
    var first = cleanDesc(useful[0])
    var last = useful[useful.length - 1].replace(/^#+\s*/, "")
    if (useful.length >= 2 && first.split(/\s+/).length <= 4 && /^[A-Z]/.test(last)) return cleanDesc(last)
    return first
}

function category(kind, key, fn, args) {
    if (kind === "mousebind" || kind === "gesturebind") return "Mouse & gestures"
    if (/^xf86/i.test(key)) return "Media & hardware"
    var cmd = args.join(",")
    if (fn === "spawn" || fn === "spawn_shell") {
        if (/qs\s.*ipc call/.test(cmd)) return "Shell"
        if (/wpctl|playerctl|brightnessctl|pamixer/.test(cmd)) return "Media & hardware"
        if (/grim|slurp|cliphist|color-picker|hyprpicker|wl-copy/.test(cmd)) return "Tools"
        if (/reload|gaming-mode|lock|hyprlock|wlogout|poweroff|reboot/.test(cmd)) return "System"
        return "Apps"
    }
    if (/^(view|tag|viewtoright|viewtoleft|toggleview|toggletag)$/.test(fn)) return "Tags"
    if (/^(focusmon|tagmon)$/.test(fn)) return "Monitors"
    if (/^(setlayout|switch_layout|switch_proportion_preset|incgaps|togglegaps|dwindle_.*|setmfact|incnmaster)$/.test(fn)) return "Layouts"
    if (/^group/.test(fn)) return "Groups"
    if (/^(quit|reload_config)$/.test(fn)) return "System"
    return "Windows"
}

// Readable fallbacks for common mango functions, used when a bind has no comment.
var FN_DESC = {
    viewtoright: "Next tag", viewtoleft: "Previous tag", toggleoverview: "Overview",
    killclient: "Close window", togglefloating: "Toggle floating", togglefullscreen: "Fullscreen",
    togglemaximizescreen: "Maximize", zoom: "Promote to master", reload_config: "Reload config",
    quit: "Exit compositor", toggle_scratchpad: "Scratchpad"
}
var DIR_DESC = { focusdir: "Focus window", exchange_client: "Swap window", focusstack: "Focus in stack",
                 focusmon: "Focus monitor", tagmon: "Move window to monitor" }

function describe(fn, args) {
    if (FN_DESC[fn]) return FN_DESC[fn]
    var a = (args[0] || "").trim()
    if (DIR_DESC[fn]) return DIR_DESC[fn] + (/^(-1|prev)$/.test(a) ? " (previous)" : /^(\+?1|next)$/.test(a) ? " (next)" : a ? " " + a : "")
    var cmd = args.join(",")
    if (fn === "spawn" || fn === "spawn_shell") {
        var ipc = /ipc call (\w+) (\w+)/.exec(cmd)
        if (ipc) return ipc[2].charAt(0).toUpperCase() + ipc[2].slice(1) + " " + ipc[1]
        var prog = cmd.trim().split(/\s+/)[0].replace(/^.*\//, "").replace(/\.sh$/, "")
        return "Run " + prog
    }
    var words = fn.replace(/_/g, " ")
    return words.charAt(0).toUpperCase() + words.slice(1) + (args.length && args[0] ? " " + args.join(" ") : "")
}

function parse(text) {
    var lines = text.split("\n")
    var rows = [], block = []          // the comment block right above the current line
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l === "") { block = []; continue }
        if (l[0] === "#") {
            if (/^#+\s*[#=─━-]{3,}/.test(l) || /^#{3,}/.test(l)) { block = []; continue }  // banners
            block.push(l)
            continue
        }
        var m = /^(binds?[a-z]*|mousebind|gesturebind)\s*=\s*(.*)$/.exec(l.replace(/\s+#\s.*$/, ""))  // trailing "# note"
        if (!m) { block = []; continue }
        var kind = m[1].indexOf("bind") === 0 && m[1] !== "mousebind" && m[1] !== "gesturebind" ? "bind" : m[1]
        var parts = m[2].split(",")
        var mods, keys, fn, args, key
        if (kind === "gesturebind") {
            // gesturebind=MODS,direction,fingers,func,args
            mods = parts[0]; fn = (parts[3] || "").trim(); args = parts.slice(4); key = ""
            keys = (parts[2] || "").trim() + "-finger swipe " + keyLabel((parts[1] || "").trim())
            keys = [chord(mods, "x").slice(0, -1).concat([keys])]
        } else {
            mods = parts[0]; fn = (parts[2] || "").trim(); args = parts.slice(3); key = (parts[1] || "").trim()
            keys = [chord(mods, key)]
        }
        var desc = pickDesc(block)
        var prev = rows.length ? rows[rows.length - 1] : null
        // Continue the previous row: same modifiers, action and category, and either
        // no new comment (the run shares the comment above its first bind) or the
        // same text. Only a COMMENTED row takes uncommented followers: two bare
        // `spawn` binds are different commands, not one shortcut.
        var cat = category(kind, key, fn, args)
        if (prev && prev._commented && prev._mods === mods && prev.action === fn && prev.category === cat
                && (desc === "" || desc === prev.desc)) {
            prev.keys.push(keys[0])
        } else {
            rows.push({ category: cat, keys: keys, desc: desc || describe(fn, args),
                        action: fn, line: i + 1, _mods: mods, _commented: desc !== "" })
        }
        block = []
    }
    rows.forEach(r => { delete r._mods; delete r._commented; r.chips = keyChips(r.keys) })
    return rows
}

// Rows grouped by category in CATEGORY_ORDER, filtered by a search query that
// matches the description, the action or any key label (case-insensitive).
function group(rows, query) {
    var q = (query || "").trim().toLowerCase()
    var hit = r => !q || r.desc.toLowerCase().indexOf(q) >= 0 || r.action.toLowerCase().indexOf(q) >= 0
                    || r.keys.some(k => k.join(" + ").toLowerCase().indexOf(q) >= 0)
    var out = []
    CATEGORY_ORDER.forEach(c => {
        var items = rows.filter(r => r.category === c && hit(r))
        if (items.length) out.push({ category: c, rows: items })
    })
    return out
}

// A merged row as keycap chips: the shared modifiers once, then the keys; a long
// digit run collapses to first … last ("…" is plain text, not a cap).
//   [["Super","1 / &"],…,["Super","9 / ç"]] → Super · 1 / & · … · 9 / ç
function keyChips(keys) {
    var out = keys[0].slice(0, -1).map(m => ({ text: m, cap: true }))
    var last = keys.map(k => k[k.length - 1])
    if (last.length > 3 && last.every(x => /^\d( \/ .)?$/.test(x)))
        last = [last[0], "…", last[last.length - 1]]
    last.forEach(t => out.push({ text: t, cap: t !== "…" }))
    return out
}

// Rows split into `n` columns for a masonry layout: whole categories, each to
// the currently shortest column (a card costs its rows plus a header).
function columns(groups, n) {
    var cols = [], h = []
    for (var i = 0; i < n; i++) { cols.push([]); h.push(0) }
    groups.forEach(g => {
        var k = h.indexOf(Math.min.apply(null, h))
        cols[k].push(g); h[k] += g.rows.length + 2
    })
    return cols
}

// A description as styled text: the trailing "(aside)" in the muted colour, so
// "Settings panel (alternate binding)" reads by its main words. HTML-escaped.
function styledDesc(desc, mutedColor) {
    var esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    var m = /^(.*\S)\s+(\([^()]*\))$/.exec(desc)
    if (!m) return esc(desc)
    return esc(m[1]) + " <font color=\"" + mutedColor + "\">" + esc(m[2]) + "</font>"
}
