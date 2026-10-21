import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "../../Commons" as Commons
import "../../Commons/Primitives" as Prim
import "../../Services/Theming" as Theming

// Per-mode wallpaper slots (item_140): a Light and a Dark card showing the
// wallpaper each mode uses. The selected card is the one the wallpaper carousel
// below fills (bind its `slot` to `selected`); the current mode's card is marked
// "Now", and only a pick for that card is applied straight away.
RowLayout {
    id: root
    spacing: Commons.Appearance.spacing.s3

    // "" follows the current mode (the selected card moves when the theme
    // flips) until a card is clicked.
    property string chosenSlot: ""
    readonly property string selected: chosenSlot || Theming.Wallpapers.mode

    readonly property var _slots: [
        { id: "light", label: "Light", glyph: "󰖙" },
        { id: "dark",  label: "Dark",  glyph: "󰖔" }
    ]

    function _thumb(path) {
        var l = Theming.Wallpapers.list
        for (var i = 0; i < l.length; i++) if (l[i].path === path) return l[i].thumb
        return path
    }

    Repeater {
        model: root._slots

        ColumnLayout {
            id: slot
            required property var modelData
            readonly property bool _selected: root.selected === slot.modelData.id
            readonly property bool _now: Theming.Wallpapers.mode === slot.modelData.id
            // An empty slot of the current mode shows what is on screen (it keeps it).
            readonly property string _path: Theming.Wallpapers.markedPath(slot.modelData.id)
            readonly property bool _unset: Theming.Wallpapers.slotPath(slot.modelData.id) === ""
            spacing: Commons.Appearance.spacing.s2
            // The label row fills its width; keep that from widening the card.
            Layout.fillWidth: false
            Layout.preferredWidth: 180

            Item {
                id: frame
                Layout.preferredWidth: 180
                Layout.preferredHeight: 108
                Behavior on scale { Commons.Tween { spatial: true; time: Commons.Appearance.anim.fast } }

                RectangularShadow {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.lg
                    blur:   Commons.Appearance.elevation.e2.blur
                    offset: Qt.vector2d(0, Commons.Appearance.elevation.e2.y)
                    spread: Commons.Appearance.elevation.e2.spread
                    color:  Commons.Appearance.elevation.e2.color
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.lg
                    color: Commons.Appearance.colors.surface0
                }
                Image {
                    id: img
                    anchors.fill: parent
                    // Thumb first; the full image if the thumb is not there yet.
                    property bool _useThumb: true
                    property int  _gen: Theming.Wallpapers.thumbGen
                    on_GenChanged: _useThumb = true
                    readonly property string _src: img._useThumb ? root._thumb(slot._path) : slot._path
                    source: slot._path ? "file://" + _src : ""
                    onStatusChanged: if (status === Image.Error && _useThumb) _useThumb = false
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 360
                    sourceSize.height: 216
                    visible: false
                }
                Rectangle { id: mask; anchors.fill: parent; radius: Commons.Appearance.radius.lg; visible: false }
                OpacityMask { anchors.fill: img; source: img; maskSource: mask; visible: slot._path !== "" }

                // Mode glyph on a chip, so it reads on any wallpaper.
                Rectangle {
                    anchors { left: parent.left; top: parent.top; margins: Commons.Appearance.spacing.s2 }
                    width: 26; height: 26; radius: width / 2
                    color: Commons.Appearance.colors.glassBg
                    border.width: 1
                    border.color: Commons.Appearance.colors.glassBorder
                    Text {
                        anchors.centerIn: parent
                        text: slot.modelData.glyph
                        color: Commons.Appearance.colors.textPrimary
                        font.pixelSize: Commons.Appearance.font.sizeMd
                        font.family: Commons.Appearance.font.family
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.lg
                    antialiasing: true
                    color: "transparent"
                    border.width: slot._selected ? 3 : 1
                    border.color: slot._selected ? Commons.Appearance.colors.accent : Commons.Appearance.colors.glassBorder
                    Behavior on border.color { ColorAnimation  { duration: Commons.Appearance.anim.fast } }
                }

                Prim.StateLayer {
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.lg
                    scaleTarget: frame
                    onClicked: root.chosenSlot = slot.modelData.id
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Commons.Appearance.spacing.s2
                Text {
                    text: slot.modelData.label
                    color: slot._selected ? Commons.Appearance.colors.accent : Commons.Appearance.colors.textPrimary
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                    font.weight: Commons.Appearance.font.weightMedium
                }
                // The mode the theme is in now: its card is the one on screen.
                Text {
                    visible: slot._now || slot._unset
                    text: [slot._now ? "· Now" : "", slot._unset ? "· not set" : ""].filter(t => t).join(" ")
                    color: Commons.Appearance.colors.textMuted
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                }
            }
        }
    }

    Item { Layout.fillWidth: true }
}
