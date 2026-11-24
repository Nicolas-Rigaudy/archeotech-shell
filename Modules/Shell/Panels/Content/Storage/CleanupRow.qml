pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../../../Commons" as Commons
import "../../../../../Commons/Primitives" as Prim
import "../../../../../Services/System/StorageLogic.js" as Logic
import "Glyph.js" as G

// One cleanup source in the Clean up list: checkbox, label (+ "admin" when it
// needs the password), what deleting it costs on the second line, and its path
// and size on the right. A click ticks it; an "open" row (Downloads…) has
// nothing to run, so a click opens the folder in the file manager instead.
Item {
    id: row
    required property var entry
    property bool checked: false
    property string home: ""
    signal toggled()

    readonly property bool _open: entry.action === "open"
    readonly property string _size: typeof entry.bytes === "number"
        ? (entry.upto ? "≤ " : entry.approx ? "~ " : "") + Logic.formatBytes(entry.bytes) : "—"
    readonly property string _path: Logic.tilde((entry.paths || [])[0] || "", home)
                                    + ((entry.paths || []).length > 1 ? "  +" + (entry.paths.length - 1) : "")

    implicitHeight: 50
    opacity: enabled ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Commons.Appearance.spacing.s2
        anchors.rightMargin: -Commons.Appearance.spacing.s2
        radius: Commons.Appearance.radius.sm
        color: Commons.Appearance.colors.surface0Alpha
        opacity: hov.hovered && row.enabled ? 1 : 0
        Behavior on opacity { Commons.Tween {} }
    }

    Text {
        id: box
        anchors.verticalCenter: parent.verticalCenter
        width: Commons.Appearance.font.sizeXl * 1.6
        text: row._open ? G.folder : row.checked ? G.boxOn : G.boxOff
        color: row.checked && !row._open ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay1
        font.family: Commons.Appearance.font.mono
        font.pixelSize: Commons.Appearance.font.sizeXl
    }

    ColumnLayout {
        anchors {
            left: box.right; right: pathText.left; rightMargin: Commons.Appearance.spacing.s4
            verticalCenter: parent.verticalCenter
        }
        spacing: Commons.Appearance.spacing.s1
        RowLayout {
            spacing: Commons.Appearance.spacing.s2
            Layout.fillWidth: true
            Text {
                id: labelText
                Layout.fillWidth: implicitWidth > parent.width
                text: row.entry.label
                color: Commons.Appearance.colors.textPrimary
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
                elide: Text.ElideRight
            }
            Text {
                visible: row.entry.root === true
                text: G.lock + " admin"
                color: Commons.Appearance.colors.overlay2
                font.family: Commons.Appearance.font.mono
                font.pixelSize: Commons.Appearance.font.sizeSm
            }
        }
        Text {
            id: costText
            Layout.fillWidth: true
            text: row.entry.cost || row.entry.detail || ""
            color: Commons.Appearance.colors.overlay2
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeSm
            elide: Text.ElideRight
        }
    }

    Text {
        id: pathText
        anchors { right: sizeText.left; rightMargin: Commons.Appearance.spacing.s4; verticalCenter: parent.verticalCenter }
        width: Math.min(implicitWidth, row.width * 0.32)
        text: row._path
        color: Commons.Appearance.colors.overlay1
        font.family: Commons.Appearance.font.mono
        font.pixelSize: Commons.Appearance.font.sizeSm
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
    }
    Text {
        id: sizeText
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: Commons.Appearance.font.sizeMd * 5
        horizontalAlignment: Text.AlignRight
        text: row._size
        color: row.checked || row._open ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.subtext0
        font.family: Commons.Appearance.font.mono
        font.pixelSize: Commons.Appearance.font.sizeMd
    }

    HoverHandler { id: hov; enabled: row.enabled; cursorShape: Qt.PointingHandCursor }
    // What an elided label, cost line or path says in full (built only while hovered).
    readonly property string _full: !hov.hovered ? ""
        : [labelText.truncated ? row.entry.label : "", costText.truncated ? costText.text : "",
           pathText.truncated || (row.entry.paths || []).length > 1 ? (row.entry.paths || []).map(p => Logic.tilde(p, row.home)).join("  ·  ") : ""]
          .filter(t => t).join("\n")
    Loader {
        active: row._full.length > 0
        sourceComponent: Prim.Tooltip { parent: row; visible: true; text: row._full }
    }
    TapHandler {
        enabled: row.enabled
        onTapped: {
            if (row._open) {
                const p = (row.entry.paths || [])[0]
                if (p) Quickshell.execDetached(["xdg-open", p])
            } else row.toggled()
        }
    }
}
