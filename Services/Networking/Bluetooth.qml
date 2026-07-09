pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool   enabled:   false
    property bool   connected: false
    property string device:    ""
    property var    devices:   []

    // In-flight operation tracking (drives the UI spinners). Holds the address
    // of the device being (dis)connected; "" when idle. Single-flight: only one
    // op at a time — mirrors the Network service and avoids the overlapping
    // "Operation already in progress" Connect calls seen in bluetoothd logs.
    property string connectingTo:      ""
    property string disconnectingFrom: ""
    property string pairingTo:         ""
    property string removingFrom:      ""

    // True while a discovery scan is running (the bt-agent.py --scan helper holds
    // the discovery session open; killing it stops discovery). Drives the Scan
    // button state and the "AVAILABLE" device section in the settings pane.
    property bool discovering: false

    Component.onCompleted: _refresh()

    function _refresh() {
        if (!pollEnabled.running) pollEnabled.running = true
        if (!pollDevices.running) {
            pollDevices._incoming = []
            pollDevices.running   = true
        }
    }

    // ── D-Bus signal monitor (best-effort; polling fallback below) ─────────────
    property var monitor: Process {
        command: ["busctl", "monitor", "--json=short", "org.bluez"]
        running: true
        stdout: SplitParser { onRead: _line => root._refresh() }
        onExited: (code, status) => {
            if (code === 0) {
                running = true  // clean exit (connection dropped) — restart
            }
            // code !== 0 (e.g., Access denied): stop; polling timer takes over
        }
    }

    // Polling fallback — fires every 3s when monitor is not available
    property var _pollTimer: Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: if (!root.monitor.running) root._refresh()
    }

    // ── Adapter powered state ──────────────────────────────────────────────────
    property var pollEnabled: Process {
        command: ["busctl", "get-property", "org.bluez", "/org/bluez/hci0",
                  "org.bluez.Adapter1", "Powered"]
        running: false
        stdout: SplitParser {
            onRead: data => { root.enabled = data.trim().includes("true") }
        }
        onExited: (code, status) => {
            if (code !== 0) console.warn("Bluetooth: pollEnabled exited with code " + code)
        }
    }

    // ── Device list ──────────────────────────────────────────────────────────
    // Emits every device in the adapter tree (paired + discovered) with its
    // paired/trusted/connected state. The UI shows paired ones always and
    // discovered (unpaired) ones under "AVAILABLE" while a scan is running.
    // `sort -u` collapses the device path that grep also matches on each of a
    // connected device's audio sub-objects (fd0/sep/player) — without it a
    // connected device appeared once per sub-object.
    property var pollDevices: Process {
        property var _incoming: []
        command: ["bash", "-c",
            "busctl tree org.bluez 2>/dev/null | grep -oP '/org/bluez/hci0/dev_\\w+' | sort -u | " +
            "while IFS= read -r dev; do " +
            "  name=$(busctl get-property org.bluez \"$dev\" org.bluez.Device1 Alias 2>/dev/null | cut -d'\"' -f2); " +
            "  addr=$(busctl get-property org.bluez \"$dev\" org.bluez.Device1 Address 2>/dev/null | cut -d'\"' -f2); " +
            "  conn=$(busctl get-property org.bluez \"$dev\" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}'); " +
            "  paird=$(busctl get-property org.bluez \"$dev\" org.bluez.Device1 Paired 2>/dev/null | awk '{print $2}'); " +
            "  trust=$(busctl get-property org.bluez \"$dev\" org.bluez.Device1 Trusted 2>/dev/null | awk '{print $2}'); " +
            "  bat=$(busctl get-property org.bluez \"$dev\" org.bluez.Battery1 Percentage 2>/dev/null | awk '{print $2}'); " +
            "  [ -n \"$addr\" ] && " +
            "    printf '{\"name\":\"%s\",\"address\":\"%s\",\"connected\":%s,\"paired\":%s,\"trusted\":%s,\"battery\":%s}\\n' " +
            "      \"${name:-$addr}\" \"$addr\" \"${conn:-false}\" \"${paird:-false}\" \"${trust:-false}\" \"${bat:-null}\"; " +
            "done"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var d = JSON.parse(data.trim())
                    pollDevices._incoming = pollDevices._incoming.concat([d])
                } catch(e) {}
            }
        }
        onExited: (code, status) => {
            root.devices = pollDevices._incoming
            var conn = pollDevices._incoming.filter(d => d.connected)
            root.connected = conn.length > 0
            root.device    = conn.length > 0 ? conn[0].name : ""
            if (code !== 0) console.warn("Bluetooth: pollDevices exited with code " + code)
        }
    }

    // Faster polling while discovering so newly-found devices appear promptly.
    property var _scanPoll: Timer {
        interval: 1500; repeat: true; running: root.discovering
        onTriggered: root._refresh()
    }

    // ── Commands ───────────────────────────────────────────────────────────────
    property var _cmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("Bluetooth: command exited with code " + code)
            root._refresh()
        }
    }

    function _run(cmd) { _cmd.cmd = cmd; _cmd.running = true }

    function _devPath(address) {
        return "/org/bluez/hci0/dev_" + address.replace(/:/g, "_")
    }

    function toggle() {
        _run("busctl set-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered b " +
             (enabled ? "false" : "true"))
    }

    // ── Connect ──────────────────────────────────────────────────────────────
    // Mark the device Trusted *before* Connect. An untrusted audio device (e.g.
    // a Jabra headset) brings the ACL link up, but bluez is then denied the
    // A2DP/HFP profile setup ("avdtp ... Permission denied", "Hands-Free ...
    // Connection refused" in bluetoothd) and tears the whole link down — i.e.
    // it "connects then disconnects straight away". Trust authorises the audio
    // profiles and also enables auto-reconnect on power-on / range return.
    property var _connCmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("Bluetooth: connect exited with code " + code)
            root.connectingTo = ""
            root._refresh()
        }
    }

    function connectDevice(address) {
        if (root.connectingTo !== "" || root.disconnectingFrom !== "") return
        var path = root._devPath(address)
        root.connectingTo = address
        _connCmd.cmd =
            "busctl set-property org.bluez \"" + path + "\" org.bluez.Device1 Trusted b true; " +
            "busctl call org.bluez \"" + path + "\" org.bluez.Device1 Connect"
        _connCmd.running = true
    }

    // ── Disconnect ─────────────────────────────────────────────────────────────
    property var _disconnCmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("Bluetooth: disconnect exited with code " + code)
            root.disconnectingFrom = ""
            root._refresh()
        }
    }

    function disconnectDevice(address) {
        if (root.connectingTo !== "" || root.disconnectingFrom !== "") return
        var path = root._devPath(address)
        root.disconnectingFrom = address
        _disconnCmd.cmd = "busctl call org.bluez \"" + path + "\" org.bluez.Device1 Disconnect"
        _disconnCmd.running = true
    }

    // ── Trust toggle (agent-free) ──────────────────────────────────────────────
    function setTrusted(address, on) {
        var path = root._devPath(address)
        _run("busctl set-property org.bluez \"" + path + "\" org.bluez.Device1 Trusted b "
             + (on ? "true" : "false"))
    }

    // ── Remove / unpair (agent-free) ───────────────────────────────────────────
    // Adapter1.RemoveDevice drops the pairing + link key. This is the in-panel
    // replacement for opening blueman just to unpair.
    property var _removeCmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("Bluetooth: remove exited with code " + code)
            root.removingFrom = ""
            root._refresh()
        }
    }

    function removeDevice(address) {
        if (root.removingFrom !== "") return
        var path = root._devPath(address)
        root.removingFrom = address
        _removeCmd.cmd = "busctl call org.bluez /org/bluez/hci0 org.bluez.Adapter1 RemoveDevice o \""
                         + path + "\""
        _removeCmd.running = true
    }

    // ── Discovery scan (needs a persistent connection → bt-agent.py --scan) ─────
    // A one-shot `busctl StartDiscovery` stops the instant busctl exits (the
    // session is bound to the calling D-Bus connection), so the helper holds it
    // open + registers a pairing agent. Killing the process (running=false) ends
    // discovery cleanly; the helper also self-times-out.
    property var _scanCmd: Process {
        command: ["bash", "-c", "bt-agent.py --scan 30"]
        running: false
        onExited: (code, status) => {
            root.discovering = false
            root._refresh()
        }
    }

    function startScan() {
        if (root.discovering) return
        root.discovering = true
        _scanCmd.running = true
    }
    function stopScan() { _scanCmd.running = false }  // SIGTERM → discovery ends

    // ── Pair (needs the agent for the SSP handshake → bt-agent.py --pair) ───────
    // Pairs, trusts, and connects a discovered device. "Just-works" devices
    // (headsets) pair fine; PIN/passkey devices may still need blueman.
    property var _pairCmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("Bluetooth: pair exited with code " + code)
            root.pairingTo = ""
            root._refresh()
        }
    }

    function pairDevice(address) {
        if (root.pairingTo !== "") return
        root.pairingTo = address
        _pairCmd.cmd = "bt-agent.py --pair " + address
        _pairCmd.running = true
    }

    function icon() {
        if (connected) return "󰂱"
        if (enabled)   return "󰂯"
        return "󰂲"
    }
}
