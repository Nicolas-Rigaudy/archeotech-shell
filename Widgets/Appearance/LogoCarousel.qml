import QtQuick
import Quickshell.Io
import "../../Commons" as Commons

// Sprint 26 — logo picker as a snap-to-centre carousel (Off / Arch / Rebel /
// Imperial), matching the wallpaper + theme carousels. Each tile renders the
// SAME SVG used by wallpaper-set.sh — read via FileView with LOGO_COLOR
// substituted in-memory so the glyph tracks the theme text colour. Apply goes
// through wallpaper-set.sh so this UI and the bash keybind stay in sync.
Item {
    id: root

    // Quick-switcher panel passes its strip so we re-read the active logo on
    // open (it may have changed via keybind). Embedded hosts leave it null.
    property var panelRoot: null

    // Lay the carousel top→bottom for left/right panels.
    property bool vertical: false

    property string currentLogo: ""    // "", "arch", "rebel", "imperial"
    readonly property bool applying: logoProc.running

    readonly property string _assetsBase: Commons.Paths.config + "/archeotech/assets"

    property string _archSvgRaw: ""
    property string _rebelSvgRaw: ""
    property string _imperialSvgRaw: ""

    readonly property string _archSvg:     _svgDataUri(_archSvgRaw)
    readonly property string _rebelSvg:    _svgDataUri(_rebelSvgRaw)
    readonly property string _imperialSvg: _svgDataUri(_imperialSvgRaw)

    function _svgFor(id) {
        if (id === "arch")     return _archSvg
        if (id === "rebel")    return _rebelSvg
        if (id === "imperial") return _imperialSvg
        return ""
    }
    function _svgDataUri(content) {
        if (!content) return ""
        var sub = content
            .replace(/LOGO_COLOR/g,   "" + Commons.Appearance.colors.text)
            .replace(/LOGO_OPACITY/g, "1.0")
        return "data:image/svg+xml;utf8," + encodeURIComponent(sub)
    }

    readonly property var _logoOptions: [
        { id: "",         label: "Off",      glyph: "󰳤" },
        { id: "arch",     label: "Arch",     glyph: "" },
        { id: "rebel",    label: "Rebel",    glyph: "" },
        { id: "imperial", label: "Imperial", glyph: "" }
    ]

    FileView { path: root._assetsBase + "/arch-logo.svg";     preload: true; printErrors: false; onTextChanged: root._archSvgRaw = text() }
    FileView { path: root._assetsBase + "/rebel-logo.svg";    preload: true; printErrors: false; onTextChanged: root._rebelSvgRaw = text() }
    FileView { path: root._assetsBase + "/imperial-logo.svg"; preload: true; printErrors: false; onTextChanged: root._imperialSvgRaw = text() }

    Component.onCompleted: _refresh()
    Connections {
        target: root.panelRoot
        ignoreUnknownSignals: true
        function onPanelOpenChanged() {
            if (root.panelRoot && root.panelRoot.panelOpen) root._refresh()
        }
    }
    function _refresh() { if (!logoReader.running) logoReader.running = true }

    function _applyLogo(id) {
        if (applying) return
        var toggleOff = (id === "" || id === root.currentLogo)
        root.currentLogo = toggleOff ? "" : id
        logoProc.command = toggleOff
            ? [Commons.Paths.wallpaperSet, "--toggle-logo"]
            : [Commons.Paths.wallpaperSet, "--toggle-logo", id]
        logoProc.running = true
        logoRefreshTimer.restart()
    }

    Process { id: logoProc; running: false }
    Timer {
        id: logoRefreshTimer
        interval: 250
        onTriggered: { if (!logoReader.running) logoReader.running = true }
    }
    Process {
        id: logoReader
        running: false
        command: ["bash", "-c", "cat \"$HOME/.cache/wallpaper/logo-active\" 2>/dev/null || true"]
        property string _buf: ""
        onRunningChanged: if (running) _buf = ""
        stdout: SplitParser { onRead: line => { logoReader._buf = line.trim() } }
        onExited: root.currentLogo = logoReader._buf
    }

    Carousel {
        id: strip
        anchors.fill: parent
        model: root._logoOptions
        vertical: root.vertical
        itemSpacing: Math.floor(Math.min((root.vertical ? width : height) - 12, 140) * 1.15)

        onModelChanged: _sync()
        Component.onCompleted: _sync()
        Connections {
            target: root
            function onCurrentLogoChanged() { strip._sync() }
        }
        function _sync() {
            var i = root._logoOptions.findIndex(function(o) { return o.id === root.currentLogo })
            if (i >= 0) currentIndex = i
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index

            readonly property bool _current: PathView.isCurrentItem
            readonly property bool _active:  root.currentLogo === modelData.id
            readonly property int  _s: Math.min((root.vertical ? strip.width : strip.height) - 12, 140)
            readonly property string _svgData: root._svgFor(modelData.id)

            width: _s; height: _s
            z: _current ? 2 : 1
            scale:   _current ? 1.0 : 0.7
            opacity: root.applying ? (_active ? 1.0 : 0.4) : (_current ? 1.0 : 0.55)
            Behavior on scale   { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: Commons.Appearance.radius.md
                color: cell._active ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0
                border.width: cell._active ? 2 : (cell._current ? 1 : 0)
                border.color: Commons.Appearance.colors.accent
                Behavior on color        { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                Image {
                    anchors.fill: parent
                    anchors.margins: 14
                    source: cell._svgData
                    sourceSize.width: 128; sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: cell._svgData !== ""
                    opacity: cell._active || cell._current ? 1.0 : 0.7
                }
                Text {
                    anchors.centerIn: parent
                    visible: cell._svgData === ""
                    text: cell.modelData.glyph
                    color: cell._active ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                    font.pixelSize: Math.floor(cell._s * 0.4)
                    font.family: Commons.Appearance.font.family
                }
            }

            Text {
                anchors { top: parent.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                visible: cell._current
                text: cell.modelData.label
                color: Commons.Appearance.colors.subtext0
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
            }

            MouseArea {
                anchors.fill: parent
                enabled: !root.applying
                cursorShape: root.applying ? Qt.BusyCursor : Qt.PointingHandCursor
                onClicked: {
                    if (cell._current) root._applyLogo(cell.modelData.id)
                    else strip.currentIndex = cell.index
                }
            }
        }
    }
}
