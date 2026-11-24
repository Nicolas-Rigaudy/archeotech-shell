pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../../Commons" as Commons
import "../../../../../Commons/Primitives" as Prim
import "../../../../../Services/System" as SysSvc
import "../../../../../Services/System/StorageLogic.js" as Logic
import "../../../../Dashboard/panels" as Dash
import "../../../../Settings/Widgets" as SW
import "Glyph.js" as G

// The Clean up tab (item_182, owner pick "CleanC"): the cleanups grouped by tier
// on the left (two-line rows), and on the right what the ticked ones free, the
// disk bar with that amount overlaid, the exact commands that will run, and the
// Rescan / Free buttons. The panel owns the selection and the search; this view
// only shows them and reports clicks.
RowLayout {
    id: view
    property var entries: []       // the rows to show (already filtered by the search)
    property var sel: ({})         // id -> true
    property string home: ""
    property string query: ""
    property string ageText: ""
    signal toggle(string id)
    signal rescan()
    signal free()

    readonly property var store: SysSvc.Storage
    readonly property var _all: store.entries
    readonly property var _groups: Logic.groups(entries)
    readonly property var _pick: Logic.selection(_all, sel)
    readonly property int _rootCount: _all.filter(e => sel[e.id] && e.root && e.action !== "open").length
    readonly property bool _busy: store.scanning || store.running
    readonly property string _total: (_pick.approx ? "~ " : "") + Logic.formatBytes(_pick.bytes)

    spacing: Commons.Appearance.spacing.s4

    function _tierTitle(t) { return t === "safe" ? "Safe to remove" : "Review first" }
    function _tierNote(g) {
        if (g.tier === "review") return "to the Trash"
        var all = view._all.filter(e => e.tier === g.tier)
        var on = all.filter(e => view.sel[e.id])
        return on.length + " of " + all.length + "  ·  " + Logic.formatBytes(Logic.sumBytes(on))
    }

    // ── The list ───────────────────────────────────────────────────────────
    Dash.DashCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 900

        Flickable {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: groupsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: groupsCol
                width: list.width - Commons.Appearance.spacing.s3
                spacing: Commons.Appearance.spacing.s4

                Repeater {
                    model: view._groups
                    delegate: Column {
                        id: group
                        required property var modelData
                        width: groupsCol.width

                        Item {
                            width: group.width
                            height: Commons.Appearance.font.sizeMd * 2.2
                            SW.SectionLabel {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: view._tierTitle(group.modelData.tier).toUpperCase()
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: view._tierNote(group.modelData)
                                color: Commons.Appearance.colors.overlay1
                                font.family: Commons.Appearance.font.family
                                font.pixelSize: Commons.Appearance.font.sizeSm
                            }
                        }
                        Repeater {
                            model: group.modelData.entries
                            delegate: Column {
                                id: line
                                required property var modelData
                                required property int index
                                width: group.width
                                Prim.Divider { width: line.width; thin: true; visible: line.index > 0 }
                                CleanupRow {
                                    width: line.width
                                    entry: line.modelData
                                    home: view.home
                                    checked: view.sel[line.modelData.id] === true
                                    enabled: !view._busy
                                    onToggled: view.toggle(line.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Nothing matches the search / nothing to clean.
        Prim.EmptyState {
            visible: view._groups.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: view.query ? G.search : G.check
            title: view.query ? "No cleanup matches “" + view.query + "”" : "Nothing to clean up"
            hint: view.query ? "Esc clears the search" : "Every cache and leftover the scan knows about is empty"
        }
    }

    // ── What the selection does ────────────────────────────────────────────
    Dash.DashCard {
        Layout.fillHeight: true
        Layout.preferredWidth: 440
        Layout.maximumWidth: 440
        title: "Selected"

        Text {
            text: view._pick.count ? view._total : "0 B"
            color: view._pick.count ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textMuted
            font.family: Commons.Appearance.font.mono
            font.pixelSize: Commons.Appearance.font.sizeDisplay
            font.weight: Commons.Appearance.font.weightSemibold
        }
        Text {
            Layout.fillWidth: true
            text: view._pick.count === 0 ? "Tick what to remove on the left"
                : view._pick.count + (view._pick.count === 1 ? " cleanup" : " cleanups")
                  + (view._rootCount ? "  ·  " + view._rootCount + (view._rootCount === 1 ? " needs" : " need") + " your password" : "")
                  + (view._pick.unknown ? "  ·  " + view._pick.unknown + " of unknown size" : "")
            color: Commons.Appearance.colors.overlay2
            font.family: Commons.Appearance.font.family
            font.pixelSize: Commons.Appearance.font.sizeBase
            wrapMode: Text.WordWrap
        }
        DiskBar {
            Layout.fillWidth: true
            Layout.topMargin: Commons.Appearance.spacing.s2
            freeing: view._pick.bytes
        }
        Prim.Divider { Layout.fillWidth: true; Layout.topMargin: Commons.Appearance.spacing.s2; Layout.bottomMargin: Commons.Appearance.spacing.s2 }
        SW.SectionLabel { text: "WILL RUN" }

        // The exact commands, admin ones (#) first: what the Free button runs.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80
            radius: Commons.Appearance.radius.sm
            color: Commons.Appearance.colors.crust
            border.width: 1
            border.color: Commons.Appearance.colors.borderSubtle
            Flickable {
                id: cmds
                anchors.fill: parent
                anchors.margins: Commons.Appearance.spacing.s3
                clip: true
                contentHeight: cmdCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: cmdCol
                    width: cmds.width
                    spacing: Commons.Appearance.spacing.s1
                    Repeater {
                        model: view._pick.root.map(c => "# " + c).concat(view._pick.user.map(c => "$ " + c))
                        delegate: Text {
                            required property string modelData
                            width: cmdCol.width
                            text: Logic.tilde(modelData, view.home)
                            color: modelData.charAt(0) === "#" ? Commons.Appearance.colors.textPrimary
                                                                : Commons.Appearance.colors.subtext0
                            font.family: Commons.Appearance.font.mono
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: view._pick.root.length + view._pick.user.length === 0
                text: view._pick.count ? "Only folders to open: nothing runs" : "Nothing selected"
                color: Commons.Appearance.colors.textMuted
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeSm
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Commons.Appearance.spacing.s2
            spacing: Commons.Appearance.spacing.s3
            Text {
                Layout.fillWidth: true
                text: (view.store.scanning ? "Scanning…" : view.ageText ? "Scanned " + view.ageText : "")
                color: Commons.Appearance.colors.overlay1
                font.family: Commons.Appearance.font.mono
                font.pixelSize: Commons.Appearance.font.sizeSm
                elide: Text.ElideRight
            }
            Prim.GlassButton {
                text: "Rescan"
                enabled: !view._busy
                onClicked: view.rescan()
            }
            Prim.GlassButton {
                text: view._pick.root.length + view._pick.user.length ? "Free " + view._total : "Free"
                active: true
                enabled: !view._busy && view._pick.root.length + view._pick.user.length > 0
                onClicked: view.free()
            }
        }
    }
}
