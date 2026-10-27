.pragma library
// When a state change should raise the OSD (item_120). The OSD follows the
// real volume / mute / brightness state, so a change from any source shows it:
// media keys, wpctl, pavucontrol, the bar sliders. The keybinds' own
// `ipc call osd …` still works; both paths only restart the hide timer.
// Pure, so tests/qml can check it without the shell.

// Startup: the first device reads (sink binding, brightnessctl get) are not
// user changes.
var ARM_DELAY_MS = 2000
// After the default sink changes (or binds/unbinds, e.g. a Bluetooth profile
// switch), its volume and mute arrive as a new value: not a user change.
var SINK_SETTLE_MS = 750

// kind: "volume" | "muted" | "brightness"
// prev, next: old and new value
// ctx: { now, armedAt, sinkChangedAt } in ms (armedAt = when the shell started)
// Returns the OSD type to show ("volume" | "brightness"), or "" for none.
function trigger(kind, prev, next, ctx) {
    if (prev === next) return ""
    var now = ctx.now
    if (now - ctx.armedAt < ARM_DELAY_MS) return ""
    if (kind === "brightness") return "brightness"
    if (kind !== "volume" && kind !== "muted") return ""
    if (ctx.sinkChangedAt !== undefined && now - ctx.sinkChangedAt < SINK_SETTLE_MS) return ""
    return "volume"
}
