pragma Singleton
import QtQuick
import Quickshell.Io
import "../Persistence" as Persistence

QtObject {
    id: root

    // ── Device aliasing + per-device volume cap (Sprint 24) ──────────────────────
    // Stored in Persistence.Config (per-user UI state) keyed by the pactl device
    // name. Alias is display-only; the volume cap clamps setVolume on the active
    // sink so a device can't be driven past a safe level.
    function aliasFor(name) {
        var a = Persistence.Config.get("audio.aliases", ({}))
        return (a && a[name]) ? a[name] : ""
    }
    function setAlias(name, alias) {
        var a = JSON.parse(JSON.stringify(Persistence.Config.get("audio.aliases", ({}))))
        var t = (alias || "").trim()
        if (t !== "") a[name] = t; else delete a[name]
        Persistence.Config.set("audio.aliases", a)
    }
    function volumeLimitFor(name) {
        var l = Persistence.Config.get("audio.volumeLimits", ({}))
        return (l && l[name] !== undefined) ? l[name] : 100
    }
    function setVolumeLimit(name, pct) {
        var l = JSON.parse(JSON.stringify(Persistence.Config.get("audio.volumeLimits", ({}))))
        l[name] = Math.round(pct)
        Persistence.Config.set("audio.volumeLimits", l)
        if (name === root.defaultSink && root.volume > pct) root.setVolume(pct)
    }

    property int  volume:     0
    property bool muted:      false
    property int  micVolume:  0
    property bool micMuted:   false
    property var  sinks:       []
    property string defaultSink: ""
    property var  sources:     []      // real input devices (monitors excluded)
    property string defaultSource: ""

    // ── Initial reads ──────────────────────────────────────────────────────────

    Component.onCompleted: {
        refreshSink.running      = true
        refreshMute.running      = true
        refreshMic.running       = true
        refreshMicMute.running   = true
        refreshSinks.running     = true
        refreshDefaultSink.running = true
        refreshSources.running     = true
        refreshDefaultSource.running = true
        subscribe.running        = true
    }

    // ── pactl subscribe — fires on every sink/source change ───────────────────

    property var subscribe: Process {
        command: ["pactl", "subscribe"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("sink") || line.includes("'change'")) {
                    refreshSink.running      = true
                    refreshMute.running      = true
                    refreshSinks.running     = true
                    refreshDefaultSink.running = true
                }
                if (line.includes("source")) {
                    refreshMic.running    = true
                    refreshMicMute.running = true
                    refreshSources.running       = true
                    refreshDefaultSource.running = true
                }
            }
        }
        // Auto-restart if it dies
        onExited: (code, status) => { if (code !== 0 || status !== 0) running = true }
    }

    // ── One-shot readers ───────────────────────────────────────────────────────

    property var refreshSink: Process {
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1"]
        running: false
        stdout: SplitParser { onRead: data => root.volume = parseInt(data.trim()) || 0 }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: refreshSink exited with code " + code)
        }
    }

    property var refreshMute: Process {
        command: ["bash", "-c", "pactl get-sink-mute @DEFAULT_SINK@ | grep -c 'yes' || echo 0"]
        running: false
        stdout: SplitParser { onRead: data => root.muted = data.trim() === "1" }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: refreshMute exited with code " + code)
        }
    }

    property var refreshMic: Process {
        command: ["bash", "-c", "pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\\d+(?=%)' | head -1"]
        running: false
        stdout: SplitParser { onRead: data => root.micVolume = parseInt(data.trim()) || 0 }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: refreshMic exited with code " + code)
        }
    }

    property var refreshMicMute: Process {
        command: ["bash", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ | grep -c 'yes' || echo 0"]
        running: false
        stdout: SplitParser { onRead: data => root.micMuted = data.trim() === "1" }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: refreshMicMute exited with code " + code)
        }
    }

    // ── Sink list + default sink ───────────────────────────────────────────────

    property var refreshSinks: Process {
        command: ["bash", "-c", "pactl list sinks | grep -E '^\\s+(Name|Description):'"]
        running: false
        property string _buf: ""
        stdout: SplitParser { onRead: line => refreshSinks._buf += line + "\n" }
        onExited: (code, status) => {
            if (code !== 0) { console.warn("Audio: refreshSinks failed"); return }
            var sinks = []
            var lines = _buf.trim().split("\n")
            var current = null
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                var m
                if ((m = line.match(/^Name:\s*(.+)$/))) {
                    if (current) sinks.push(current)
                    current = { name: m[1].trim(), description: "", shortName: "" }
                } else if ((m = line.match(/^Description:\s*(.+)$/))) {
                    if (current) {
                        current.description = m[1].trim()
                        var d = current.description
                        var sm
                        if ((sm = d.match(/HDMI \/ DisplayPort (\d+)/))) current.shortName = "HDMI " + sm[1]
                        else if (d.match(/HDMI \/ DisplayPort/))          current.shortName = "HDMI"
                        else if (d.includes("Headphones"))                 current.shortName = "Headphones"
                        else if (d.includes("Speakers"))                   current.shortName = "Speakers"
                        else if ((sm = d.match(/cAVS (.+)$/)))             current.shortName = sm[1]
                        else current.shortName = d
                            .replace(/ Analog Stereo( \(IEC958\))?$/, "")
                            .replace(/ Digital Stereo( \(IEC958\))?$/, "")
                            .replace(/^Built-in Audio$/, "Built-in")
                    }
                }
            }
            if (current) sinks.push(current)
            _buf = ""
            root.sinks = sinks
        }
    }

    property var refreshDefaultSink: Process {
        command: ["pactl", "get-default-sink"]
        running: false
        stdout: SplitParser { onRead: data => root.defaultSink = data.trim() }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: refreshDefaultSink failed")
        }
    }

    // ── Source (input) list + default source ─────────────────────────────────
    // Mirrors the sink reader. Monitor sources (loopbacks of each sink, name
    // ends in ".monitor") are excluded — they aren't real capture devices.

    property var refreshSources: Process {
        command: ["bash", "-c", "pactl list sources | grep -E '^\\s+(Name|Description):'"]
        running: false
        property string _buf: ""
        stdout: SplitParser { onRead: line => refreshSources._buf += line + "\n" }
        onExited: (code, status) => {
            if (code !== 0) { console.warn("Audio: refreshSources failed"); return }
            var sources = []
            var lines = _buf.trim().split("\n")
            var current = null
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                var m
                if ((m = line.match(/^Name:\s*(.+)$/))) {
                    if (current) sources.push(current)
                    current = { name: m[1].trim(), description: "", shortName: "" }
                } else if ((m = line.match(/^Description:\s*(.+)$/))) {
                    if (current) {
                        current.description = m[1].trim()
                        var d = current.description
                        if (d.includes("Headset"))         current.shortName = "Headset"
                        else if (d.includes("Microphone"))  current.shortName = "Microphone"
                        else current.shortName = d
                            .replace(/ Analog Stereo( \(IEC958\))?$/, "")
                            .replace(/^Built-in Audio$/, "Built-in")
                    }
                }
            }
            if (current) sources.push(current)
            _buf = ""
            // Drop monitor sources — not real inputs.
            root.sources = sources.filter(function(s) { return !/\.monitor$/.test(s.name) })
        }
    }

    property var refreshDefaultSource: Process {
        command: ["pactl", "get-default-source"]
        running: false
        stdout: SplitParser { onRead: data => root.defaultSource = data.trim() }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: refreshDefaultSource failed")
        }
    }

    // ── Actions ────────────────────────────────────────────────────────────────

    property var _cmd: Process {
        id: cmdRunner
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("Audio: command exited with code " + code)
        }
    }

    function setVolume(pct) {
        // Clamp to the active sink's configured max (default 100).
        var cap = volumeLimitFor(defaultSink)
        var v = Math.min(Math.round(pct), cap)
        _cmd.cmd = "pactl set-sink-volume @DEFAULT_SINK@ " + v + "%"
        _cmd.running = true
    }

    function toggleMute() {
        _cmd.cmd = "pactl set-sink-mute @DEFAULT_SINK@ toggle"
        _cmd.running = true
    }

    function toggleMicMute() {
        _cmd.cmd = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"
        _cmd.running = true
    }

    function setDefaultSink(name) {
        defaultSink = name
        _cmd.cmd = "pactl set-default-sink '" + name.replace(/'/g, "'\\''") + "'"
        _cmd.running = true
    }

    function setDefaultSource(name) {
        defaultSource = name
        _cmd.cmd = "pactl set-default-source '" + name.replace(/'/g, "'\\''") + "'"
        _cmd.running = true
    }
}
