pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Must be Item (not QtObject) to support child objects like Connections and Timer
Item {
    id: root
    visible: false

    property MprisPlayer _player: null
    readonly property MprisPlayer player: _player

    Component.onCompleted: _updatePlayer()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root._updatePlayer() }
    }

    Timer {
        interval: 1000; repeat: true; running: root.playing
        onTriggered: root.positionTick++
    }
    property int positionTick: 0

    function _updatePlayer() {
        var list = Mpris.players.values
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying) { _player = list[i]; return }
        }
        _player = list.length > 0 ? list[0] : null
    }

    readonly property bool available:  player !== null
    readonly property bool playing:    player !== null && player.isPlaying
    readonly property string title:    player !== null ? (player.trackTitle  || "") : ""
    readonly property string artist:   player !== null ? (player.trackArtist || "") : ""
    readonly property string artUrl:   player !== null ? (player.trackArtUrl || "") : ""
    readonly property string identity: player !== null ? (player.identity    || "") : ""

    readonly property double position: { positionTick; return player !== null && player.positionSupported ? player.position : 0 }
    readonly property double length:   player !== null && player.lengthSupported   ? player.length   : 0

    function togglePlay() {
        if (player !== null && player.canTogglePlaying) player.togglePlaying()
    }
    function next() {
        if (player !== null && player.canGoNext) player.next()
    }
    function previous() {
        if (player !== null && player.canGoPrevious) player.previous()
    }
    function seekTo(seconds) {
        if (player !== null && player.canSeek) player.position = seconds
    }

    readonly property string appIcon: {
        if (player === null) return "󰝚"
        var e = (player.desktopEntry || "").toLowerCase()
        if (e.includes("spotify"))                           return "󰓇"
        if (e.includes("firefox") || e.includes("zen"))     return "󰈹"
        if (e.includes("chrome") || e.includes("chromium")) return "󰊯"
        if (e.includes("vlc"))                               return "󰕼"
        if (e.includes("mpv"))                               return "󰝚"
        if (e.includes("rhythmbox") || e.includes("elisa")) return "󰓃"
        return "󰝚"
    }
}
