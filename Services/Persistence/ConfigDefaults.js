.pragma library
// Defaults for config.json keys that Settings can reset (item_138), declared once.
// Config.get(key) with no second argument falls back to this table; a key here
// must not also carry an inline default at its call sites (tests/py enforces it).
// Reset removes the key from config.json, so the value follows this table again.

var DEFAULTS = {
    "appearance.fontScale":           1,
    "appearance.flatMode":            false,
    "appearance.glass":               "",        // "" = the mode's preset (glass-presets.json)
    "appearance.glassBlur":           "xray",    // layer blur over windows: xray (wallpaper) | windows
    "appearance.coverageBlur":        "auto",    // patched scenefx (coverage-weighted blur): auto (marker file) | on | off
    "clock.format":                   "24h",
    "clock.seconds":                  false,
    "clock.date":                     "short",
    "notifications.toastTimeout":     5000,
    "notifications.maxToasts":        5,
    "notifications.showOnFullscreen": false,
    "notifications.persistDnd":       false,
    "scroller.proportion":            0.98,
    "dashboard.scanRoots":            ["~/Projects"],
    "input.repeatDelay":              600,       // unset input.* = mango's own value
    "input.repeatRate":               25,
    "input.tapToClick":               true,
    "input.naturalScroll":            true,
    "input.disableWhileTyping":       true,
    "input.pointerSpeed":             0,
    "nightLight.temperature":         4000,
    "wallpaper.light":                "",        // item_140: "" = keep what is on screen
    "wallpaper.dark":                 ""
}

function has(key) { return DEFAULTS.hasOwnProperty(key) }
// Shared value: callers must copy an array/object before changing it.
function value(key) { return has(key) ? DEFAULTS[key] : undefined }

// True when `current` (undefined = unset) differs from the key's default.
function isModified(key, current) {
    if (current === undefined || !has(key)) return false
    return JSON.stringify(current) !== JSON.stringify(DEFAULTS[key])
}
