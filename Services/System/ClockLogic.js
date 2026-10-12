.pragma library
// Clock format helpers: one global setting (config.json "clock.*", Settings →
// Shell → Clock) read by every clock (bar widget, dashboard, notification times).
// Pure Qt.formatDateTime patterns, so tests/qml can check them without the shell.

// clock.date values → date pattern ("" = no date).
var DATE_FORMATS = {
    short:   "ddd d MMM",     // Mon 12 Oct
    numeric: "dd/MM",         // 12/10
    iso:     "yyyy-MM-dd",    // 2026-10-12
    none:    ""
}

function is12h(format) { return format === "12h" }

// Time pattern for "24h" | "12h", with or without seconds.
function timeFormat(format, seconds) {
    var t = is12h(format) ? "h:mm" : "HH:mm"
    if (seconds === true) t += ":ss"
    return is12h(format) ? t + " AP" : t
}

// Hour-only pattern (the vertical bar clock stacks hours over minutes).
function hourFormat(format) { return is12h(format) ? "h" : "HH" }

function dateFormat(date) {
    return DATE_FORMATS.hasOwnProperty(date) ? DATE_FORMATS[date] : DATE_FORMATS.short
}
