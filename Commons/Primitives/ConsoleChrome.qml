import QtQuick
import ".." as Commons

// Console hardware drawn over a popup or panel card where it fastens to the bar
// or strip (trim, corner gussets, a collar on the attach edge). Core has no
// visual of its own: a pack draws it with a `ConsoleChrome` style delegate
// (Grimdark's bolted copper console), so without one this is an empty Loader.
// Drop into a card with `anchors.fill: parent`, above its fill; decorative only
// (no MouseArea, never eats hover).
StyleDelegate {
    id: chrome
    componentId: "ConsoleChrome"

    // Edge that fastens to the bar/strip (gets the collar).
    property string attachSide: "bottom"        // "top" | "bottom" | "left" | "right"
    property real   radius: 3
    property bool   showCollar:  true           // collar on the attach edge
    property bool   showTrim:    true           // edge trim (off when the host draws its own outline)
    property bool   showGussets: true           // corner brackets (off for small popups)
    property real   inset: 2                    // trim inset from the card edge

    api: ({
        "attachSide":  chrome.attachSide,
        "radius":      chrome.radius,
        "showCollar":  chrome.showCollar,
        "showTrim":    chrome.showTrim,
        "showGussets": chrome.showGussets,
        "inset":       chrome.inset,
        "specular":    Commons.Appearance.opacity.specular,
        "palette":     Commons.Appearance.colors,
        "steel":       Commons.Appearance.steel
    })
}
