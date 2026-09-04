import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../../Commons" as Commons
import "../../Services/Shell" as ShellServices
import "../../Services/Theming" as Theming

// Wallpaper selection carousel (Sprint 24). Hosted by the quick-switcher
// WallpaperPicker panel (as a tab) and the Settings → Appearance pane
// (embedded: true — no title/count/palette button, fixed carousel height).
// The logo picker moved to its own LogoCarousel (Sprint 26). Apply goes
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

    // Embedded mode: drop the big title / item count / palette shortcut. Used
    // by the Settings pane and the quick-switcher tab, which provide their own
    // surrounding chrome.
    property bool embedded: false
    // carouselHeight > 0 → fixed-height carousel (Settings pane); <= 0 → fill
    // the remaining vertical space (quick-switcher panels).
    property int  carouselHeight: 0
    // vertical: lay the carousel top→bottom for left/right panels (the quick
    // switcher passes !panelRoot._horizontal). Settings leaves it horizontal.
    property bool vertical: false

    // Wallpaper list comes from the persistent Wallpapers service — scanned once
    // at startup and held, so opening the picker is instant (no re-scan/rebuild).
    readonly property var wallpapers: Theming.Wallpapers.list
    property string currentPath: ""

    Component.onCompleted: _refresh()
    Connections {
        target: root.panelRoot
        ignoreUnknownSignals: true
        function onPanelOpenChanged() {
            if (root.panelRoot && root.panelRoot.panelOpen) root._refresh()
        }
    }

    // The wallpaper list + thumbnail cache live in the Wallpapers service now.
    // On open we only refresh the cheap selection state (current wallpaper) —
    // the grid is already populated, so it stays instant.
    function _refresh() {
        if (!currentReader.running) currentReader.running = true
    }

    readonly property bool applying: applyProc.running

    function _apply(path) {
        if (applying) return
        root.currentPath = path
        applyProc.command = [Commons.Paths.wallpaperSet, path]
        applyProc.running = true
    }

    Process { id: applyProc; running: false }

    Process {
        id: currentReader
        running: false
        command: ["bash", "-c",
            "cat \"$HOME/.cache/wallpaper/last-wallpaper\" 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: line => { var t = line.trim(); if (t) root.currentPath = t }
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.embedded ? 0 : Commons.Appearance.spacing.lg
        spacing: Commons.Appearance.spacing.md

        // Header — title (left) + count / palette shortcut (right). Dropped in
        // embedded mode: the quick panel and Settings provide their own chrome.
        Item {
            visible: !root.embedded
            Layout.fillWidth: true
            Layout.preferredHeight: root.embedded ? 0 : 64

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "󰸉  Wallpapers"
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeLg
                font.family: Commons.Appearance.font.family
                font.weight: Font.Medium
            }

            Row {
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
                    color: _hovered ? Commons.Appearance.colors.surfaceRaised : "transparent"
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
            visible: !root.embedded
            Layout.fillWidth: true
            Layout.preferredHeight: root.embedded ? 0 : 1
            color: Commons.Appearance.colors.surface0
            opacity: 0.5
        }

        // Wallpaper carousel — snap-to-centre; the centred item is the large
        // "preview", scrolling brings others to centre (no apply), clicking
        // applies. Only ~4 delegates are built, so it opens instantly.
        Carousel {
            id: grid
            Layout.fillWidth:  true
            Layout.fillHeight: root.carouselHeight <= 0
            Layout.preferredHeight: root.carouselHeight > 0 ? root.carouselHeight : 200
            model: root.wallpapers
            vertical: root.vertical
            // Tile cross-axis extent (drives both spacing and the delegate size,
            // so they can't diverge). Vertically the tiles STACK, so cap the cross
            // by the panel height too (·0.5 → along-track tile ≈ height/3): that
            // lets ~3 thumbnails fit instead of one big tile crowding the others
            // out of a short side panel. Horizontally it's the old height-derived
            // width. Landscape 3:2 either way.
            readonly property int _tileCross: root.vertical
                ? Math.min(grid.width - 24, 300, Math.floor(grid.height * 0.5))
                : Math.min(grid.height - 24, 190)
            // 0.95 (matches horizontal) → a real gap between tiles, not overlap.
            // Safe against bleed because _tileCross is height-capped above.
            itemSpacing: root.vertical
                ? Math.floor(_tileCross * 2 / 3 * 0.95)
                : Math.floor(_tileCross * 3 / 2 * 0.95)

            // Start centred on the applied wallpaper. The current path is read
            // asynchronously (currentReader), so it usually lands AFTER these two
            // fire — re-centre when it does, else the picker opens on item 0
            // instead of the active wallpaper. (Theme/Logo carousels do the same.)
            onModelChanged: _syncCurrent()
            Component.onCompleted: _syncCurrent()
            Connections {
                target: root
                function onCurrentPathChanged() { grid._syncCurrent() }
            }
            function _syncCurrent() {
                var i = root.wallpapers.findIndex(function(w) { return w.path === root.currentPath })
                // StrictlyEnforceRange + highlight 0.5 auto-centres currentIndex.
                if (i >= 0) currentIndex = i
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index

                readonly property bool _current: PathView.isCurrentItem
                readonly property bool _active:  root.currentPath === modelData.path
                // Size from the shared cross extent (capped by height in vertical
                // so thumbnails stack). Landscape 3:2 either way.
                readonly property int  _cross: grid._tileCross
                readonly property int  _w: root.vertical ? _cross : Math.floor(_cross * 3 / 2)
                readonly property int  _h: root.vertical ? Math.floor(_cross * 2 / 3) : _cross

                width:  _w
                height: _h
                z: _current ? 2 : 1

                // Centre item full-size + opaque; neighbours shrink + dim.
                scale:   _current ? 1.0 : 0.72
                opacity: root.applying ? (_active ? 1.0 : 0.4) : (_current ? 1.0 : 0.6)
                Behavior on scale   { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Commons.Appearance.anim.base; easing.type: Easing.OutCubic } }

                // Soft cast shadow UNDER the hero (centred) item only — lifts it
                // off the panel. Sibling behind the image (never on the thumbnail
                // itself), radius-matched to the rounded photo. Side thumbnails
                // stay flat. Gated on shadowStrength so flat mode drops it.
                RectangularShadow {
                    anchors.fill: parent
                    visible: cell._current
                    radius: Commons.Appearance.radius.lg
                    blur:   32
                    offset: Qt.vector2d(0, 12)
                    spread: 2
                    color:  Qt.rgba(0, 0, 0, 0.55 * Commons.Appearance.shadowStrength)
                }

                Image {
                    id: cellImg
                    anchors.fill: parent
                    // Prefer the cached thumbnail; fall back to the full image
                    // until it's generated, then swap in (Wallpapers.thumbGen
                    // bumps when generation finishes → retry the thumb).
                    property bool _useThumb: true
                    property int  _gen: Theming.Wallpapers.thumbGen
                    on_GenChanged: _useThumb = true
                    source: cell.modelData
                        ? "file://" + ((_useThumb && cell.modelData.thumb) ? cell.modelData.thumb : cell.modelData.path)
                        : ""
                    onStatusChanged: if (status === Image.Error && _useThumb) _useThumb = false
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width:  cell._w * 2
                    sourceSize.height: cell._h * 2
                    visible: false
                }
                Rectangle {
                    id: cellMask
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.lg
                    visible: false
                }
                OpacityMask {
                    anchors.fill: cellImg
                    source: cellImg
                    maskSource: cellMask
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.lg
                    antialiasing: true
                    color: "transparent"
                    border.width: cell._active ? 3 : (cell._current ? 2 : 0)
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
                    enabled: !root.applying
                    cursorShape: root.applying ? Qt.BusyCursor : Qt.PointingHandCursor
                    // Click a side item → bring it to centre (preview); click the
                    // centred item → apply it. Matches "preview on scroll, apply
                    // on click" without ever running the heavy script while browsing.
                    onClicked: {
                        if (cell._current) root._apply(cell.modelData.path)
                        else grid.currentIndex = cell.index
                    }
                }
            }
        }
    }
}
