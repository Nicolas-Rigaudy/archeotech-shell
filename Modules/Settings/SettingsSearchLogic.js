.pragma library
// Settings search index (item_138): one entry per setting, so a result jumps to
// the row itself. Panes are lazy-loaded and cannot register rows before they are
// built, so the index is declared here; every `key` must match a `searchKey:`
// (or SearchTarget `key:`) in that pane's QML (tests/py/test_settings_search.py).
// `section` is the caption above the row; `keywords` add synonyms.

var INDEX = [
    // Appearance
    { pane: "appearance", key: "appearance.pack",     section: "Theme pack", label: "Theme pack",       keywords: "grimdark steel pack look" },
    { pane: "appearance", key: "appearance.theme",    section: "Theme",      label: "Theme",            keywords: "color colour scheme palette family flavor accent catppuccin macchiato mocha latte dracula nord gruvbox tokyo monochrome light dark mode schedule" },
    { pane: "appearance", key: "appearance.glass",    section: "Style",      label: "Opacity",          keywords: "glass solid transparency transparent see-through kitty" },
    { pane: "appearance", key: "appearance.glassBlur", section: "Style",     label: "Behind windows",   keywords: "blur frosted x-ray xray glass windows wallpaper see-through" },
    { pane: "appearance", key: "appearance.fontScale", section: "Style",     label: "Text size",        keywords: "typography font size scale larger smaller" },
    { pane: "appearance", key: "appearance.flatMode", section: "Style",      label: "Depth",            keywords: "flat 3d shadows sheen" },
    { pane: "appearance", key: "appearance.wallpaper", section: "Wallpaper", label: "Wallpaper",        keywords: "background image picker" },
    { pane: "appearance", key: "wallpaper.modes",     section: "Wallpaper",  label: "Light and dark wallpapers", keywords: "per mode separate day night background theme" },
    { pane: "appearance", key: "appearance.logo",     section: "Logo",       label: "Logo overlay",     keywords: "arch rebel imperial emblem sigil wallpaper" },
    // Shell
    { pane: "shell", key: "shell.editLayout",    section: "Customize", label: "Edit layout",         keywords: "visual builder edit mode bar strips widgets arrange add remove hide" },
    { pane: "shell", key: "shell.pillMode",      section: "Frame",     label: "Pill frame",          keywords: "float rounded edges" },
    { pane: "shell", key: "shell.cornerRadius",  section: "Frame",     label: "Corner radius",       keywords: "roundness corners" },
    { pane: "shell", key: "shell.outerGap",      section: "Frame",     label: "Outer gap",           keywords: "spacing margin windows" },
    { pane: "shell", key: "clock.format",        section: "Clock",     label: "Time format",         keywords: "24-hour 12-hour am pm clock" },
    { pane: "shell", key: "clock.seconds",       section: "Clock",     label: "Seconds",             keywords: "clock seconds" },
    { pane: "shell", key: "clock.date",          section: "Clock",     label: "Date",                keywords: "clock date format iso" },
    { pane: "shell", key: "scroller.proportion", section: "Scroller",  label: "Window width",        keywords: "scroller proportion focused peek mango" },
    { pane: "shell", key: "dashboard.notes",     section: "Dashboard · System notes", label: "System notes", keywords: "dashboard stats snapshot uptime updates kernel vpn host aws ip" },
    { pane: "shell", key: "dashboard.scanRoots", section: "Dashboard · Project folders", label: "Project folders", keywords: "dashboard active projects git repositories scan roots" },
    // Display
    { pane: "display", key: "display.layout",     section: "Monitor layout", label: "Monitor layout",  keywords: "arrange screen position resolution refresh rotation portrait scale enable" },
    { pane: "display", key: "display.autoApply",  section: "Profiles",       label: "Apply profiles automatically", keywords: "dock undock work home laptop saved layout" },
    { pane: "display", key: "display.profiles",   section: "Profiles",       label: "Display profiles", keywords: "save layout dock undock work home" },
    { pane: "display", key: "nightLight.enabled", section: "Night light",    label: "Night light",     keywords: "blue light warm gamma" },
    { pane: "display", key: "nightLight.temperature", section: "Night light", label: "Temperature",    keywords: "night light warmth kelvin" },
    // Input
    { pane: "input", key: "input.keyboardLayouts",   section: "Keyboards",  label: "Keyboard layout",      keywords: "azerty qwerty french us international accents altgr external" },
    { pane: "input", key: "input.repeatDelay",       section: "Key repeat", label: "Delay",                keywords: "key repeat delay typing" },
    { pane: "input", key: "input.repeatRate",        section: "Key repeat", label: "Rate",                 keywords: "key repeat rate speed typing" },
    { pane: "input", key: "input.tapToClick",        section: "Touchpad",   label: "Tap to click",         keywords: "touchpad trackpad tap" },
    { pane: "input", key: "input.naturalScroll",     section: "Touchpad",   label: "Natural scrolling",    keywords: "touchpad trackpad scroll direction reverse" },
    { pane: "input", key: "input.disableWhileTyping", section: "Touchpad",  label: "Disable while typing", keywords: "touchpad trackpad palm dwt" },
    { pane: "input", key: "input.pointerSpeed",      section: "Touchpad",   label: "Pointer speed",        keywords: "touchpad trackpad acceleration sensitivity cursor" },
    // Notifications
    { pane: "notifications", key: "notifications.toastTimeout",     section: "Toasts",    label: "Toast duration",        keywords: "notification popup timeout seconds" },
    { pane: "notifications", key: "notifications.maxToasts",        section: "Toasts",    label: "Max visible toasts",    keywords: "notification popup stack count" },
    { pane: "notifications", key: "notifications.showOnFullscreen", section: "Behaviour", label: "Show when fullscreen",  keywords: "notification toast fullscreen games video" },
    { pane: "notifications", key: "notifications.persistDnd",       section: "Behaviour", label: "Persist Do Not Disturb", keywords: "dnd silence mute remember restart" },
    // Connections
    { pane: "connections", key: "connections.wifi",      section: "Wi-Fi",     label: "Wi-Fi",     keywords: "wifi wireless network connect ssid password" },
    { pane: "connections", key: "connections.bluetooth", section: "Bluetooth", label: "Bluetooth", keywords: "bt pair device headset connect" },
    // Audio
    { pane: "audio", key: "audio.output",    section: "Output device", label: "Output device", keywords: "sink speakers headphones sound volume" },
    { pane: "audio", key: "audio.maxVolume", section: "Output device", label: "Max volume",    keywords: "volume limit cap sink" },
    { pane: "audio", key: "audio.input",     section: "Input device",  label: "Input device",  keywords: "source microphone mic recording" },
    // Plugins
    { pane: "plugins", key: "plugins.modules", section: "Installed modules", label: "Plugins & modules", keywords: "plugin module widget enable disable verified extension configure" },
    // Power
    { pane: "power", key: "power.profile", section: "Power profile", label: "Power profile",     keywords: "performance balanced saver battery mode" },
    { pane: "power", key: "power.dim",     section: "Idle & sleep",  label: "Dim screen on idle", keywords: "idle brightness timeout swayidle" },
    { pane: "power", key: "power.lock",    section: "Idle & sleep",  label: "Lock screen",       keywords: "idle lock timeout swayidle" },
    { pane: "power", key: "power.sleep",   section: "Idle & sleep",  label: "Sleep displays",    keywords: "idle suspend screen off timeout swayidle dpms" },
    // About
    { pane: "about", key: "about.environment", section: "Environment", label: "About",        keywords: "version system info quickshell archeotech" }
]

// Ranked matches for `query`: every whitespace-separated token must be a
// substring of label + section + keywords + pane label. A token in the label
// (best at its start) beats one in the section, which beats a keyword hit.
// `paneLabel(id)` maps a pane id to its label. Returns entries plus `_score`.
function search(query, paneLabel, limit) {
    var q = String(query || "").trim().toLowerCase()
    if (q === "") return []
    var tokens = q.split(/\s+/)
    var out = []
    for (var i = 0; i < INDEX.length; i++) {
        var e = INDEX[i]
        var label = e.label.toLowerCase(), section = e.section.toLowerCase()
        var rest = (e.keywords + " " + (paneLabel ? paneLabel(e.pane) : e.pane)).toLowerCase()
        var score = 0, ok = true
        for (var t = 0; t < tokens.length && ok; t++) {
            var tok = tokens[t], p
            if ((p = label.indexOf(tok)) !== -1)        score += p === 0 ? 0 : 10 + p
            else if ((p = section.indexOf(tok)) !== -1) score += 100 + p
            else if ((p = rest.indexOf(tok)) !== -1)    score += 1000 + p
            else ok = false
        }
        if (ok) out.push(Object.assign({ _score: score * 100 + e.label.length }, e))
    }
    out.sort(function (a, b) { return a._score - b._score })
    return out.slice(0, limit || 15)
}

function entryFor(key) {
    for (var i = 0; i < INDEX.length; i++) if (INDEX[i].key === key) return INDEX[i]
    return null
}
