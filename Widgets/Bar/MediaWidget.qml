import QtQuick
import QtQuick.Layouts
import "../../Commons" as Commons
import "../../Services/Media" as MediaServices
import "../../Services/Persistence" as Persistence
import "../../Services/Shell" as ShellServices

// MPRIS marquee — separator dot, play/pause toggle, scrolling title·artist.
// Collapses to zero width when nothing is playing so it doesn't push the
// title/clock around.
Item {
    id: root
    required property var holderRoot
    property string widgetId

    visible: Persistence.Config.get("bar.modules.music", true)
        && holderRoot && holderRoot.horizontal

    property bool active: MediaServices.MprisService.playing === true
    property string displayText: {
        if (!MediaServices.MprisService) return ""
        var t = MediaServices.MprisService.title  || ""
        var a = MediaServices.MprisService.artist || ""
        if (t.length > 0 && a.length > 0) return t + "  ·  " + a
        if (t.length > 0) return t
        return a
    }

    // Reserve real layout width (the loader sizes to implicitWidth). Without
    // this the root Item reports 0 and the 200px content floats over the clock.
    // Collapses to 0 when idle so it doesn't push the title/clock around.
    implicitWidth:  active ? 200 : 0
    implicitHeight: Commons.Appearance.bar.height
    Layout.alignment: Qt.AlignVCenter
    opacity: active ? 1 : 0
    Behavior on implicitWidth { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
    Behavior on opacity       { NumberAnimation { duration: Commons.Appearance.anim.fast } }

    width: 200
    height: Commons.Appearance.bar.height
    clip: true

    Text {
        id: mprisSep
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "·"
        color: Commons.Appearance.colors.surface1
        font.pixelSize: Commons.Appearance.font.sizeSm
        font.family: Commons.Appearance.font.family
    }

    Text {
        id: mprisIcon
        anchors.left: mprisSep.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: MediaServices.MprisService.playing ? "󰝚" : "󰏤"
        color: Commons.Appearance.colors.accent
        font.pixelSize: 12
        font.family: Commons.Appearance.font.family
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: MediaServices.MprisService.togglePlay()
        }
    }

    Item {
        id: marqueeContainer
        anchors.left: mprisIcon.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        height: Commons.Appearance.font.sizeSm + 4
        clip: true

        property real textWidth: marqueeText1.implicitWidth
        property bool needsScroll: textWidth > marqueeContainer.width
        property real scrollPos: 0

        property string displayText: root.displayText

        Timer {
            id: marqueeStartTimer
            interval: 80; repeat: false
            onTriggered: {
                marqueeAnim.stop()
                marqueeContainer.scrollPos = 0
                if (marqueeContainer.needsScroll && root.active)
                    marqueeAnim.start()
            }
        }

        onDisplayTextChanged: marqueeStartTimer.restart()
        onNeedsScrollChanged: {
            if (needsScroll) marqueeStartTimer.restart()
            else { marqueeAnim.stop(); scrollPos = 0 }
        }

        Connections {
            target: root
            function onActiveChanged() {
                if (root.active) marqueeStartTimer.restart()
                else { marqueeAnim.stop(); marqueeContainer.scrollPos = 0 }
            }
        }

        SequentialAnimation {
            id: marqueeAnim
            loops: Animation.Infinite

            NumberAnimation {
                target: marqueeContainer; property: "scrollPos"
                from: 0
                to: marqueeContainer.textWidth + 40
                duration: Math.max(5000, (marqueeContainer.textWidth + 40) * 20)
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: 600 }
            ScriptAction { script: marqueeContainer.scrollPos = 0 }
            PauseAnimation { duration: 300 }
        }

        Text {
            id: marqueeText1
            x: marqueeContainer.needsScroll ? -marqueeContainer.scrollPos : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            color: Commons.Appearance.colors.subtext1
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
            elide: marqueeContainer.needsScroll ? Text.ElideNone : Text.ElideRight
            width: marqueeContainer.needsScroll ? implicitWidth : marqueeContainer.width
        }

        Text {
            x: marqueeText1.x + marqueeContainer.textWidth + 40
            anchors.verticalCenter: parent.verticalCenter
            visible: marqueeContainer.needsScroll
            text: root.displayText
            color: Commons.Appearance.colors.subtext1
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
        }

        // Click the title/artist → open the Media panel (play/pause stays on
        // the icon to the left).
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellServices.ShellState.toggleGlobal("media")
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: if (root.holderRoot) root.holderRoot.showPopup(root, "NOW PLAYING",
            MediaServices.MprisService.title  || "—",
            MediaServices.MprisService.artist || "",
            "Click icon to play / pause")
        onExited: if (root.holderRoot) root.holderRoot.hidePopup(root)
    }
}
