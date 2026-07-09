import QtQuick
import QtQuick.Layouts
import "../../../Commons" as Commons

// Sprint 26 — auto-generated per-instance config form from a configSchema.
// Field type → row widget: bool→ToggleRow, int/real→SliderRow,
// enum→ButtonGroupRow (≤3 options) / DropdownRow, string→TextFieldRow.
// Emits `changed(config)` with the full merged config on every edit; the
// caller persists (edit mode → ShellConfig.setEntryConfig; Plugins pane →
// widget default config). Row widgets are same-dir siblings (implicit import).
Item {
    id: root
    property var schema: ({})
    property var config: ({})
    signal changed(var config)

    property var _working: ({})
    property var _fields: []

    implicitHeight: _col.implicitHeight

    function _resync() {
        var w = {}
        if (config) for (var k in config) w[k] = config[k]
        _working = w
        var f = []
        if (schema) for (var kk in schema) f.push({ key: kk, spec: schema[kk] })
        _fields = f
    }
    onConfigChanged: _resync()
    onSchemaChanged: _resync()
    Component.onCompleted: _resync()

    // Reactive so a row reflects its own edit (re-reads _working after _set).
    function _value(k) {
        if (_working[k] !== undefined) return _working[k]
        return (schema && schema[k]) ? schema[k]["default"] : undefined
    }
    function _set(k, v) {
        var w = {}
        for (var kk in _working) w[kk] = _working[kk]
        w[k] = v
        _working = w
        root.changed(w)
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 4

        Repeater {
            model: root._fields
            delegate: Loader {
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: {
                    var t = modelData.spec.type
                    if (t === "bool") return _boolComp
                    if (t === "int" || t === "real") return _numComp
                    if (t === "enum") return (modelData.spec.options && modelData.spec.options.length <= 3) ? _btnComp : _dropComp
                    return _strComp
                }
                onLoaded: {
                    item.fieldKey = modelData.key
                    item.spec     = modelData.spec
                }
            }
        }
    }

    Component { id: _boolComp
        ToggleRow {
            property string fieldKey: ""
            property var spec: ({})
            label: spec.label || fieldKey
            description: spec.description || ""
            checked: root._value(fieldKey) === true
            onToggled: v => root._set(fieldKey, v)
        }
    }
    Component { id: _numComp
        SliderRow {
            property string fieldKey: ""
            property var spec: ({})
            label: spec.label || fieldKey
            description: spec.description || ""
            from: spec.min !== undefined ? spec.min : 0
            to:   spec.max !== undefined ? spec.max : 100
            stepSize: spec.step !== undefined ? spec.step : 1
            value: { var v = root._value(fieldKey); return v !== undefined ? v : from }
            valueDisplay: Math.round(value) + (spec.unit || "")
            onMoved: v => root._set(fieldKey, spec.type === "int" ? Math.round(v) : v)
        }
    }
    Component { id: _btnComp
        ButtonGroupRow {
            property string fieldKey: ""
            property var spec: ({})
            label: spec.label || fieldKey
            description: spec.description || ""
            options: spec.options || []
            currentValue: { var v = root._value(fieldKey); return v !== undefined ? v : "" }
            onSelected: v => root._set(fieldKey, v)
        }
    }
    Component { id: _dropComp
        DropdownRow {
            property string fieldKey: ""
            property var spec: ({})
            label: spec.label || fieldKey
            description: spec.description || ""
            options: spec.options || []
            currentValue: { var v = root._value(fieldKey); return v !== undefined ? v : "" }
            onSelected: v => root._set(fieldKey, v)
        }
    }
    Component { id: _strComp
        TextFieldRow {
            property string fieldKey: ""
            property var spec: ({})
            label: spec.label || fieldKey
            description: spec.description || ""
            text: { var v = root._value(fieldKey); return v !== undefined ? v : "" }
            placeholder: spec.placeholder || ""
            onEdited: v => root._set(fieldKey, v)
        }
    }
}
