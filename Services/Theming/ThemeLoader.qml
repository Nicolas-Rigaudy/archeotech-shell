pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root
    property var data: ({})

    readonly property string _path:
        StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/archeotech/theme.json"

    property FileView _file: FileView {
        path: root._path
        watchChanges: true
        preload: true
        printErrors: false
        onTextChanged: {
            var content = text()
            if (!content || !content.trim()) return
            try { root.data = JSON.parse(content) } catch (_) {}
        }
    }
}
