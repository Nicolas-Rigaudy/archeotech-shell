pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../Commons" as Commons
import "../../../Services/Shell" as ShellServices
import "../../../Services/Persistence" as Persistence
import "SystemNotesLogic.js" as Logic

DashCard {
    id: root
    title: "SYSTEM NOTES"

    // Which stats show, in registry order: Settings → Shell → Dashboard writes
    // "dashboard.notes" (unset = all). Each stat is fetched by its own process
    // (system-notes.sh <id>), so a slow one (updates) never holds back the rest,
    // and a stat whose source does not exist here (__NA__) is hidden, not faked.
    // Config.get() depends on the whole config object, so any Config.set() (any
    // key) re-evaluates it and hands back a NEW array. Compare by value: the
    // string only changes when the selection does, so the fetchers and rows are
    // left alone by unrelated settings changes.
    readonly property string _selKey: JSON.stringify(Logic.selection(Persistence.Config.get("dashboard.notes", null)))
    property var _selected: JSON.parse(_selKey)
    on_SelKeyChanged: _selected = JSON.parse(_selKey)
    property var values:      ({})   // id → display string
    property var unavailable: ({})   // id → true when the source is missing
    readonly property var _shown: _selected.filter(function(id) { return !root.unavailable[id] })
    readonly property string _script: decodeURIComponent(Qt.resolvedUrl("system-notes.sh").toString().replace(/^file:\/\//, ""))

    Component.onCompleted: _refresh()

    Connections {
        target: ShellServices.ShellState
        function onStateMapChanged() {
            if (ShellServices.ShellState.isOpenAnywhere("dashboard")) root._refresh()
        }
    }

    function _refresh() {
        for (var i = 0; i < fetchers.count; i++) {
            var p = fetchers.objectAt(i)
            if (p && !p.running) p.running = true
        }
    }

    function _store(id, text) {
        var t = String(text || "").trim()
        var na = Object.assign({}, root.unavailable)
        if (t === "__NA__") { na[id] = true; root.unavailable = na; return }
        delete na[id]; root.unavailable = na
        var v
        if (t === "__ERR__")       v = "check failed"
        else if (id === "snapshot") v = Logic.shortStamp(Logic.parseSnapper(t))
        else if (id === "vpn")      v = Logic.parseVpn(t)
        else if (id === "updates")  v = Logic.formatUpdates(t)
        else if (id === "ip")       v = t || "offline"
        else                        v = t || "N/A"
        var vals = Object.assign({}, root.values); vals[id] = v; root.values = vals
    }

    function _value(id) {
        var v = root.values[id]
        if (v !== undefined) return v
        return id === "updates" ? "checking…" : "…"
    }

    function _color(id, v) {
        var c = Commons.Appearance.colors
        if (v === "…" || v === "checking…" || v === "check failed") return c.overlay1
        switch (id) {
        case "updates": return v === "up to date" ? c.green : c.yellow
        case "vpn":     return v === "inactive" ? c.overlay1 : c.green
        case "aws":     return v === "none" ? c.overlay1 : (v.indexOf("(not in config)") !== -1 ? c.yellow : c.blue)
        case "ip":      return v === "offline" ? c.overlay1 : c.blue
        case "kernel":
        case "host":    return c.subtext1
        default:        return c.text
        }
    }

    // One process per selected stat; new selections start fetching at once.
    Instantiator {
        id: fetchers
        model: root._selected
        delegate: Process {
            id: fetcher
            required property string modelData
            command: ["bash", root._script, fetcher.modelData]
            stdout: StdioCollector {
                id: collector
                onStreamFinished: root._store(fetcher.modelData, collector.text)
            }
        }
        onObjectAdded: (index, object) => object.running = true
    }

    component NoteRow: Item {
        id: noteRow
        required property string label
        required property string value
        required property color  valueColor
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 22

        Text {
            id: noteLbl
            text: noteRow.label
            color: Commons.Appearance.colors.subtext0
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            width: 74
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: noteRow.value
            color: noteRow.valueColor
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            anchors { left: noteLbl.right; leftMargin: 6; right: parent.right; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    // 2-column key/value grid over the selected, resolvable stats.
    GridLayout {
        Layout.fillWidth: true
        // A child layout fills its cell by default, which centred a short
        // selection mid-card; keep the grid at its own height, under the title.
        Layout.fillHeight: false
        Layout.alignment: Qt.AlignTop
        columns: 2
        columnSpacing: 20
        rowSpacing: 4

        Repeater {
            model: root._shown
            delegate: NoteRow {
                id: note
                required property string modelData
                label: Logic.label(note.modelData)
                value: root._value(note.modelData)
                valueColor: root._color(note.modelData, note.value)
            }
        }
    }
}
