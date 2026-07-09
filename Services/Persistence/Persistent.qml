pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root
    property int settingsActivePaneIndex: 0

    property var _data: ({})
    property bool _loading: false

    readonly property string _path:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share/archeotech/state.json"

    property Process _mkdir: Process {
        command: ["bash", "-c", "mkdir -p ~/.local/share/archeotech"]
        running: false
    }

    property FileView _file: FileView {
        path: root._path
        watchChanges: false
        preload: false
        printErrors: false
        onTextChanged: {
            var content = text()
            if (!content.trim()) return
            try { root._data = JSON.parse(content) } catch (_) {}
            root._loading = true
            root.settingsActivePaneIndex = root._data.settingsActivePaneIndex || 0
            root._loading = false
        }
    }

    property Timer _debounce: Timer {
        interval: 50
        repeat: false
        onTriggered: {
            root._data.settingsActivePaneIndex = root.settingsActivePaneIndex
            root._file.setText(JSON.stringify(root._data, null, 2))
        }
    }

    onSettingsActivePaneIndexChanged: if (!_loading) _debounce.restart()

    Component.onCompleted: {
        _mkdir.running = true
        _file.preload = true
    }
}
