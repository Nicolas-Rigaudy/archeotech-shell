pragma Singleton
import QtQuick
import Quickshell.Io
import "../../Commons" as Commons

QtObject {
    id: root

    // ── Basic connection state ─────────────────────────────────────────────────
    property bool   connected:  false
    property string ssid:       ""
    property int    signal:     0
    property string band:       ""
    property bool   wired:      false

    // ── WiFi adapter ──────────────────────────────────────────────────────────
    property bool wifiEnabled: true

    // ── Network list ──────────────────────────────────────────────────────────
    property var    networks:          []  // [{ssid, security, signal, active, saved, bssid}]
    property bool   scanning:          false
    property string connectingTo:      ""
    property string disconnectingFrom: ""

    // List freeze — prevents reorder while password field is open
    property bool _frozen:         false
    property var  _frozenSnapshot: null
    readonly property var displayNetworks: _frozen && _frozenSnapshot !== null
        ? _frozenSnapshot : networks

    function freezeList()  { root._frozenSnapshot = root.networks.slice(); root._frozen = true }
    function unfreezeList() { root._frozen = false; root._frozenSnapshot = null }

    // ── Startup ────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        root.refresh.running     = true
        root.monitor.running     = true
        root._radioCheck.running = true
        root._scan()
    }

    // ── nmcli event monitor ────────────────────────────────────────────────────
    property var monitor: Process {
        command: ["nmcli", "monitor"]
        running: false
        stdout: SplitParser {
            onRead: _line => { root.refresh.running = true; root._scan() }
        }
        onExited: (code, status) => { running = true }
    }

    // ── Basic connection state refresh ─────────────────────────────────────────
    property var refresh: Process {
        command: ["bash", "-c",
            "LINE=$(nmcli -t -f active,ssid,signal,freq dev wifi 2>/dev/null | grep '^yes' | head -1); " +
            "SSID=$(echo \"$LINE\" | cut -d: -f2); " +
            "SIG=$(echo \"$LINE\" | cut -d: -f3); " +
            "FREQ=$(echo \"$LINE\" | cut -d: -f4); " +
            "echo \"$SSID|$SIG|$FREQ\""]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                var s = parts[0] || ""
                root.ssid      = s
                root.connected = s.length > 0
                root.signal    = parseInt(parts[1]) || 0
                var freq       = parseInt(parts[2]) || 0
                root.band      = freq >= 5000 ? "5 GHz" : freq >= 2000 ? "2.4 GHz" : ""
            }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Network: refresh exited with code " + code)
        }
    }

    // ── WiFi radio toggle ──────────────────────────────────────────────────────
    property var _radioCheck: Process {
        command: ["nmcli", "radio", "wifi"]
        running: false
        stdout: SplitParser {
            onRead: data => { root.wifiEnabled = data.trim() === "enabled" }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Network: radio check exited with code " + code)
        }
    }

    property var _radioCmd: Process {
        property string _state: "on"
        command: ["nmcli", "radio", "wifi", _state]
        running: false
        onExited: (code, status) => { root._radioCheck.running = true }
    }

    function toggleWifi() {
        root._radioCmd._state = root.wifiEnabled ? "off" : "on"
        root._radioCmd.running = true
    }

    // ── Network list scan ──────────────────────────────────────────────────────
    property var _scanProc: Process {
        property var _buf: []
        command: [Commons.Paths.wifiScan]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try { root._scanProc._buf = root._scanProc._buf.concat([JSON.parse(data.trim())]) } catch(e) {}
            }
        }
        onExited: (code, status) => {
            root.scanning = false
            if (!root._frozen) root.networks = root._dedup(root._scanProc._buf)
            if (code !== 0) console.warn("Network: scan exited with code " + code)
        }
    }

    function _dedup(list) {
        var seen = {}
        list.forEach(function(n) {
            if (!seen[n.ssid] || n.active ||
                (!seen[n.ssid].active && n.signal > seen[n.ssid].signal))
                seen[n.ssid] = n
        })
        var result = Object.values(seen)
        result.sort(function(a, b) {
            if (a.active && !b.active)  return -1
            if (b.active && !a.active)  return  1
            if (a.saved  && !b.saved)   return -1
            if (b.saved  && !a.saved)   return  1
            return b.signal - a.signal
        })
        return result
    }

    function _scan() {
        if (root._scanProc.running) return
        root._scanProc._buf = []
        root._scanProc.running = true
    }

    property var _rescanProc: Process {
        command: ["bash", "-c", "nmcli dev wifi rescan 2>/dev/null; true"]
        running: false
        onExited: (code, status) => { root._scan() }
    }

    function scan() {
        if (root.scanning) return
        root.scanning = true
        root._rescanProc.running = true
    }

    // ── Connect / Disconnect / Forget ──────────────────────────────────────────
    property var _connCmd: Process {
        property string _cmd: ""
        command: ["bash", "-c", _cmd]
        running: false
        onExited: (code, status) => {
            var s = root.connectingTo
            root.connectingTo = ""
            if (code !== 0 && s !== "") {
                // Forget the stale partial profile on auth failure then rescan
                root._forgetCmd._cmd = "nmcli connection delete " + root._esc(s) + " 2>/dev/null; true"
                root._forgetCmd.running = true
            }
            root.refresh.running = true
            root._scan()
        }
    }

    function connect(targetSsid) {
        if (root.connectingTo !== "") return
        root.connectingTo = targetSsid
        root._connCmd._cmd = "nmcli dev wifi connect " + root._esc(targetSsid)
        root._connCmd.running = true
    }

    function connectWithPassword(targetSsid, pw) {
        if (root.connectingTo !== "") return
        root.connectingTo = targetSsid
        root._connCmd._cmd = "nmcli dev wifi connect " + root._esc(targetSsid) + " password " + root._esc(pw)
        root._connCmd.running = true
    }

    property var _disconnCmd: Process {
        command: ["nmcli", "dev", "wifi", "disconnect"]
        running: false
        onExited: (code, status) => {
            root.disconnectingFrom = ""
            root.refresh.running = true
            root._scan()
        }
    }

    function disconnect() {
        root.disconnectingFrom = root.ssid
        root._disconnCmd.running = true
    }

    property var _forgetCmd: Process {
        property string _cmd: ""
        command: ["bash", "-c", _cmd]
        running: false
        onExited: (code, status) => { root._scan() }
    }

    function forget(targetSsid) {
        root._forgetCmd._cmd = "nmcli connection delete " + root._esc(targetSsid) + " 2>/dev/null; true"
        root._forgetCmd.running = true
    }

    // ── Auto-join (NetworkManager autoconnect) ──────────────────────────────────
    // Toggle whether a saved network is auto-joined when in range. Re-scans on
    // completion so the model's `autoconnect` field reflects the new state.
    property var _autoconnCmd: Process {
        property string _cmd: ""
        command: ["bash", "-c", _cmd]
        running: false
        onExited: (code, status) => { root._scan() }
    }

    function setAutoconnect(targetSsid, on) {
        root._autoconnCmd._cmd = "nmcli connection modify " + root._esc(targetSsid)
            + " connection.autoconnect " + (on ? "yes" : "no") + " 2>/dev/null; true"
        root._autoconnCmd.running = true
    }

    // bash single-quote escape (handles all characters including single quotes)
    function _esc(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }

    // ── Icons ──────────────────────────────────────────────────────────────────
    function icon() {
        if (!root.wifiEnabled) return "󰖫"
        if (!root.connected)   return "󰖪"
        return "󰖩"
    }

    function signalIcon(strength, secure) {
        var lvl = strength >= 75 ? 4 : strength >= 50 ? 3 : strength >= 25 ? 2 : strength > 0 ? 1 : 0
        // wifi-strength-{lock-outline,1..4-lock} for secure; wifi-strength-{outline,1..4}
        // for open. Both follow the MDI +3 codepoint stride so all levels render as
        // proper wifi bars (the old secure set used scattered non-wifi glyphs).
        return secure
            ? ["󰤭", "󰤡", "󰤤", "󰤧", "󰤪"][lvl]
            : ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][lvl]
    }
}
