import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../../../../Commons" as Commons
import "../../../../../Services/Media" as MediaServices

// MediaPanel face: "compact" — a single dense row: small art + title/artist +
// inline prev/play/next. No progress bar or seek. Reads MprisService directly.
RowLayout {
    id: face
    property var host
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
    spacing: 12

    // Small album art / app-icon
    Rectangle {
        Layout.preferredWidth: 48; Layout.preferredHeight: 48
        Layout.alignment: Qt.AlignVCenter
        radius: Commons.Appearance.radius.base
        color: Commons.Appearance.colors.base

        Image {
            id: art
            anchors.fill: parent
            source: MediaServices.MprisService.artUrl || ""
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        Rectangle { id: artMask; anchors.fill: parent; radius: Commons.Appearance.radius.base; visible: false }
        OpacityMask { anchors.fill: art; source: art; maskSource: artMask; visible: art.status === Image.Ready }
        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: MediaServices.MprisService.appIcon || "󰝚"
            color: Commons.Appearance.colors.accent
            font.pixelSize: 24
            font.family: Commons.Appearance.font.family
        }
    }

    // Title + artist
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 1
        Text {
            Layout.fillWidth: true
            text: MediaServices.MprisService.title || "Unknown track"
            color: Commons.Appearance.colors.text
            font.pixelSize: Commons.Appearance.font.sizeBase
            font.family: Commons.Appearance.font.family
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: MediaServices.MprisService.artist || MediaServices.MprisService.identity || ""
            color: Commons.Appearance.colors.subtext0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
            elide: Text.ElideRight
        }
    }

    // Inline transport
    Text {
        text: "󰒮"
        color: cPrev.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
        font.pixelSize: 16; font.family: Commons.Appearance.font.family
        Layout.alignment: Qt.AlignVCenter
        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
        MouseArea { id: cPrev; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.previous() }
    }
    Text {
        text: MediaServices.MprisService.playing ? "󰏤" : "󰐊"
        color: cPlay.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.text
        font.pixelSize: 22; font.family: Commons.Appearance.font.family
        Layout.alignment: Qt.AlignVCenter
        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
        MouseArea { id: cPlay; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MediaServices.MprisService.togglePlay() }
    }
    Text {
        text: "󰒭"
        color: cNext.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
        font.pixelSize: 16; font.family: Commons.Appearance.font.family
        Layout.alignment: Qt.AlignVCenter
        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
        MouseArea { id: cNext; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.next() }
    }
}
