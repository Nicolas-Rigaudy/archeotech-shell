import QtQuick
import QtTest
import "../../Services/Compositor/KeybindsLogic.js" as Logic

// Keybind sheet parser (Services/Compositor/KeybindsLogic.js, item_145).
// The fixture mimics the shapes in a real mango config: headings, runs sharing
// one comment, code: number-row binds, XF86 keys, mouse and gesture binds.
// Run: tests/run.sh
TestCase {
    name: "KeybindsLogic"

    readonly property string conf: [
        "# ═══════════ Apps ═══════════",
        "# Terminal",
        "bind=SUPER,q,spawn,kitty",
        "bind=SUPER,r,spawn,qs -c archeotech ipc call launcher toggle",
        "",
        "# Focus movement (arrow keys)",
        "bind=SUPER,Left,focusdir,left",
        "bind=SUPER,Right,focusdir,right",
        "",
        "# Tag switching (tags 1-9 - empty tags hidden in waybar)",
        "bind=SUPER,code:10,view,1",
        "bind=SUPER,code:11,view,2",
        "bind=SUPER,code:12,view,3",
        "bind=SUPER,code:13,view,4",
        "",
        "# Tag navigation (next/previous)",
        "bind=SUPER,Tab,viewtoright",
        "bind=SUPER+SHIFT,Tab,viewtoleft",
        "",
        "# System controls",
        "# Reload config (via script — re-applies monitor layout)",
        "bind=SUPER+SHIFT,r,spawn,mango-reload.sh",
        "",
        "# Cycle focus through the stack (dwm-style). Reaches hidden windows",
        "# — the deck pile — which focusdir can't.",
        "bind=SUPER,j,focusstack,next",
        "",
        "# toggle_named_scratchpad: arg1=appid",
        "# Scratchpad (floating overlay terminal)",
        "bind=SUPER,code:49,toggle_named_scratchpad,kitty-sp,none,kitty",
        "",
        "# Audio controls (media keys)",
        "binds=NONE,XF86AudioRaiseVolume,spawn_shell,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && qs -c archeotech ipc call osd volume",
        "binds=NONE,XF86AudioMute,spawn_shell,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && qs -c archeotech ipc call osd volume",
        "",
        "mousebind=SUPER,btn_left,moveresize,curmove",
        "# 3-finger swipe - Navigate between windows",
        "# Natural direction: swipe left to focus window on the right (push current window left)",
        "gesturebind=NONE,left,3,focusdir,right",
        "border_color=0x000000ff"
    ].join("\n")

    function _rows() { return Logic.parse(conf) }
    function _find(rows, desc) { return rows.filter(r => r.desc === desc)[0] }

    function test_comments_become_descriptions() {
        var rows = _rows()
        verify(_find(rows, "Terminal"), "the comment above a bind")
        verify(_find(rows, "Reload config"), "heading + specific line: the specific line, aside cut")
        verify(_find(rows, "Cycle focus through the stack (dwm-style)"), "first sentence of a long note")
        verify(_find(rows, "Scratchpad (floating overlay terminal)"), "api notes (lowercase fn: lines) skipped")
        verify(_find(rows, "Swipe left to focus window on the right"), "Natural direction: prefix and long aside dropped")
        verify(_find(rows, "Tag switching"), "parenthetical of more than three words dropped")
        verify(_find(rows, "Focus movement"), "keycap-repeating aside dropped")
    }

    function test_fallback_descriptions() {
        var rows = _rows()
        verify(_find(rows, "Toggle launcher"), "qs ipc spawn → 'Toggle launcher'")
        verify(_find(rows, "Previous tag"), "uncommented bind after a run uses the function table")
    }

    function test_runs_merge() {
        var rows = _rows()
        compare(_find(rows, "Focus movement").keys.length, 2)
        compare(_find(rows, "Tag switching").keys.length, 4)
        compare(_find(rows, "Tag navigation (next/previous)").keys.length, 1, "different modifiers don't merge")
        compare(_find(rows, "Audio controls").keys.length, 2)
    }

    function test_categories() {
        var rows = _rows()
        compare(_find(rows, "Terminal").category, "Apps")
        compare(_find(rows, "Toggle launcher").category, "Shell")
        compare(_find(rows, "Tag switching").category, "Tags")
        compare(_find(rows, "Reload config").category, "System")
        compare(_find(rows, "Audio controls").category, "Media & hardware", "XF86 before the qs ipc rule")
        compare(rows.filter(r => r.action === "moveresize")[0].category, "Mouse & gestures")
        compare(rows.length, 12, "border_color and comments are not binds")
    }

    function test_key_labels() {
        compare(Logic.keyLabel("code:10"), "1 / &", "US label + AZERTY label")
        compare(Logic.keyLabel("code:21"), "=", "same on both layouts: one label")
        compare(Logic.keyLabel("code:49"), "` / ²")
        compare(Logic.keyLabel("Left"), "←")
        compare(Logic.keyLabel("q"), "Q")
        compare(Logic.keyLabel("XF86AudioMute"), "Mute")
        compare(Logic.chord("SUPER+SHIFT", "Return"), ["Super", "Shift", "Enter"])
        compare(Logic.chord("NONE", "Print"), ["Print"])
        var g = _rows().filter(r => r.action === "focusdir" && r.category === "Mouse & gestures")[0]
        compare(g.keys[0], ["3-finger swipe ←"])
    }

    function test_uncommented_binds_stay_apart() {
        var rows = Logic.parse("bind=SUPER,a,spawn,firefox\nbind=SUPER,b,spawn,kitty\nbind=SUPER,c,spawn,foo")
        compare(rows.length, 3, "bare spawns are different commands")
        compare(rows[1].desc, "Run kitty")
        var r = Logic.parse("bind=SUPER,x,spawn,grim -g x # region shot, quick")[0]
        compare(r.desc, "Run grim"); compare(r.category, "Tools", "inline comment dropped")
        compare(_find(_rows(), "Tag switching").chips.length, 4, "chips precomputed")
    }

    function test_group_and_search() {
        var rows = _rows()
        var all = Logic.group(rows, "")
        compare(all[0].category, "Apps", "CATEGORY_ORDER order")
        compare(all.reduce((n, g) => n + g.rows.length, 0), rows.length)
        var t = Logic.group(rows, "TAG")
        verify(t.every(g => g.rows.every(r => /tag/i.test(r.desc + r.action))), "case-insensitive description match")
        compare(Logic.group(rows, "enter").length, 0)
        compare(Logic.group(rows, "super + q").length, 1, "matches key labels")
        compare(Logic.group(rows, "zzz").length, 0)
    }

    function test_chips_and_sidebar() {
        var rows = _rows()
        var c = Logic.keyChips(_find(rows, "Tag switching").keys)
        compare(c.map(x => x.text), ["Super", "1 / &", "…", "4 / '"])
        compare(c[2].cap, false, "the ellipsis is not a keycap")
        compare(Logic.keyChips(_find(rows, "Terminal").keys).length, 2)
        var side = Logic.sidebar(rows, "")
        compare(side[0].category, "All")
        compare(side[0].count, rows.reduce((n, r) => n + r.keys.length, 0), "All counts key combos")
        compare(side.length, 1 + Logic.group(rows, "").length, "one entry per category present")
        var t = Logic.sidebar(rows, "terminal")
        compare(t.length, side.length, "searching keeps every category listed")
        compare(t.filter(e => e.category === "Apps")[0].count, 1)
        compare(t.filter(e => e.category === "Tags")[0].count, 0)
    }

    function test_styled_desc() {
        compare(Logic.styledDesc("Settings panel (alternate binding)", "#888"),
                "Settings panel <font color=\"#888\">(alternate binding)</font>")
        compare(Logic.styledDesc("Terminal", "#888"), "Terminal")
        compare(Logic.styledDesc("Media & <keys>", "#888"), "Media &amp; &lt;keys&gt;")
    }

    function test_noise_asides_dropped() {
        compare(Logic.cleanDesc("# App launcher (Quickshell)"), "App launcher")
        compare(Logic.cleanDesc("# Overview jump mode (mangowm 0.15)"), "Overview jump mode")
        compare(Logic.cleanDesc("# Focus movement (arrow keys)"), "Focus movement")
        compare(Logic.cleanDesc("# Settings panel (alternate binding)"), "Settings panel (alternate binding)")
        compare(Logic.cleanDesc("# Git TUI (Lazygit)"), "Git TUI (Lazygit)")
    }

    function test_labels_for_a_keyboard() {
        var fr = { "10": "&", "11": "é", "12": "\"", "13": "'", "49": "²" }
        var rows = Logic.parse(conf, fr)
        var tags = _find(rows, "Tag switching")
        compare(tags.keys[0], ["Super", "&"], "code:10 as printed on the AZERTY")
        compare(tags.chips.map(c => c.text), ["Super", "&", "…", "'"], "keycode run still collapses")
        compare(_find(rows, "Scratchpad (floating overlay terminal)").keys[0], ["Super", "²"])
        compare(_find(rows, "Terminal").keys[0], ["Super", "Q"], "keysym binds unchanged")
        compare(Logic.keyLabel("code:10", { "10": "1" }), "1")
        compare(Logic.keyLabel("code:10", {}), "1 / &", "no label: both")
    }
}
