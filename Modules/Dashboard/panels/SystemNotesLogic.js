.pragma library
// Pure System Notes logic (dashboard card + Settings → Shell → Dashboard), kept
// out of QML so tests/qml can unit-test it (qmltestrunner has no Quickshell).

// The stat registry, in display order. `id` is what "dashboard.notes" stores.
var STATS = [
    { id: "snapshot", label: "Snapshot", description: "Latest snapper snapshot of the root config" },
    { id: "uptime",   label: "Uptime",   description: "Time since boot" },
    { id: "updates",  label: "Updates",  description: "Pending pacman + AUR updates (checked at most every 30 min)" },
    { id: "kernel",   label: "Kernel",   description: "Running kernel release" },
    { id: "vpn",      label: "VPN",      description: "Active NetworkManager VPN or WireGuard connection" },
    { id: "host",     label: "Host",     description: "Hostname" },
    { id: "aws",      label: "AWS",      description: "AWS profile a new terminal gets (login shell, else [default])" },
    { id: "ip",       label: "IP",       description: "Source address of the default route" }
]

function ids() { return STATS.map(function(s) { return s.id }) }

function label(id) {
    for (var i = 0; i < STATS.length; i++) if (STATS[i].id === id) return STATS[i].label
    return id
}

// The configured selection, cleaned: unknown ids and duplicates dropped, shown in
// registry order. Anything that is not an array (unset, corrupt) means "all".
function selection(cfg) {
    if (!Array.isArray(cfg)) return ids()
    return ids().filter(function(id) { return cfg.indexOf(id) !== -1 })
}

function isOn(cfg, id) { return selection(cfg).indexOf(id) !== -1 }

// New selection with `id` switched on/off (registry order, no duplicates).
function toggle(cfg, id, on) {
    var cur = selection(cfg)
    return ids().filter(function(x) { return x === id ? on : cur.indexOf(x) !== -1 })
}

var _MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

// "YYYY-MM-DD HH:MM[:SS]" → "today HH:MM" / "Sep 29 10:24" (fits the card
// column; the full stamp truncated). Anything unparsable is returned as is.
function shortStamp(stamp, now) {
    var m = String(stamp).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/)
    if (!m) return stamp
    var n = now || new Date()
    var sameDay = n.getFullYear() === +m[1] && n.getMonth() + 1 === +m[2] && n.getDate() === +m[3]
    return (sameDay ? "today" : _MONTHS[+m[2] - 1] + " " + (+m[3])) + " " + m[4] + ":" + m[5]
}

// `snapper --csvout list --columns number,date` → date of the newest snapshot,
// or "none" when there is only the current system (number 0, no date).
function parseSnapper(csv) {
    var best = -1, date = ""
    var lines = String(csv || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split(",")
        var n = parseInt(f[0])
        if (isNaN(n) || n <= 0 || !f[1]) continue
        if (n > best) { best = n; date = f[1].trim() }
    }
    return best > 0 ? date : "none"
}

// `nmcli -t -f NAME,TYPE con show --active` → first VPN/WireGuard name, else
// "inactive". Matches the TYPE field only (a Wi-Fi named "vpn-lab" is not a VPN).
// nmcli -t escapes ':' inside names as '\:'.
function parseVpn(text) {
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^((?:[^:\\]|\\.)*):([^:]*)$/)
        if (!m) continue
        var type = m[2].trim()
        if (type === "vpn" || type === "wireguard") return m[1].replace(/\\(.)/g, "$1")
    }
    return "inactive"
}

// "<repo> <aur>" counts → the Updates value.
function formatUpdates(text) {
    var f = String(text || "").trim().split(/\s+/)
    var u = parseInt(f[0]) || 0, a = parseInt(f[1]) || 0
    if (u === 0 && a === 0) return "up to date"
    if (u === 0) return a + " AUR"
    if (a === 0) return u + " pkgs"
    return u + " + " + a + " AUR"
}
