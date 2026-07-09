pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons
import "../../../Dashboard/panels"

// Dashboard UI — bottom-edge panel (PanelRegistry side="bottom"). Panel.qml
// provides chrome + slide anim + Esc + click-outside; this file is the inner
// content only. `panelRoot` is injected by Loader.onLoaded.
//
// Auto-dismiss timer (4s) fires when `Commons.State.dashboardAutoOpen` is
// true and closes via `panelRoot.close()`.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    // Responsive: two columns side-by-side when the card is wide (bottom strip),
    // stacked + scrollable when narrow (vertical side strip). Keys on the actual
    // allocated width, so it's holder-agnostic — no per-side variant. (S26-C)
    readonly property bool _wide: width >= 720

    // Auto-dismiss when opened via autostart (openAuto IPC call)
    Timer {
        id: autoDismiss
        interval: 4000
        repeat: false
        running: false
        onTriggered: {
            if (root.panelRoot) root.panelRoot.close()
            Commons.State.dashboardAutoOpen = false
        }
    }

    Connections {
        target: root.panelRoot
        enabled: root.panelRoot !== null
        function onPanelOpenChanged() {
            if (root.panelRoot.panelOpen && Commons.State.dashboardAutoOpen)
                autoDismiss.restart()
            else
                autoDismiss.stop()
        }
    }

    // Content container — fills Panel's Loader bounds. Panel.qml owns chrome
    // (color/border/radius) + slide-from-bottom anim.
    Item {
        id: panel
        anchors.fill: parent
        clip: true

        // ── Header ──────────────────────────────────────────────────────
        Item {
            id: header
            anchors { top: parent.top; topMargin: 20; left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 24 }
            height: 28

            Text {
                text: "ARCHEOTECH-OS"
                color: Commons.Appearance.colors.accent
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
                font.letterSpacing: 3
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: dateLbl
                color: Commons.Appearance.colors.subtext0
                font.family: Commons.Appearance.font.family
                font.pixelSize: Commons.Appearance.font.sizeMd
                anchors { right: closeBtn.left; rightMargin: 12; verticalCenter: parent.verticalCenter }

                property var _now: new Date()
                text: Qt.formatDateTime(_now, "ddd yyyy-MM-dd")

                Timer {
                    interval: 60000
                    repeat: true
                    running: root.panelRoot ? root.panelRoot.panelOpen : false
                    onTriggered: dateLbl._now = new Date()
                }
            }

            // Close button
            Rectangle {
                id: closeBtn
                width: 26; height: 26
                radius: Commons.Appearance.radius.sm
                color: closeBtnHov.containsMouse ? Commons.Appearance.colors.accentAlpha : "transparent"
                border.color: closeBtnHov.containsMouse ? Commons.Appearance.colors.accentBorder : "transparent"
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                Text {
                    text: "✕"
                    color: closeBtnHov.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay1
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeMd
                    anchors.centerIn: parent
                }
                HoverHandler { id: closeBtnHov }
                TapHandler { onTapped: if (root.panelRoot) root.panelRoot.close() }
            }
        }

        Rectangle {
            id: divider
            anchors { top: header.bottom; topMargin: 8; left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 24 }
            height: 1
            color: Commons.Appearance.colors.surface0
        }

        // ── Body — reflowing grid, scrollable when stacked ────────────────
        Flickable {
            anchors {
                top:    divider.bottom; topMargin:    16
                left:   parent.left;    leftMargin:   24
                right:  parent.right;   rightMargin:  24
                bottom: parent.bottom;  bottomMargin: 20
            }
            clip: true
            contentWidth: width
            contentHeight: grid.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            GridLayout {
                id: grid
                width: parent.width
                columns: root._wide ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16

                // Two grouped column-containers. Wide → sit side-by-side;
                // narrow → the grid drops to 1 column and they stack in order.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1   // equal split with the right group
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    SystemStatus { Layout.fillWidth: true }
                    SystemNotes  { Layout.fillWidth: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    ActiveProjects { Layout.fillWidth: true }
                    QuickLaunch    { Layout.fillWidth: true }
                    TipOfSession   { Layout.fillWidth: true }
                }
            }
        }
    }
}
