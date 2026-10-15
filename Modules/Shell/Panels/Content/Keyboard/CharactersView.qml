pragma ComponentBehavior: Bound
import QtQuick
import "../../../../../Commons" as Commons
import "../../../../../Commons/Primitives" as Prim

// Characters tab of the Keyboard panel (item_144): how to type each character on
// the selected keyboard. One line per letter form, lower-case and capital side by
// side (é | É), grouped by letter; each form shows its easiest combo as keycaps
// (→ between steps) and a muted "or …" second way. Search: a character ("é"),
// a letter ("e" → every accented e) or a name ("cedilla"). Clicking a form, or
// Enter on the selected line (Shift+Enter: its capital), emits `picked(ch)`.
Item {
    id: root

    property var map: null                  // one scripts/keymap-data.py map
    property string query: ""
    signal picked(string ch)

    readonly property int _capH: 24
    readonly property int _charW: 28
    // One form (é + its combos): half of what the accent name leaves, at most 400.
    readonly property real _formW: Math.max(160, Math.min(400, (width - _nameW - Commons.Appearance.spacing.s8) / 2))
    readonly property int _nameW: 150
    readonly property int _rowH: 34

    property int sel: 0                     // selected line (keyboard)
    property var hov: null                  // hovered form: a result object
    onQueryChanged: sel = 0
    onMapChanged: sel = 0

    readonly property var _results: {
        if (!map) return []
        var q = query.trim()
        var all = map.chars
        // No query: what is one chord away (the AltGr layer, as a list).
        if (q === "") return all.filter(c => c.combos[0].length === 1)
        if (q.length === 1) {
            var l = q.toLowerCase()
            return all.filter(c => c.ch === q || c.base === l)
        }
        var w = q.toLowerCase()
        return all.filter(c => c.name.toLowerCase().indexOf(w) >= 0)
    }
    // Lines: a lower-case form and its capital side by side (é | É), grouped by
    // letter; symbols and unpaired forms take a line of their own.
    readonly property var _lines: {
        var by = {}, used = {}, out = []
        _results.forEach(c => by[c.ch] = c)
        _results.forEach(c => {
            if (used[c.ch]) return
            var up = c.ch.toUpperCase(), low = c.ch.toLowerCase()
            if (up !== c.ch && by[up]) { out.push({ a: c, b: by[up] }); used[up] = true }
            else if (low !== c.ch && by[low]) return            // its lower form pairs it
            else out.push({ a: c, b: null })
            used[c.ch] = true
        })
        out.forEach(l => l.group = l.a.base ? l.a.base.toUpperCase() : "Symbols")
        return out
    }
    // Key labels the diagram lights: the hovered form's easiest combo, else the
    // selected line's first form.
    readonly property var lit: {
        var r = hov || (_lines[sel] ? _lines[sel].a : null)
        return r ? r.combos[0].reduce((l, chord) => l.concat(chord), []) : []
    }
    readonly property int count: _results.length

    // Keyboard, driven by the panel's search field.
    function up()   { sel = Math.max(0, sel - 1) }
    function down() { sel = Math.max(0, Math.min(_lines.length - 1, sel + 1)) }
    function enter(shift) {
        var l = _lines[sel]
        if (l) picked(shift && l.b ? l.b.ch : l.a.ch)
    }

    // "Latin Small Letter E With Acute" → "acute"; other names as they are.
    function _short(n) {
        var m = /^Latin (?:Small|Capital) (?:Letter|Ligature) \S+(?: With (.*))?$/.exec(n)
        return m ? (m[1] ? m[1].toLowerCase() : "") : n.toLowerCase()
    }

    component Cap: Rectangle {
        property string text: ""
        property bool lit: false
        implicitWidth: capText.implicitWidth + Commons.Appearance.spacing.s3
        implicitHeight: root._capH
        radius: Commons.Appearance.radius.xs
        color: lit ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0Alpha
        border.width: 1
        border.color: lit ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.glassBorder
        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.text
            textFormat: Text.PlainText
            color: Commons.Appearance.colors.textPrimary
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.weight: Commons.Appearance.font.weightMedium
        }
    }

    // One way to write a character on a result line: the glyph, its easiest combo
    // as keycaps (→ between steps) and a muted "or …" second way. Click copies.
    component Form: Item {
        id: form
        property var item: null
        signal picked()
        height: root._rowH
        HoverHandler {
            id: formHov
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.hov = hovered ? form.item : (root.hov === form.item ? null : root.hov)
        }
        TapHandler { onTapped: { form.picked(); if (form.item) root.picked(form.item.ch) } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: Commons.Appearance.spacing.s1 / 2
            radius: Commons.Appearance.radius.sm
            color: formHov.hovered ? Commons.Appearance.colors.surface0Alpha : "transparent"
        }
        Text {
            id: glyph
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: root._charW
            horizontalAlignment: Text.AlignHCenter
            text: form.item ? form.item.ch : ""
            textFormat: Text.PlainText
            color: Commons.Appearance.colors.textPrimary
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeXl
        }
        Row {
            anchors { left: glyph.right; leftMargin: Commons.Appearance.spacing.s2; right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Commons.Appearance.spacing.s1
            clip: true
            Repeater {
                model: form.item ? form.item.combos : []
                delegate: Row {
                    id: combo
                    required property var modelData
                    required property int index
                    spacing: Commons.Appearance.spacing.s1
                    opacity: index === 0 ? 1 : 0.55
                    Text {
                        visible: combo.index > 0
                        height: root._capH
                        leftPadding: Commons.Appearance.spacing.s2
                        verticalAlignment: Text.AlignVCenter
                        text: "or"
                        color: Commons.Appearance.colors.textMuted
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.size2xs
                    }
                    Repeater {
                        model: combo.modelData
                        delegate: Row {
                            id: step
                            required property var modelData
                            required property int index
                            spacing: Commons.Appearance.spacing.s1
                            Text {
                                visible: step.index > 0
                                height: root._capH
                                verticalAlignment: Text.AlignVCenter
                                text: "→"
                                color: Commons.Appearance.colors.textMuted
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeSm
                            }
                            Repeater {
                                model: step.modelData
                                delegate: Cap { required property var modelData; text: modelData }
                            }
                        }
                    }
                }
            }
        }
    }


    // ── Results: one line per letter form (é | É), grouped by letter ─────
    ListView {
        id: list
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root._lines
        currentIndex: root.sel
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        section.property: "group"
        section.delegate: Item {
            id: sec
            required property string section
            width: list.width
            height: root._rowH
            Text {
                id: secName
                anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s2; bottom: parent.bottom; bottomMargin: Commons.Appearance.spacing.s1 }
                text: sec.section
                color: Commons.Appearance.colors.accent
                font.family: Commons.Appearance.font.display
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.letterSpacing: Commons.Appearance.font.trackingLabel
            }
            Prim.Divider {
                thin: true
                anchors { left: secName.right; leftMargin: Commons.Appearance.spacing.s3; right: parent.right; verticalCenter: secName.verticalCenter }
            }
        }

        Text {
            visible: root.map !== null && root._lines.length === 0
            width: list.width
            topPadding: Commons.Appearance.spacing.s8
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: root.query.trim() === "" ? "This layout types nothing beyond plain ASCII"
                : "“" + root.query + "” can't be typed on this keyboard"
            color: Commons.Appearance.colors.textMuted
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeMd
        }

        delegate: Rectangle {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: index === root.sel
            width: list.width
            height: root._rowH
            radius: Commons.Appearance.radius.sm
            color: current ? Commons.Appearance.colors.accentAlpha
                 : index % 2 === 1 ? Qt.alpha(Commons.Appearance.colors.surface0, 0.25) : "transparent"
            border.width: current ? 1 : 0
            border.color: Commons.Appearance.colors.accentBorder

            Row {
                anchors { left: parent.left; leftMargin: Commons.Appearance.spacing.s2; verticalCenter: parent.verticalCenter }
                spacing: Commons.Appearance.spacing.s4
                Form { width: root._formW; item: line.modelData.a; onPicked: root.sel = line.index }
                Form { width: root._formW; item: line.modelData.b; visible: !!line.modelData.b; onPicked: root.sel = line.index }
            }

            Text {
                anchors { right: parent.right; rightMargin: Commons.Appearance.spacing.s3; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth, root._nameW)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: root._short(line.modelData.a.name)
                textFormat: Text.PlainText
                color: Commons.Appearance.colors.textMuted
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeSm
            }
        }
    }

}
