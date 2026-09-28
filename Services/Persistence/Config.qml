pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root
    property bool ready: false
    property var _data: ({})

    readonly property string _path:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/archeotech/config.json"

    property Process _mkdir: Process {
        command: ["bash", "-c", "mkdir -p ~/.config/archeotech"]
        running: false
    }

    property FileView _file: FileView {
        path: root._path
        watchChanges: true
        preload: false
        printErrors: false
        // `ready` means config.json has actually been read (or does not exist).
        // It used to flip on the first textChanged, which fires with empty text
        // before the file loads, so boot-time writers (ColorScheme._bootResolve)
        // ran against empty data and a Config.set() could race the load and
        // overwrite config.json. loaded()/loadFailed() only fire once the read ends.
        function _parse() {
            var content = text()
            if (!content.trim()) return
            try { root._data = JSON.parse(content) } catch (_) { root._data = {} }
        }
        onTextChanged: _parse()             // also picks up external edits (watchChanges)
        onLoaded:      { _parse(); root.ready = true }
        onLoadFailed:  root.ready = true    // no file yet: defaults are correct
    }

    property Timer _debounce: Timer {
        interval: 50
        repeat: false
        onTriggered: root._file.setText(JSON.stringify(root._data, null, 2))
    }

    Component.onCompleted: {
        _mkdir.running = true
        _file.preload = true
    }

    function get(key, defaultValue) {
        var parts = key.split(".")
        var obj = root._data
        for (var i = 0; i < parts.length; i++) {
            if (obj === null || obj === undefined || typeof obj !== "object") return defaultValue
            obj = obj[parts[i]]
        }
        return obj !== undefined ? obj : defaultValue
    }

    function set(key, value) {
        // Deep-clone so the property assignment triggers QML change notification
        var newData = JSON.parse(JSON.stringify(root._data))
        var parts = key.split(".")
        var obj = newData
        for (var i = 0; i < parts.length - 1; i++) {
            var k = parts[i]
            if (typeof obj[k] !== "object" || obj[k] === null) obj[k] = {}
            obj = obj[k]
        }
        obj[parts[parts.length - 1]] = value
        root._data = newData
        _debounce.restart()
    }
}
