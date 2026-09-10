import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "../../../../../Commons" as Commons
import "../../../../../Services/Media" as MediaServices

// MediaPanel face: "full" — album art + track info + seekable progress + full
// transport (prev / play / next). Extracted verbatim from the pre-face panel.
// `host` (the MediaPanel) provides formatTime() and _narrow.
GridLayout {
    id: face
    property var host

    readonly property bool _narrow: host ? host._narrow : false

    Layout.fillWidth: true
    Layout.fillHeight: !_narrow
    Layout.alignment: _narrow ? Qt.AlignTop : Qt.AlignVCenter
    columns: _narrow ? 1 : 2
    columnSpacing: 14
    rowSpacing: 14

    Item {
        readonly property int _art: face._narrow ? 72 : 92
        Layout.preferredWidth: _art; Layout.preferredHeight: _art
        Layout.alignment: face._narrow ? Qt.AlignHCenter : Qt.AlignVCenter

        RectangularShadow {
            anchors.fill: artRect; radius: artRect.radius
            blur: 12; offset: Qt.vector2d(0, 3); spread: 0
            color: Qt.rgba(0, 0, 0, 0.4 * Commons.Appearance.shadowStrength)
        }
        Rectangle {
            id: artRect
            anchors.fill: parent
            radius: Commons.Appearance.radius.base
            color: Commons.Appearance.colors.base

            Image {
                id: albumArt
                anchors.fill: parent
                source: MediaServices.MprisService.artUrl || ""
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            Rectangle { id: artMask; anchors.fill: parent; radius: Commons.Appearance.radius.base; visible: false }
            OpacityMask {
                anchors.fill: albumArt
                source: albumArt; maskSource: artMask
                visible: albumArt.status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                radius: Commons.Appearance.radius.base
                color: "transparent"
                border.color: Commons.Appearance.colors.accentBorder
                border.width: 1
                visible: albumArt.status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: albumArt.status !== Image.Ready
                text: MediaServices.MprisService.appIcon || "󰝚"
                color: Commons.Appearance.colors.accent
                font.pixelSize: 40
                font.family: Commons.Appearance.font.family
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: MediaServices.MprisService.title || "Unknown track"
            color: Commons.Appearance.colors.text
            font.pixelSize: Commons.Appearance.font.sizeMd
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

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            visible: MediaServices.MprisService.available

            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.topMargin: 6
                height: 4; radius: 2
                color: Commons.Appearance.colors.surface0

                Rectangle {
                    width: MediaServices.MprisService.length > 0 ? parent.width * Math.min(MediaServices.MprisService.position / MediaServices.MprisService.length, 1) : 0
                    height: parent.height; radius: 2
                    color: Commons.Appearance.colors.accent
                    Behavior on width { NumberAnimation { duration: 950 } }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: MediaServices.MprisService.length > 0
                    onClicked: mouse => {
                        const frac = Math.max(0, Math.min(1, (mouse.x - 4) / parent.width))
                        MediaServices.MprisService.seekTo(MediaServices.MprisService.length * frac)
                    }
                }
            }
            Text {
                anchors.left: parent.left; anchors.bottom: parent.bottom
                text: face.host ? face.host.formatTime(MediaServices.MprisService.position) : ""
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: 9; font.family: Commons.Appearance.font.family
            }
            Text {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                text: MediaServices.MprisService.length > 0 && face.host ? face.host.formatTime(MediaServices.MprisService.length) : ""
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: 9; font.family: Commons.Appearance.font.family
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Item { Layout.fillWidth: true }
            Text {
                text: "󰒮"
                color: prevArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                font.pixelSize: 20; font.family: Commons.Appearance.font.family
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                MouseArea { id: prevArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.previous() }
            }
            Item { Layout.preferredWidth: 24 }
            Item {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter
                scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.06 : 1.0)
                Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                RectangularShadow {
                    anchors.fill: playKey; radius: playKey.radius
                    blur: 10; offset: Qt.vector2d(0, 3); spread: 0
                    color: Qt.rgba(0, 0, 0, 0.45 * Commons.Appearance.shadowStrength)
                }
                Rectangle {
                    id: playKey; anchors.fill: parent; radius: width / 2; antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Commons.Appearance.depthFlat ? Commons.Appearance.colors.accent : Qt.lighter(Commons.Appearance.colors.accent, 1.12) }
                        GradientStop { position: 1.0; color: Commons.Appearance.depthFlat ? Commons.Appearance.colors.accent : Qt.darker(Commons.Appearance.colors.accent, 1.10) }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: MediaServices.MprisService.playing ? "󰏤" : "󰐊"
                    color: Commons.Appearance.colors.base
                    font.pixelSize: 20; font.family: Commons.Appearance.font.family
                }
                MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MediaServices.MprisService.togglePlay() }
            }
            Item { Layout.preferredWidth: 24 }
            Text {
                text: "󰒭"
                color: nextArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                font.pixelSize: 20; font.family: Commons.Appearance.font.family
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                MouseArea { id: nextArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: MediaServices.MprisService.next() }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
