import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices

// Shared wallpaper + logo selection UI (Sprint 24). Lives once here and is
// hosted by both the quick-switcher WallpaperPicker panel (full header) and
// the Settings → Appearance pane (embedded: true — no title/count/palette
// button, fixed carousel height).
//
// Top: centered row of logo tiles (Off + Arch + Rebel + Imperial). Each tile
// renders the SAME SVG used by wallpaper-set.sh — read via FileView with
// LOGO_COLOR / LOGO_OPACITY substituted in-memory, fed to Image as a data URI.
// Below: horizontal carousel of wallpaper thumbnails. All apply paths go
// through wallpaper-set.sh so this UI and the bash keybind stay in sync.
Item {
    id: root
    // No self-anchor: the panel wrapper anchors.fill this; the Settings pane
    // sizes it via Layout.*. The inner ColumnLayout fills the root either way.

    // Host hook — the quick-switcher panel passes its strip so we refresh on
    // open; the embedded (Settings) host leaves it null and relies on the
    // Component.onCompleted scan. Default null (not undefined) so the
    // Connections target below binds cleanly in embedded mode.
    property var panelRoot: null

    // Embedded mode: drop the big title / item count / palette shortcut (keep
    // the logo tiles). Used by the Settings pane and the bottom Appearance
    // switcher, which provide their own surrounding chrome.
    property bool embedded: false
    // carouselHeight > 0 → fixed-height carousel (Settings pane); <= 0 → fill
    // the remaining vertical space (quick-switcher panels).
    property int  carouselHeight: 0

    property var wallpapers: []
    property string currentPath: ""
    property string currentLogo: ""    // "", "arch", "rebel", "imperial"

    readonly property string _assetsBase:
        Commons.Paths.config + "/archeotech/assets"

    // Raw SVG text; the data URIs below recompute reactively so the logo tint
    // tracks the theme's text color (was hardcoded dark-lavender → invisible on
    // light themes like Latte).
    property string _archSvgRaw: ""
    property string _rebelSvgRaw: ""
    property string _imperialSvgRaw: ""

    readonly property string _archSvg:     _svgDataUri(_archSvgRaw)
    readonly property string _rebelSvg:    _svgDataUri(_rebelSvgRaw)
    readonly property string _imperialSvg: _svgDataUri(_imperialSvgRaw)

    function _svgFor(id) {
        if (id === "arch")     return root._archSvg
        if (id === "rebel")    return root._rebelSvg
        if (id === "imperial") return root._imperialSvg
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

    FileView {
        path: root._assetsBase + "/arch-logo.svg"
        preload: true
        printErrors: false
        onTextChanged: root._archSvgRaw = text()
    }
    FileView {
        path: root._assetsBase + "/rebel-logo.svg"
        preload: true
        printErrors: false
        onTextChanged: root._rebelSvgRaw = text()
    }
    FileView {
        path: root._assetsBase + "/imperial-logo.svg"
        preload: true
        printErrors: false
        onTextChanged: root._imperialSvgRaw = text()
    }

    Component.onCompleted: _refresh()
    Connections {
        target: root.panelRoot
        ignoreUnknownSignals: true
        function onPanelOpenChanged() {
            if (root.panelRoot && root.panelRoot.panelOpen) root._refresh()
        }
    }

    function _refresh() {
        root.wallpapers = []
        if (!scanProc.running)      scanProc.running = true
        if (!currentReader.running) currentReader.running = true
        if (!logoReader.running)    logoReader.running = true
    }

    readonly property bool applying: applyProc.running || logoProc.running

    function _apply(path) {
        if (applying) return
        root.currentPath = path
        applyProc.command = [Commons.Paths.wallpaperSet, path]
        applyProc.running = true
    }
    function _applyLogo(id) {
        if (applying) return
        var toggleOff = (id === "" || id === root.currentLogo)
        root.currentLogo = toggleOff ? "" : id
        if (toggleOff)
            logoProc.command = [Commons.Paths.wallpaperSet, "--toggle-logo"]
        else
            logoProc.command = [Commons.Paths.wallpaperSet, "--toggle-logo", id]
        logoProc.running = true
        logoRefreshTimer.restart()
    }

    Process { id: applyProc; running: false }
    Process { id: logoProc;  running: false }
    Timer {
        id: logoRefreshTimer
        interval: 250
        onTriggered: { if (!logoReader.running) logoReader.running = true }
    }

    Process {
        id: scanProc
        running: false
        command: ["bash", "-lc",
            "find -L \"$HOME/.config/archeotech/wallpapers\" " +
            "-maxdepth 1 -type f -regextype posix-extended " +
            "-iregex '.*\\.(jpe?g|png|webp)$' | sort"]
        property var _buf: []
        onRunningChanged: if (running) _buf = []
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim()
                if (!p) return
                var slash = p.lastIndexOf("/")
                var dot   = p.lastIndexOf(".")
                var stem  = p.substring(slash + 1, dot >= 0 ? dot : p.length)
                var name  = stem.replace(/[_-]/g, " ")
                scanProc._buf = (scanProc._buf || []).concat([{ path: p, name: name }])
            }
        }
        onExited: root.wallpapers = scanProc._buf || []
    }

    Process {
        id: currentReader
        running: false
        command: ["bash", "-lc",
            "cat \"$HOME/.cache/wallpaper/last-wallpaper\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: line => { var t = line.trim(); if (t) root.currentPath = t }
        }
    }

    Process {
        id: logoReader
        running: false
        command: ["bash", "-lc",
            "cat \"$HOME/.cache/wallpaper/logo-active\" 2>/dev/null || true"]
        property string _buf: ""
        onRunningChanged: if (running) _buf = ""
        stdout: SplitParser { onRead: line => { logoReader._buf = line.trim() } }
        onExited: root.currentLogo = logoReader._buf
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.embedded ? 0 : Commons.Appearance.spacing.lg
        spacing: Commons.Appearance.spacing.md

        // Combined header — title (left), logo tiles (centered), count +
        // palette button (right). In embedded mode only the logo tiles remain.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            Text {
                visible: !root.embedded
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "󰸉  Wallpapers"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.family: Commons.Appearance.font.family
                font.weight: Font.Medium
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: root._logoOptions
                    delegate: Item {
                        id: logoChip
                        required property var modelData

                        readonly property bool _active:  root.currentLogo === modelData.id
                        property bool _hovered: false
                        readonly property string _svgData: root._svgFor(modelData.id)

                        width: 60; height: 60

                        Rectangle {
                            anchors.fill: parent
                            radius: Commons.Appearance.radius.md
                            color: logoChip._active
                                ? Commons.Appearance.colors.accentAlpha
                                : (logoChip._hovered ? Commons.Appearance.colors.surface0Alpha : "transparent")
                            border.width: logoChip._active ? 2 : 0
                            border.color: Commons.Appearance.colors.accent
                            scale: logoChip._hovered && !logoChip._active ? 1.05 : 1.0
                            Behavior on color       { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                            Behavior on border.width{ NumberAnimation { duration: Commons.Appearance.anim.fast } }
                            Behavior on scale       { NumberAnimation { duration: Commons.Appearance.anim.fast; easing.type: Easing.OutCubic } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 6
                                source: logoChip._svgData
                                sourceSize.width: 96; sourceSize.height: 96
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: logoChip._svgData !== ""
                                opacity: logoChip._active ? 1.0 : (logoChip._hovered ? 1.0 : 0.7)
                                Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: logoChip._svgData === ""
                                text: logoChip.modelData.glyph
                                color: logoChip._active
                                    ? Commons.Appearance.colors.accent
                                    : (logoChip._hovered ? Commons.Appearance.colors.subtext1 : Commons.Appearance.colors.overlay0)
                                font.pixelSize: 24
                                font.family: Commons.Appearance.font.family
                            }
                        }

                        Rectangle {
                            visible: logoChip._hovered
                            anchors.top: parent.bottom
                            anchors.topMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitWidth: _tipLabel.implicitWidth + 10
                            implicitHeight: _tipLabel.implicitHeight + 4
                            radius: Commons.Appearance.radius.sm
                            color: Commons.Appearance.colors.crust
                            z: 10
                            Text {
                                id: _tipLabel
                                anchors.centerIn: parent
                                text: logoChip.modelData.label
                                color: Commons.Appearance.colors.text
                                font.pixelSize: Commons.Appearance.font.sizeSm
                                font.family: Commons.Appearance.font.family
                            }
                        }

                        opacity: root.applying && !logoChip._active ? 0.45 : 1.0
                        Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.applying
                            cursorShape: root.applying ? Qt.BusyCursor : Qt.PointingHandCursor
                            onEntered: logoChip._hovered = true
                            onExited:  logoChip._hovered = false
                            onClicked: root._applyLogo(logoChip.modelData.id)
                        }
                    }
                }
            }

            Row {
                visible: !root.embedded
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: (root.wallpapers ? root.wallpapers.length : 0) + " items"
                    color: Commons.Appearance.colors.subtext0
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    id: paletteBtn
                    width: 28; height: 28
                    radius: 14
                    property bool _hovered: false
                    color: _hovered ? Commons.Appearance.colors.surface0Alpha : "transparent"
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰏘"
                        color: paletteBtn._hovered
                            ? Commons.Appearance.colors.accent
                            : Commons.Appearance.colors.subtext1
                        font.pixelSize: 16
                        font.family: Commons.Appearance.font.family
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: paletteBtn._hovered = true
                        onExited:  paletteBtn._hovered = false
                        onClicked: {
                            Commons.State.settingsOpenPane = "appearance"
                            ShellServices.ShellState.openGlobal("settings")
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Commons.Appearance.colors.surface0
            opacity: 0.5
        }

        ListView {
            id: grid
            Layout.fillWidth:  true
            Layout.fillHeight: root.carouselHeight <= 0
            Layout.preferredHeight: root.carouselHeight > 0 ? root.carouselHeight : -1
            clip: true
            orientation: ListView.Horizontal
            spacing: 12
            model: root.wallpapers
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

            readonly property real _aspect: 3 / 2
            readonly property int _cellH: Math.max(140, height - 14)
            readonly property int _cellW: Math.floor(_cellH * _aspect)

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    var step = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    grid.flick(step * 6, 0)
                    event.accepted = true
                }
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width:  grid._cellW
                height: grid._cellH

                readonly property bool _active:  root.currentPath === modelData.path
                property bool _hovered: false

                scale: cell._hovered && !cell._active && !root.applying ? 1.03 : 1.0
                Behavior on scale { NumberAnimation { duration: Commons.Appearance.anim.fast; easing.type: Easing.OutCubic } }

                opacity: root.applying && !cell._active ? 0.5 : 1.0
                Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                Image {
                    id: cellImg
                    anchors.fill: parent
                    source: cell.modelData ? "file://" + cell.modelData.path : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width:  grid._cellW * 2
                    sourceSize.height: grid._cellH * 2
                    visible: false
                }
                Rectangle {
                    id: cellMask
                    anchors.fill: parent
                    radius: 14
                    visible: false
                }
                OpacityMask {
                    anchors.fill: cellImg
                    source: cellImg
                    maskSource: cellMask
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: cell._active ? 2 : (cell._hovered ? 1 : 0)
                    border.color: cell._active
                        ? Commons.Appearance.colors.accent
                        : Commons.Appearance.colors.subtext0
                    Behavior on border.color { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                    Behavior on border.width { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                }

                Rectangle {
                    visible: cell._active
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    width: 24; height: 24; radius: 12
                    color: Commons.Appearance.colors.accent
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Commons.Appearance.colors.base
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.applying
                    cursorShape: root.applying ? Qt.BusyCursor : Qt.PointingHandCursor
                    onEntered: cell._hovered = true
                    onExited:  cell._hovered = false
                    onClicked: root._apply(cell.modelData.path)
                }
            }
        }
    }
}
