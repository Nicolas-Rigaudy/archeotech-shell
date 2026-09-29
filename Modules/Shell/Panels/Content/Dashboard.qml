pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../../Commons" as Commons
import "../../../Dashboard/panels"

// Dashboard UI — bottom-edge panel (PanelRegistry side="bottom"). Panel.qml
// provides chrome + slide anim + Esc + click-outside; this file is the inner
// content only. `panelRoot` is injected by Loader.onLoaded.
//
// "Base of operations" layout (2026-07-20 rework): a welcoming hero (greeting +
// name + big clock + date) over a 2×2 bento of cards. Sized to fit — no scroll.
// Auto-shown on login (openAuto) but stays until dismissed — no auto-dismiss.
Item {
    id: root
    anchors.fill: parent

    property var panelRoot

    // Kept for the narrow (vertical-strip) edge case — stack to 1 column there.
    readonly property bool _wide: width >= 720

    // Live clock/greeting — tick while the panel is open.
    property var _now: new Date()
    function _greeting() {
        var h = root._now.getHours()
        var g = h < 5 ? "Good night" : h < 12 ? "Good morning"
              : h < 18 ? "Good afternoon" : "Good evening"
        // Derive the name from the home dir basename (Commons.Paths.home is
        // StandardPaths-backed — no dependency on a Quickshell.env call).
        var u = (Commons.Paths.home || "").split("/").filter(Boolean).pop() || ""
        if (u.length) u = u.charAt(0).toUpperCase() + u.slice(1)
        return u.length ? g + ", " + u : g
    }
    Timer {
        interval: 1000; repeat: true
        running: root.panelRoot ? root.panelRoot.panelOpen : false
        onTriggered: root._now = new Date()
    }

    // Content container — fills Panel's Loader bounds. Panel.qml owns chrome.
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24; anchors.rightMargin: 24
        anchors.topMargin: 20;  anchors.bottomMargin: 20
        spacing: 16

        // ── Hero — human anchor: greeting + name, big clock, date ────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: 56

            Column {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                    text: root._greeting()
                    color: Commons.Appearance.colors.textPrimary
                    font.family: Commons.Appearance.font.display
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Qt.formatDateTime(root._now, "dddd, d MMMM")
                    color: Commons.Appearance.colors.textSecondary
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeMd
                }
            }

            // Big clock
            Text {
                anchors { right: closeBtn.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: Qt.formatDateTime(root._now, "HH:mm")
                color: Commons.Appearance.colors.accent
                font.family: Commons.Appearance.font.family
                font.pixelSize: 40
                font.weight: Font.Light
            }

            // Close button
            Rectangle {
                id: closeBtn
                width: 28; height: 28
                radius: Commons.Appearance.radius.sm
                color: closeBtnHov.containsMouse ? Commons.Appearance.colors.accentAlpha : "transparent"
                border.color: closeBtnHov.containsMouse ? Commons.Appearance.colors.accentBorder : "transparent"
                anchors { right: parent.right; top: parent.top }
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                Text {
                    text: "✕"
                    color: closeBtnHov.containsMouse ? Commons.Appearance.colors.textPrimary : Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeMd
                    anchors.centerIn: parent
                }
                HoverHandler { id: closeBtnHov }
                TapHandler { onTapped: if (root.panelRoot) root.panelRoot.close() }
            }
        }

        // ── Bento grid — 2×2. No Layout.alignment, so cards STRETCH to the
        // row's height → the two cards in each row share a top AND bottom edge
        // (fixes the misalignment). Content inside each card stays top-anchored.
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root._wide ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            // fillHeight stretches cards to the row height (aligns them);
            // minimumHeight floors each at its content so fillHeight can't
            // shrink it below the content (which caused the overflow).
            SystemStatus   { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.minimumHeight: implicitHeight }
            ActiveProjects { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.minimumHeight: implicitHeight }
            QuickLaunch    { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.minimumHeight: implicitHeight }
            SystemNotes    { Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1; Layout.minimumHeight: implicitHeight }
        }

        // ── Tip — slim full-width strip at the bottom (its own line). ────────
        TipOfSession { Layout.fillWidth: true }
    }
}
