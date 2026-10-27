import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "../../../../../Commons" as Commons
import "../../../../../Services/Media" as MediaServices

// MediaPanel face: "full" — album art + track info + seekable progress + full
// transport (prev / play / next). Extracted verbatim from the pre-face panel.
// `host` (the MediaPanel) provides formatTime() and _narrow.
// Root fills the carousel; the player grid is vertically CENTERED inside it so the
// art stays aligned with the text/controls regardless of the panel's height.
Item {
    id: face
    property var host

    readonly property bool _narrow: host ? host._narrow : false
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        columns: face._narrow ? 1 : 2
        columnSpacing: Commons.Appearance.spacing.s4
        rowSpacing: Commons.Appearance.spacing.s4

    Item {
        readonly property int _art: face._narrow ? 72 : 92
        Layout.preferredWidth: _art; Layout.preferredHeight: _art
        Layout.alignment: face._narrow ? Qt.AlignHCenter : Qt.AlignVCenter

        RectangularShadow {
            anchors.fill: artRect; radius: artRect.radius
            blur:   Commons.Appearance.elevation.e2.blur; offset: Qt.vector2d(0, Commons.Appearance.elevation.e2.y); spread: Commons.Appearance.elevation.e2.spread
            color:  Commons.Appearance.elevation.e2.color
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
                font.pixelSize: Commons.Appearance.font.size7xl
                font.family: Commons.Appearance.font.family
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Commons.Appearance.spacing.s1

        Text {
            Layout.fillWidth: true
            text: MediaServices.MprisService.title || "Unknown track"
            color: Commons.Appearance.colors.textPrimary
            font.pixelSize: Commons.Appearance.font.sizeMd
            font.family: Commons.Appearance.font.family
            font.weight: Commons.Appearance.font.weightMedium
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: MediaServices.MprisService.artist || MediaServices.MprisService.identity || ""
            color: Commons.Appearance.colors.textSecondary
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
                anchors.top: parent.top; anchors.topMargin: Commons.Appearance.spacing.s2
                height: 4; radius: height / 2
                color: Commons.Appearance.colors.surface0

                Rectangle {
                    width: MediaServices.MprisService.length > 0 ? parent.width * Math.min(MediaServices.MprisService.position / MediaServices.MprisService.length, 1) : 0
                    height: parent.height; radius: 2
                    color: Commons.Appearance.colors.accent
                    Behavior on width { Commons.Tween { spatial: true; time: Commons.Appearance.anim.tick } }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Commons.Appearance.spacing.s1
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
                color: Commons.Appearance.colors.textMuted
                font.pixelSize: Commons.Appearance.font.size2xs; font.family: Commons.Appearance.font.family
            }
            Text {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                text: MediaServices.MprisService.length > 0 && face.host ? face.host.formatTime(MediaServices.MprisService.length) : ""
                color: Commons.Appearance.colors.textMuted
                font.pixelSize: Commons.Appearance.font.size2xs; font.family: Commons.Appearance.font.family
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Item { Layout.fillWidth: true }
            Text {
                text: "󰒮"
                color: prevArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textSecondary
                font.pixelSize: Commons.Appearance.font.size3xl; font.family: Commons.Appearance.font.family
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                MouseArea { id: prevArea; anchors.fill: parent; anchors.margins: -Commons.Appearance.spacing.s2; hoverEnabled: true; onClicked: MediaServices.MprisService.previous() }
            }
            Item { Layout.preferredWidth: 24 }
            Item {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter
                scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.06 : 1.0)
                Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
                RectangularShadow {
                    anchors.fill: playKey; radius: playKey.radius
                    blur:   Commons.Appearance.elevation.e2.blur; offset: Qt.vector2d(0, Commons.Appearance.elevation.e2.y); spread: Commons.Appearance.elevation.e2.spread
                    color:  Commons.Appearance.elevation.e2.color
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
                    font.pixelSize: Commons.Appearance.font.size3xl; font.family: Commons.Appearance.font.family
                }
                MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MediaServices.MprisService.togglePlay() }
            }
            Item { Layout.preferredWidth: 24 }
            Text {
                text: "󰒭"
                color: nextArea.containsMouse ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textSecondary
                font.pixelSize: Commons.Appearance.font.size3xl; font.family: Commons.Appearance.font.family
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                MouseArea { id: nextArea; anchors.fill: parent; anchors.margins: -Commons.Appearance.spacing.s2; hoverEnabled: true; onClicked: MediaServices.MprisService.next() }
            }
            Item { Layout.fillWidth: true }
        }
    }
    }
}
