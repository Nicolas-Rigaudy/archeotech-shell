pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import "../Persistence" as Persistence

// Audio state, fully event-driven off Quickshell's native Pipewire bindings —
// volume / mute / device changes update INSTANTLY, no polling, no subprocesses.
//
// Replaces the old pactl-based service (one long-lived `pactl subscribe` Process
// + a swarm of one-shot `pactl` readers). That design leaked: on a crash or
// hard-kill of Quickshell the `pactl subscribe` child reparented to init instead
// of being torn down, and held a PipeWire-Pulse client slot forever. Enough of
// them accumulated to exhaust the connection limit → the server refused every
// new client → no volume, OSD, mute icon or device detection until reboot.
// Native bindings use Quickshell's own persistent Pipewire client: nothing is
// spawned per change, so nothing can orphan or exhaust connections.
QtObject {
    id: root

    // ── Device aliasing + per-device volume cap (Sprint 24) ──────────────────────
    // Stored in Persistence.Config (per-user UI state) keyed by the device node
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

    // ── Native Pipewire handles ──────────────────────────────────────────────────
    readonly property var _sink:   Pipewire.defaultAudioSink
    readonly property var _source: Pipewire.defaultAudioSource

    // Bind the default sink + source so their `audio` data (volume/mute) is live
    // and writable — without a tracker, PwNode.audio stays null. The objects list
    // re-binds automatically when the default device changes.
    property var _tracker: PwObjectTracker {
        objects: [root._sink, root._source].filter(Boolean)
    }

    // ── Public state (same contract the old pactl service exposed) ───────────────
    readonly property int  volume:    (_sink && _sink.audio)     ? Math.round(_sink.audio.volume * 100)   : 0
    readonly property bool muted:     (_sink && _sink.audio)     ? _sink.audio.muted                      : false
    readonly property int  micVolume: (_source && _source.audio) ? Math.round(_source.audio.volume * 100) : 0
    readonly property bool micMuted:  (_source && _source.audio) ? _source.audio.muted                    : false

    readonly property string defaultSink:   _sink   ? _sink.name   : ""
    readonly property string defaultSource: _source ? _source.name : ""

    // ── Device lists (outputs / real inputs) ─────────────────────────────────────
    // Built from the live node model; recompute whenever nodes appear/disappear.
    // Monitor sources (loopbacks of each sink, name ends in ".monitor") are
    // excluded — they aren't real capture devices. Application streams (isStream)
    // are excluded — only hardware/virtual devices belong in the picker.
    readonly property var sinks: {
        var out = []
        var vals = Pipewire.nodes.values
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (!n || n.isStream) continue
            if ((n.type & PwNodeType.AudioSink) !== PwNodeType.AudioSink) continue
            var d = _descOf(n)
            out.push({ name: n.name, description: d, shortName: _sinkShort(d) })
        }
        return out
    }

    readonly property var sources: {
        var out = []
        var vals = Pipewire.nodes.values
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (!n || n.isStream) continue
            if ((n.type & PwNodeType.AudioSource) !== PwNodeType.AudioSource) continue
            if (/\.monitor$/.test(n.name)) continue
            var d = _descOf(n)
            out.push({ name: n.name, description: d, shortName: _srcShort(d) })
        }
        return out
    }

    function _descOf(n) {
        return (n.description && n.description !== "") ? n.description : (n.nickname || n.name)
    }

    // shortName derivations preserved verbatim from the pactl service.
    function _sinkShort(d) {
        var sm
        if ((sm = d.match(/HDMI \/ DisplayPort (\d+)/))) return "HDMI " + sm[1]
        if (d.match(/HDMI \/ DisplayPort/))               return "HDMI"
        if (d.includes("Headphones"))                     return "Headphones"
        if (d.includes("Speakers"))                       return "Speakers"
        if ((sm = d.match(/cAVS (.+)$/)))                 return sm[1]
        return d.replace(/ Analog Stereo( \(IEC958\))?$/, "")
                .replace(/ Digital Stereo( \(IEC958\))?$/, "")
                .replace(/^Built-in Audio$/, "Built-in")
    }
    function _srcShort(d) {
        if (d.includes("Headset"))     return "Headset"
        if (d.includes("Microphone"))  return "Microphone"
        return d.replace(/ Analog Stereo( \(IEC958\))?$/, "")
                .replace(/^Built-in Audio$/, "Built-in")
    }

    function _nodeByName(name) {
        var vals = Pipewire.nodes.values
        for (var i = 0; i < vals.length; i++)
            if (vals[i] && vals[i].name === name) return vals[i]
        return null
    }

    // ── Actions (native property writes — no subprocess) ─────────────────────────
    function setVolume(pct) {
        if (!_sink || !_sink.audio) return
        var cap = volumeLimitFor(defaultSink)
        _sink.audio.volume = Math.min(Math.round(pct), cap) / 100
    }

    function toggleMute() {
        if (_sink && _sink.audio) _sink.audio.muted = !_sink.audio.muted
    }

    function toggleMicMute() {
        if (_source && _source.audio) _source.audio.muted = !_source.audio.muted
    }

    function setDefaultSink(name) {
        var n = _nodeByName(name)
        if (n) Pipewire.preferredDefaultAudioSink = n
    }

    function setDefaultSource(name) {
        var n = _nodeByName(name)
        if (n) Pipewire.preferredDefaultAudioSource = n
    }
}
