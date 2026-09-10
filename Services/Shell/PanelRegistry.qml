pragma Singleton
import QtQuick
import "../../Modules/Shell/Panels/Content" as Content

// Sprint 17 Stage 5 — registry mapping panelId → { content, side, size, axisSize }.
//   size      — perpendicular dim (away from the strip).
//   axisSize  — along-strip dim. Numeric (px), "auto" (panel reports
//               implicitAxis), or "full" (legacy: occupy entire screen edge).
// Sprint 20 added axisSize so panels can be compact popups instead of
// always growing to the full screen axis. All panels start "full" and are
// migrated to numeric/auto one at a time.
QtObject {
    id: root

    readonly property var panels: ({
        nc: {
            content:  _ncComp,
            side:     "right",
            size:     320,
            axisSize: "auto"
        },
        settings: {
            content:  _settingsComp,
            side:     "right",
            size:     940,
            axisSize: 880
        },
        launcher: {
            content:  _launcherComp,
            side:     "left",
            size:     600,
            axisSize: 440
        },
        dashboard: {
            content:  _dashboardComp,
            side:     "bottom",
            size:     600,
            axisSize: 1000
        },
        media: {
            content:  _mediaComp,
            side:     "bottom",
            // Tall enough that the playback controls (raised play-circle + shadow)
            // clear the strip's icon row (item_038) AND the face page-dots row below
            // the player (task_030) instead of clipping into either.
            size:     272,
            axisSize: "auto"
        },
        wallpaper: {
            content:  _wallpaperComp,
            side:     "bottom",
            // Tall enough that the theme tab (mode + flavor + accent + carousel)
            // fits above the strip's icon row without overflowing onto the bar.
            size:     380,
            axisSize: "auto"   // follows WallpaperPicker.implicitAxis per side
        },
        layout: {
            content:  _layoutComp,
            side:     "bottom",
            size:     580,      // fits all 3 rows of the 14 layout cards + header
            axisSize: "auto"    // follows LayoutPicker.implicitAxis per side
        }
    })

    readonly property var panelIds: Object.keys(panels)

    function panelFor(id) {
        return panels[id]
    }

    // Stage 5 commit-1 placeholder. Each subsequent commit replaces one
    // entry's `content` with an extracted Content/*.qml component.
    property Component _placeholderComp: Component {
        Item {
            property var panelRoot
            Text {
                anchors.centerIn: parent
                text: "(panel content TODO)"
                color: "#cad3f5"
                font.pixelSize: 14
                font.family: "FiraCode Nerd Font"
            }
        }
    }

    // Extracted panel content components — one per migrated panel.
    property Component _ncComp:        Component { Content.NotificationCenter {} }
    property Component _launcherComp:  Component { Content.Launcher           {} }
    property Component _dashboardComp: Component { Content.Dashboard          {} }
    property Component _mediaComp:     Component { Content.MediaPanel          {} }
    property Component _wallpaperComp: Component { Content.WallpaperPicker     {} }
    property Component _settingsComp:  Component { Content.SettingsPanel       {} }
    property Component _layoutComp:    Component { Content.LayoutPicker        {} }
}
