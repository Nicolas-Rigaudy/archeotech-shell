pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth state, event-driven off Quickshell's native BlueZ bindings (item_121):
// adapter power, the device list, connect / disconnect / trust / forget and
// battery update from BlueZ's own D-Bus signals, with no process spawned.
//
// Replaces a `gdbus monitor` + `busctl` design that re-ran one busctl per
// device property on every signal burst, hard-wired to /org/bluez/hci0.
// Discovery and pairing still go through bt-agent.py: pairing needs a
// registered agent for the SSP handshake, which Quickshell does not provide.
QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    // ── Public state (same contract the busctl service exposed) ──────────────
    readonly property bool enabled: !!(adapter && adapter.enabled)

    // Every device of the default adapter (paired + discovered) as plain rows.
    // Reading each device's properties here makes the binding follow them, so
    // a connect, rename or battery change re-evaluates the list.
    readonly property var devices: {
        var out = []
        var a = root.adapter
        if (!a) return out
        var vals = Bluetooth.devices.values
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i]
            if (!d || d.adapter !== a || !d.address) continue
            out.push({
                name:      d.name || d.address,
                address:   d.address,
                connected: d.connected,
                paired:    d.paired,
                trusted:   d.trusted,
                battery:   d.batteryAvailable ? Math.round(d.battery * 100) : null
            })
        }
        // Stable order (the native model's is not): by address, as the old
        // per-path listing was.
        out.sort((x, y) => x.address < y.address ? -1 : x.address > y.address ? 1 : 0)
        return out
    }
    readonly property var _connected: devices.filter(d => d.connected)
    readonly property bool   connected: _connected.length > 0
    readonly property string device:    connected ? _connected[0].name : ""

    // In-flight operation tracking (drives the UI spinners). Holds the address
    // of the device being (dis)connected; "" when idle. Single-flight: only one
    // op at a time, which avoids the overlapping "Operation already in progress"
    // Connect calls seen in bluetoothd logs.
    property string connectingTo:      ""
    property string disconnectingFrom: ""
    property string pairingTo:         ""
    property string removingFrom:      ""

    // True while a discovery scan is running (the bt-agent.py --scan helper holds
    // the discovery session open; killing it stops discovery). Drives the Scan
    // button state and the "AVAILABLE" device section in the settings pane.
    property bool discovering: false

    function _deviceFor(address) {
        if (!address) return null
        var vals = Bluetooth.devices.values
        for (var i = 0; i < vals.length; i++)
            if (vals[i] && vals[i].address === address && vals[i].adapter === root.adapter) return vals[i]
        return null
    }

    // An operation ends when the device settles (connected, disconnected or
    // gone), or after BlueZ's own connect timeout at the latest. A connect only
    // ends on Disconnected once it was seen Connecting, so the state before the
    // call starts does not end it.
    property bool _opSawConnecting: false
    function _settle() {
        if (root.connectingTo !== "") {
            var c = _deviceFor(root.connectingTo)
            if (c && c.state === BluetoothDeviceState.Connecting) root._opSawConnecting = true
            else if (!c || c.state === BluetoothDeviceState.Connected
                     || (c.state === BluetoothDeviceState.Disconnected && root._opSawConnecting))
                root._endOp()
        }
        if (root.disconnectingFrom !== "") {
            var d = _deviceFor(root.disconnectingFrom)
            if (!d || d.state === BluetoothDeviceState.Disconnected) root._endOp()
        }
        if (root.removingFrom !== "" && !_deviceFor(root.removingFrom)) root._endOp()
    }
    function _beginOp() {
        root._opSawConnecting = false
        _opTimeout.restart()
    }
    function _endOp() {
        root.connectingTo = ""
        root.disconnectingFrom = ""
        root.removingFrom = ""
        root._opSawConnecting = false
        _opTimeout.stop()
    }
    property var _opTimeout: Timer { interval: 30000; onTriggered: root._endOp() }
    // Device states change on the device objects, not on the list: follow the
    // one being worked on.
    property var _opWatch: Connections {
        target: root._deviceFor(root.connectingTo || root.disconnectingFrom || root.removingFrom)
        ignoreUnknownSignals: true
        function onStateChanged() { root._settle() }
    }
    onDevicesChanged: _settle()

    // ── Commands ───────────────────────────────────────────────────────────────
    function toggle() {
        if (root.adapter) root.adapter.enabled = !root.adapter.enabled
    }

    // Mark the device Trusted *before* Connect. An untrusted audio device (e.g.
    // a Jabra headset) brings the ACL link up, but bluez is then denied the
    // A2DP/HFP profile setup ("avdtp ... Permission denied", "Hands-Free ...
    // Connection refused" in bluetoothd) and tears the whole link down — i.e.
    // it "connects then disconnects straight away". Trust authorises the audio
    // profiles and also enables auto-reconnect on power-on / range return.
    function connectDevice(address) {
        if (root.connectingTo !== "" || root.disconnectingFrom !== "") return
        var d = _deviceFor(address)
        if (!d) return
        root.connectingTo = address
        _beginOp()
        d.trusted = true
        d.connect()
    }

    function disconnectDevice(address) {
        if (root.connectingTo !== "" || root.disconnectingFrom !== "") return
        var d = _deviceFor(address)
        if (!d) return
        root.disconnectingFrom = address
        _beginOp()
        d.disconnect()
    }

    function setTrusted(address, on) {
        var d = _deviceFor(address)
        if (d) d.trusted = on
    }

    // Adapter1.RemoveDevice drops the pairing + link key. This is the in-panel
    // replacement for opening blueman just to unpair.
    function removeDevice(address) {
        if (root.removingFrom !== "") return
        var d = _deviceFor(address)
        if (!d) return
        root.removingFrom = address
        _beginOp()
        d.forget()
    }

    // ── Discovery scan (needs a persistent connection → bt-agent.py --scan) ─────
    // The helper holds the discovery session open + registers a pairing agent so
    // a discovered device can be paired. Killing the process (running=false)
    // ends discovery cleanly; the helper also self-times-out. Found devices show
    // up through the native device list.
    property var _scanCmd: Process {
        command: ["bash", "-c", "bt-agent.py --scan 30"]
        running: false
        onExited: (code, status) => { root.discovering = false }
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
