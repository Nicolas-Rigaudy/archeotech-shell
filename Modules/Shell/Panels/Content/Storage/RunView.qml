pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../../Commons" as Commons
import "../../../../../Commons/Primitives" as Prim
import "../../../../../Services/System" as SysSvc
import "../../../../../Services/System/StorageLogic.js" as Logic
import "../../../../Dashboard/panels" as Dash
import "Glyph.js" as G

// The Free step of the Storage panel, one page in three modes:
//   confirm  the exact commands that will run, admin ones marked (one password
//            prompt for all of them), then Back / Run;
//   running  the same rows with a spinner, ✓ or ✗ (and the error) as the helper
//            reports each one; no buttons, the run cannot be half-cancelled;
//   result   what was freed, the rows' outcome, Done, and the follow-ups:
//            "Empty Trash now" after Review items went to the Trash, and a btrfs
//            balance offer when a big cleanup left no unallocated space.
ColumnLayout {
    id: view
    property string mode: "confirm"    // confirm | running | result
    property var plan: []              // entry-like rows: {id, label, commands, root, bytes, upto, approx, action}
    property string home: ""
    property string notice: ""         // why Run did nothing (a scan was in progress), shown on confirm
    signal back()
    signal run()
    signal done()
    signal emptyTrash()
    signal balance()

    readonly property var store: SysSvc.Storage
    readonly property var _result: store.lastResult
    readonly property var _cmdRows: plan.filter(e => (e.commands || []).length)
    readonly property real _bytes: Logic.sumBytes(_cmdRows)
    readonly property bool _approx: _cmdRows.some(e => e.approx || e.upto)
    readonly property int _rootCount: _cmdRows.filter(e => e.root).length
    readonly property bool _trashed: plan.some(e => e.action === "trash")
    readonly property bool _emptiesTrash: plan.some(e => e.id === "trash")
    readonly property var _trashEntry: store.entries.find(e => e.id === "trash" && (e.commands || []).length) || null
    readonly property int _failed: plan.filter(e => store.runStatus[e.id] === "failed").length
    readonly property bool _offerTrash: mode === "result" && _trashed && _trashEntry !== null
                                        && plan.some(e => e.action === "trash" && store.runStatus[e.id] === "done")
    readonly property bool _offerBalance: mode === "result" && !plan.some(e => e.id === "@balance")
                                          && store.unallocated >= 0 && store.unallocated < Logic.GIB
                                          && _result && _result.freed > Logic.GIB
    spacing: Commons.Appearance.spacing.s4

    // ── Title line ─────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Commons.Appearance.spacing.s3
        Prim.Spinner {
            visible: view.mode === "running"
            running: visible
            size: Commons.Appearance.font.size3xl
        }
        Text {
            visible: view.mode === "result"
            text: view._failed || (view._result && view._result.ok === false) ? G.alert : G.check
            color: view._failed || (view._result && view._result.ok === false) ? Commons.Appearance.colors.warning
                                                                                 : Commons.Appearance.colors.success
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.size4xl
        }
        Text {
            Layout.fillWidth: true
            text: view.mode === "confirm"
                    ? (view._bytes > 0 ? "Free " + (view._approx ? "~ " : "") + Logic.formatBytes(view._bytes) + "?" : "Run these cleanups?")
                : view.mode === "running" ? "Freeing space…"
                : !view._result ? "Freeing space…"
                : "Freed " + Logic.formatBytes(view._result.freed || 0)
                  + (view._failed ? "  ·  " + view._failed + " failed" : "")
            color: Commons.Appearance.colors.textPrimary
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeHeadline
            font.weight: Commons.Appearance.font.weightSemibold
            elide: Text.ElideRight
        }
        Text {
            text: {
                if (view.mode === "result" && view._result && view._result.before && view._result.after)
                    return Logic.formatBytes(view._result.before.free) + " free  →  " + Logic.formatBytes(view._result.after.free) + " free"
                if (view.mode === "confirm" && view._bytes > 0)
                    return Logic.formatBytes(view.store.free) + " free  →  " + Logic.formatBytes(view.store.free + view._bytes) + " free"
                return ""
            }
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeLg
        }
    }

    // ── The commands ───────────────────────────────────────────────────────
    Dash.DashCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        title: view.mode === "confirm" ? "These commands will run" : view.mode === "running" ? "Running" : "What ran"

        Text {
            visible: view.mode === "confirm" && view._rootCount > 0
            Layout.fillWidth: true
            text: G.lock + "  one password prompt for " + (view._rootCount === 1 ? "the admin cleanup" : "the " + view._rootCount + " admin cleanups")
            color: Commons.Appearance.colors.overlay2
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeSm
        }

        Flickable {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: rowCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: rowCol
                width: rows.width - Commons.Appearance.spacing.s3
                Repeater {
                    model: view._cmdRows
                    delegate: Column {
                        id: line
                        required property var modelData
                        required property int index
                        readonly property string st: view.mode === "confirm" ? "" : (view.store.runStatus[modelData.id] || "")
                        readonly property string err: view.store.runErrors[modelData.id] || ""
                        width: rowCol.width
                        Prim.Divider { width: line.width; thin: true; visible: line.index > 0 }
                        Item {
                            width: line.width
                            height: Math.max(48, cmdCol.implicitHeight + Commons.Appearance.spacing.s4)

                            // Status mark (running / result): spinner, ✓, ✗, or a dot while queued.
                            Item {
                                id: mark
                                visible: view.mode !== "confirm"
                                width: visible ? Commons.Appearance.font.sizeXl * 1.8 : 0
                                height: parent.height
                                Prim.Spinner {
                                    anchors.centerIn: parent
                                    visible: line.st === "running"
                                    running: visible
                                    size: Commons.Appearance.font.sizeLg
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: line.st !== "running"
                                    text: line.st === "done" ? G.check : line.st === "failed" ? G.cross : "·"
                                    color: line.st === "done" ? Commons.Appearance.colors.success
                                         : line.st === "failed" ? Commons.Appearance.colors.error
                                         : Commons.Appearance.colors.overlay1
                                    font.family: Commons.Appearance.font.mono
                                    font.pixelSize: Commons.Appearance.font.sizeXl
                                }
                            }
                            Text {
                                id: lbl
                                anchors { left: mark.right; verticalCenter: parent.verticalCenter }
                                width: Math.min(implicitWidth, 230)
                                text: line.modelData.label
                                color: Commons.Appearance.colors.textPrimary
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeLg
                                elide: Text.ElideRight
                                HoverHandler { id: lblHov }
                                Loader {
                                    active: lblHov.hovered && lbl.truncated
                                    sourceComponent: Prim.Tooltip { parent: lbl; visible: true; text: line.modelData.label }
                                }
                            }
                            Column {
                                id: cmdCol
                                anchors {
                                    left: parent.left; leftMargin: mark.width + 240
                                    right: badge.left; rightMargin: Commons.Appearance.spacing.s4
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: Commons.Appearance.spacing.s1
                                Repeater {
                                    model: line.modelData.commands
                                    delegate: Text {
                                        id: cmdText
                                        required property string modelData
                                        width: cmdCol.width
                                        text: (line.modelData.root ? "# " : "$ ") + Logic.tilde(modelData, view.home)
                                        color: line.modelData.root ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.subtext0
                                        font.family: Commons.Appearance.font.mono
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                        elide: Text.ElideMiddle
                                        HoverHandler { id: cmdHov }
                                        Loader {
                                            active: cmdHov.hovered && cmdText.truncated
                                            sourceComponent: Prim.Tooltip { parent: cmdText; visible: true; text: cmdText.text }
                                        }
                                    }
                                }
                                Text {
                                    visible: line.err.length > 0
                                    width: cmdCol.width
                                    text: line.err
                                    color: Commons.Appearance.colors.error
                                    font.family: Commons.Appearance.font.mono
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                id: badge
                                anchors { right: sz.left; rightMargin: Commons.Appearance.spacing.s4; verticalCenter: parent.verticalCenter }
                                visible: line.modelData.root === true
                                width: visible ? badgeText.implicitWidth + Commons.Appearance.spacing.s4 : 0
                                height: badgeText.implicitHeight + Commons.Appearance.spacing.s2
                                radius: Commons.Appearance.radius.sm
                                color: Commons.Appearance.colors.surface1
                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: G.lock + " admin"
                                    color: Commons.Appearance.colors.subtext1
                                    font.family: Commons.Appearance.font.mono
                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                }
                            }
                            Text {
                                id: sz
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: Commons.Appearance.font.sizeLg * 5
                                horizontalAlignment: Text.AlignRight
                                text: typeof line.modelData.bytes === "number"
                                      ? (line.modelData.upto ? "≤ " : line.modelData.approx ? "~ " : "") + Logic.formatBytes(line.modelData.bytes) : "—"
                                color: Commons.Appearance.colors.textPrimary
                                font.family: Commons.Appearance.font.mono
                                font.pixelSize: Commons.Appearance.font.sizeLg
                            }
                        }
                    }
                }
            }
        }
    }

    // ── The note (confirm) / follow-ups (result) ───────────────────────────
    Rectangle {
        Layout.fillWidth: true
        visible: view.mode === "confirm" || view._offerBalance || (view._result && view._result.error)
        implicitHeight: noteText.implicitHeight + Commons.Appearance.spacing.s3 * 2
        radius: Commons.Appearance.radius.md
        color: Commons.Appearance.colors.surface0Alpha
        border.width: 1
        border.color: Commons.Appearance.colors.borderSubtle
        Text {
            id: noteGlyph
            x: Commons.Appearance.spacing.s4
            y: Commons.Appearance.spacing.s3
            text: view.mode === "confirm" && !view.notice && !view._emptiesTrash ? G.terminal : G.alert
            color: view.mode === "confirm" && !view.notice && !view._emptiesTrash ? Commons.Appearance.colors.subtext1
                                                                                   : Commons.Appearance.colors.warning
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeXl
        }
        Text {
            id: noteText
            anchors {
                left: noteGlyph.right; leftMargin: Commons.Appearance.spacing.s3
                right: parent.right; rightMargin: Commons.Appearance.spacing.s4
            }
            y: Commons.Appearance.spacing.s3
            wrapMode: Text.WordWrap
            color: Commons.Appearance.colors.subtext1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeMd
            text: view.mode === "confirm"
                    ? (view.notice ? view.notice + " " : "")
                      + (view._emptiesTrash ? "Emptying the Trash deletes the files in it for good. " : "")
                      + "Caches are removed, not trashed. Nothing in Documents, Projects or Pictures is touched."
                      + (view._trashed ? " Review items you ticked go to the Trash, which frees space only once emptied." : "")
                : view._result && view._result.error ? view._result.error
                : "btrfs has no unallocated space left. A balance packs the half-empty data chunks the cleanup "
                  + "left behind, so metadata can grow again. It takes a few minutes and asks for your password."
        }
    }

    // ── Footer ─────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: view.mode !== "running"
        spacing: Commons.Appearance.spacing.s3
        Text {
            Layout.fillWidth: true
            text: view.mode === "confirm" ? "Then rescans and reports what was freed"
                : view.store.scanning ? "Rescanning…" : ""
            color: Commons.Appearance.colors.overlay1
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            elide: Text.ElideRight
        }
        Prim.GlassButton { visible: view.mode === "confirm"; text: "Back"; onClicked: view.back() }
        Prim.GlassButton { visible: view.mode === "confirm"; text: "Run"; active: true; enabled: !view.store.scanning; onClicked: view.run() }
        Prim.GlassButton {
            visible: view._offerTrash
            text: "Empty Trash now" + (view._trashEntry && typeof view._trashEntry.bytes === "number"
                                       ? "  (" + Logic.formatBytes(view._trashEntry.bytes) + ")" : "")
            enabled: !view.store.scanning
            onClicked: view.emptyTrash()
        }
        Prim.GlassButton { visible: view._offerBalance; text: "Rebalance btrfs"; enabled: !view.store.scanning; onClicked: view.balance() }
        Prim.GlassButton { visible: view.mode === "result"; text: "Done"; active: true; onClicked: view.done() }
    }
}
