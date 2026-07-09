pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var connections: []  // [{name, active}]

    property bool active: {
        for (var i = 0; i < connections.length; i++)
            if (connections[i].active) return true
        return false
    }

    property string activeConnection: {
        for (var i = 0; i < connections.length; i++)
            if (connections[i].active) return connections[i].name
        return ""
    }

    Component.onCompleted: {
        _load.running    = true
        _monitor.running = true
    }

    property var _load: Process {
        command: ["bash", "-c", "nmcli -t -f NAME,TYPE,STATE connection show"]
        running: false
        property var _parsed: []
        stdout: SplitParser {
            onRead: line => {
                // nmcli -t escapes colons in values as \: — split carefully from the right
                var parts = line.split(":")
                var fields = []
                var cur = ""
                for (var i = 0; i < parts.length; i++) {
                    cur += (cur ? ":" : "") + parts[i]
                    // A segment ending in \ was split at an escaped \: — keep accumulating
                    if (!cur.endsWith("\\") || i === parts.length - 1) {
                        fields.push(cur.replace(/\\:/g, ":"))
                        cur = ""
                    }
                }
                if (fields.length < 3) return
                var type = fields[fields.length - 2]
                if (type !== "vpn" && type !== "wireguard") return
                _load._parsed.push({
                    name:   fields.slice(0, fields.length - 2).join(":"),
                    active: fields[fields.length - 1] === "activated"
                })
            }
        }
        onExited: (code, status) => {
            if (code !== 0) { console.warn("VPN: load failed with code " + code); return }
            root.connections = _parsed
            _parsed = []
        }
    }

    property var _monitor: Process {
        command: ["nmcli", "monitor"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("vpn") || line.includes("wireguard")
                        || line.includes("activated") || line.includes("deactivating")) {
                    root.connections = []
                    _load._parsed = []
                    _load.running = true
                }
            }
        }
        onExited: (code, status) => { if (code !== 0 || status !== 0) running = true }
    }

    property var _cmd: Process {
        property string cmd: ""
        command: ["bash", "-c", cmd]
        running: false
        onExited: (code, status) => {
            if (code !== 0) console.warn("VPN: command failed with code " + code)
            root.connections = []
            _load._parsed = []
            _load.running = true
        }
    }

    function toggle(name) {
        if (!name) name = connections.length > 0 ? connections[0].name : ""
        if (!name) return
        var conn = null
        for (var i = 0; i < connections.length; i++)
            if (connections[i].name === name) { conn = connections[i]; break }
        if (!conn) return
        var action = conn.active ? "down" : "up"
        _cmd.cmd = "nmcli connection " + action + " '" + name.replace(/'/g, "'\\''") + "'"
        _cmd.running = true
    }
}
