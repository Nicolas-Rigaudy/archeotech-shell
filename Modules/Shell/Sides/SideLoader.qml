import QtQuick
import "../../../Services/Shell" as ShellServices

// Picks a side's content based on shell-config.json:
//   "bar"    → Bar
//   "strip"  → Strip
//   "holder" → Strip in holderMode (hidden at rest, hover/shortcut reveal)
//   "none"   → nothing (Loader inactive)
//
// Hosted inside ShellSurface (Sprint 17 Stage 4) as a sibling Item, anchored
// to one side of the surface. Re-evaluates live when ShellConfig hot-reloads.
Loader {
    id: loader

    required property string side
    required property var screen

    readonly property string _screenName: screen ? screen.name : ""
    readonly property string _type: ShellServices.ShellConfig.sideType(side, _screenName)

    active: _type === "bar" || _type === "strip" || _type === "holder"
    sourceComponent: _type === "bar"                          ? _barComp
                   : (_type === "strip" || _type === "holder") ? _stripComp
                   : null

    Component {
        id: _barComp
        Bar {
            side: loader.side
            screen: loader.screen
        }
    }

    Component {
        id: _stripComp
        Strip {
            side: loader.side
            screen: loader.screen
            holderMode: loader._type === "holder"
        }
    }
}
