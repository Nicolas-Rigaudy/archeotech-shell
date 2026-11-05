import QtQuick
import QtQuick.Effects
import ".." as Commons

// Segmented control — the shell's pick-one-of-N control (page selectors, mode
// toggles). N equal segments sit in one recessed track (sunk rgba language,
// like the SliderRow / stat bars); a raised accent pill slides to the selected
// segment with a top-lit gradient + lift shadow (gated on shadowStrength so it
// flattens in flat mode). Inactive segments take a StateLayer hover wash; the
// active label/glyph flips to `base` (dark) over the accent, matching the
// shell's "accent fill + base glyph" focal language.
//
// model items are { label, glyph } (either may be omitted). Bind `currentIndex`
// to your own state and update it in `onActivated` — the control is stateless.
// `iconOnly` collapses to glyphs for narrow side panels.
Item {
    id: root

    property var  model: []
    property int  currentIndex: 0
    property bool iconOnly: false
    // Opt-in vertical stack (segments top→bottom, pill slides in y) for narrow
    // side panels; horizontal (default) is unchanged.
    property bool vertical: false
    signal activated(int index)

    readonly property bool _v: root.vertical

    // Keyboard: Tab focuses (ring below); Left/Right (Up/Down when vertical) step the
    // selection. The control is stateless, so stepping only emits `activated`.
    // `enabled: false` dims it and ignores input.
    activeFocusOnTab: enabled
    opacity: enabled ? 1.0 : Commons.Appearance.disabledOpacity
    function _step(d) {
        var n = root.currentIndex + d
        if (n >= 0 && n < root.model.length) root.activated(n)
    }
    Keys.onLeftPressed:  if (enabled && !_v) _step(-1)
    Keys.onRightPressed: if (enabled && !_v) _step(1)
    Keys.onUpPressed:    if (enabled && _v)  _step(-1)
    Keys.onDownPressed:  if (enabled && _v)  _step(1)
    implicitHeight: _v ? 30 * Math.max(1, model.length) : 30

    // Track + key look from the pack's `surfaces.selector` recipe (Grimdark: a
    // recessed machined slot with a square-cut steel key and a lit-copper edge;
    // base packs: the soft sunk track and the accent pill).
    readonly property var _rec: Commons.Appearance.selectorSurface
    function _col(c) { return Commons.Appearance._surfaceColor(c) }

    // Pack style seam (item_156): a `SegmentedControl` delegate draws the track
    // and key itself from api.keyRect (the animated key position); the base
    // track/seat/shadow/key visuals step aside. Labels stay here, coloured by the
    // delegate's optional `activeText` / `idleText`.
    readonly property bool _styled: _style.active
    property int _hovIndex: -1
    function _labelCol(on) {
        const c = root._styled ? (on ? _style.item.activeText : _style.item.idleText) : undefined
        if (c !== undefined && c !== null && c !== "") return c
        return on ? root._col(root._rec.keyText) : Commons.Appearance.colors.textSecondary
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root._rec.trackRadius >= 0 ? root._rec.trackRadius : Commons.Appearance.radius.base
        color: root._styled ? "transparent" : root._col(root._rec.trackColor)
        border.width: root._styled ? 0 : root._rec.trackBorderWidth
        border.color: root._col(root._rec.trackBorderColor)
        readonly property real _segW: root.model.length > 0 ? (root._v ? height : width) / root.model.length : (root._v ? height : width)

        // top inner shadow line → reads as recessed into the plate (not a flat box)
        Rectangle {
            visible: root._rec.innerShadow && !root._styled
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 2; rightMargin: 2; topMargin: 1 }
            height: 1; color: Qt.rgba(0, 0, 0, 0.55)
        }

        RectangularShadow {                 // soft drop shadow under the key
            anchors.fill: pill
            visible: root.model.length > 0 && root._rec.keyShadow === "soft" && !root._styled
            radius: pill.radius
            blur:   Commons.Appearance.elevation.e2.blur
            offset: Qt.vector2d(0, Commons.Appearance.elevation.e2.y)
            spread: Commons.Appearance.elevation.e2.spread
            color:  Commons.Appearance.elevation.e2.color
        }
        Rectangle {                         // hard seat under the key: machined depth, not a soft glow
            visible: root.model.length > 0 && root._rec.keyShadow === "seat" && !root._styled
            x: pill.x; y: pill.y + 1.5; width: pill.width; height: pill.height
            radius: pill.radius; color: root._col(root._rec.seatColor)
        }
        Rectangle {
            id: pill
            visible: root.model.length > 0
            // Styled: keep the key's animated geometry (api.keyRect) but not its paint.
            opacity: root._styled ? 0 : 1
            width:  root._v ? track.width - 8 : track._segW - 8
            height: root._v ? track._segW - 8 : track.height - 8
            x: root._v ? 4 : root.currentIndex * track._segW + 4
            y: root._v ? root.currentIndex * track._segW + 4 : 4
            radius: root._rec.keyRadius >= 0 ? root._rec.keyRadius : track.radius - 3
            border.width: root._rec.keyBorderWidth
            border.color: root._col(root._rec.keyBorderColor)
            readonly property var _stops: root._rec.keyStops
            readonly property bool _sheen: _stops.length < 3
            gradient: Gradient {
                GradientStop { position: pill._sheen ? 0.0 : pill._stops[0][0]
                               color: pill._sheen ? Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.hi)
                                                  : root._col(pill._stops[0][1]) }
                GradientStop { position: pill._sheen ? 0.5 : pill._stops[1][0]
                               color: pill._sheen ? Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.hi)
                                                  : root._col(pill._stops[1][1]) }
                GradientStop { position: pill._sheen ? 1.0 : pill._stops[2][0]
                               color: pill._sheen ? Commons.Appearance.sheenLo(Commons.Appearance.colors.accent, Commons.Appearance.sheen.control.lo)
                                                  : root._col(pill._stops[2][1]) }
            }
            Behavior on x { Commons.Tween { spatial: true; time: Commons.Appearance.anim.base } }
            Behavior on y { Commons.Tween { spatial: true; time: Commons.Appearance.anim.base } }
        }

        StyleDelegate {
            id: _style
            anchors.fill: parent
            componentId: "SegmentedControl"
            // Built only when a pack ships the style: keyRect follows the pill's
            // animation, so an ungated object would rebuild every frame for nothing.
            api: !Commons.Appearance.hasStyle("SegmentedControl") ? ({}) : ({
                "count":        root.model.length,
                "currentIndex": root.currentIndex,
                "hoveredIndex": root._hovIndex,
                "vertical":     root._v,
                "segmentSize":  track._segW,
                "keyRect":      Qt.rect(pill.x, pill.y, pill.width, pill.height),
                "enabled":      root.enabled,
                "radius":       track.radius,
                "palette":      Commons.Appearance.colors
            })
        }

        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool _on: root.currentIndex === index
                property bool _hov: false
                x: root._v ? 0 : index * track._segW
                y: root._v ? index * track._segW : 0
                width:  root._v ? track.width : track._segW
                height: root._v ? track._segW : track.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Commons.Appearance.spacing.s1
                    radius: track.radius - 3
                    color: (seg._hov && !seg._on && !root._styled) ? Commons.Appearance.colors.stateHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Commons.Appearance.spacing.s2
                    Text {
                        visible: !!seg.modelData.glyph
                        text: seg.modelData.glyph || ""
                        color: root._labelCol(seg._on)
                        font.pixelSize: Commons.Appearance.font.sizeLg; font.family: Commons.Appearance.font.family
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                    Text {
                        visible: !root.iconOnly && !!seg.modelData.label
                        text: seg.modelData.label || ""
                        color: root._labelCol(seg._on)
                        font.pixelSize: Commons.Appearance.font.sizeBase
                        font.family: Commons.Appearance.font.family
                        font.weight: seg._on ? Commons.Appearance.font.weightMedium : Commons.Appearance.font.weightRegular
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { seg._hov = true; root._hovIndex = seg.index }
                    onExited:  { seg._hov = false; if (root._hovIndex === seg.index) root._hovIndex = -1 }
                    onClicked: root.activated(seg.index)
                }
            }
        }
    }

    FocusRing { shown: root.activeFocus; cornerRadius: track.radius }
}
