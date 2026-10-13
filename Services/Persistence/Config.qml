pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io
import "ConfigLogic.js" as Logic
import "ConfigDefaults.js" as Defaults

QtObject {
    id: root
    property bool ready: false
    property var _data: ({})
    property var _recentWrites: []   // last few texts we wrote, to recognise their echoes

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
        // Every path lands here: first load, our own writes echoed back through
        // fileChanged → reload(), and external edits. Only an external edit that
        // parses to something new may replace _data:
        //  - invalid/half-written text keeps the current config (never {}: the next
        //    set() would persist that and wipe config.json);
        //  - once loaded, while a set() is waiting to be saved, the save wins (a stale
        //    echo of an earlier write must not roll the newer value back; an external
        //    edit landing in that 50ms window is lost). Before the first load the
        //    file wins, so an early set() cannot save a near-empty config;
        //  - our own recent writes and unchanged content are no-ops (loaded and
        //    textChanged both fire per reload).
        function _parse() {
            var content = text()
            if (!content.trim()) return
            if ((root.ready && root._debounce.running) || root._recentWrites.indexOf(content) !== -1) return
            var parsed
            try { parsed = JSON.parse(content) } catch (_) { return }
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return
            if (JSON.stringify(parsed) === JSON.stringify(root._data)) return
            root._data = parsed
        }
        // watchChanges only emits fileChanged(); without a reload() an external edit
        // to config.json never reached the shell.
        onFileChanged: reload()
        onTextChanged: _parse()
        onLoaded:      { _parse(); root.ready = true; root._dropObsolete() }
        onLoadFailed:  root.ready = true    // no file yet: defaults are correct
    }

    property Timer _debounce: Timer {
        interval: 50
        repeat: false
        onTriggered: {
            var text = JSON.stringify(root._data, null, 2)
            root._recentWrites = root._recentWrites.concat([text]).slice(-4)
            root._file.setText(text)
        }
    }

    Component.onCompleted: {
        _mkdir.running = true
        _file.preload = true
    }

    // Stale keys an older config.json may still carry (ConfigLogic.OBSOLETE_KEYS).
    function _dropObsolete() {
        var next = Logic.dropKeys(root._data, Logic.OBSOLETE_KEYS)
        if (next === root._data) return
        root._data = next
        _debounce.restart()
    }

    // Returns the live (shared) subtree: copy before mutating, then set() the copy.
    // With no defaultValue, a key declared in ConfigDefaults.js falls back to it.
    function get(key, defaultValue) {
        return Logic.getPath(root._data, key, arguments.length > 1 ? defaultValue : Defaults.value(key))
    }

    // Reset to default (item_138): a key from ConfigDefaults.js is "modified" when
    // config.json holds a different value; reset() removes it, so get() falls back.
    function defaultFor(key) { return Defaults.value(key) }
    function isModified(key) { return Defaults.isModified(key, Logic.getPath(root._data, key, undefined)) }
    function reset(key) { set(key, undefined) }

    // Copies only the path to `key`, so bindings on other object-valued keys keep
    // their object and stay quiet; an unchanged value neither notifies nor writes.
    function set(key, value) {
        var next = Logic.setPath(root._data, key, value)
        if (next === root._data) return
        root._data = next
        _debounce.restart()
    }
}
