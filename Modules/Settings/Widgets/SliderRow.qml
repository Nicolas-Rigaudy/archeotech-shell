import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Commons" as Commons

Item {
    id: root
    property string label: ""
    property string description: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property string valueDisplay: Math.round(value * 100) + "%"
    signal moved(real value)

    implicitHeight: description ? 80 : 62
    Layout.fillWidth: true

    ColumnLayout {
        anchors { fill: parent; topMargin: 8; bottomMargin: 8 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                color: Commons.Appearance.colors.text
                font.pixelSize: Commons.Appearance.font.sizeBase
                font.family: Commons.Appearance.font.family
                Layout.fillWidth: true
            }

            Text {
                text: root.valueDisplay
                color: Commons.Appearance.colors.subtext1
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
            }
        }

        Text {
            visible: root.description !== ""
            text: root.description
            color: Commons.Appearance.colors.overlay0
            font.pixelSize: Commons.Appearance.font.sizeSm
            font.family: Commons.Appearance.font.family
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            padding: 0

            background: Rectangle {
                x: 0
                y: (slider.height - height) / 2
                width: slider.availableWidth
                height: 8
                radius: 4
                // Sunk/recessed track + top-lit sheen fill — same language as the
                // dashboard stat bars for a consistent 3d feel.
                color: Commons.Appearance.colors.recessedTrack

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Commons.Appearance.sheenHi(Commons.Appearance.colors.accent, 1.18) }
                        GradientStop { position: 1.0; color: Commons.Appearance.sheenLo(Commons.Appearance.colors.accent, 1.12) }
                    }
                }
            }

            handle: Rectangle {
                id: knob
                x: slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 20; height: 20; radius: 10
                color: (slider.pressed || slider.hovered) ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext1
                scale: slider.pressed ? 0.92 : slider.hovered ? 1.08 : 1.0
                // Raised 3d read: a darker edge + a top-lit gloss overlay, the same
                // top-to-bottom sheen language as the track fill above. Depth cues
                // drop in flat mode (depthFlat) — knob becomes a plain flat dot.
                border.width: Commons.Appearance.depthFlat ? 0 : 1
                border.color: Commons.Appearance.sheenLo(knob.color, 1.3)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: !Commons.Appearance.depthFlat
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.28) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }
                Behavior on color { Commons.ColorAnim {} }
                Behavior on scale { Commons.Anim { curve: Commons.Appearance.curve.expressiveDefaultSpatial } }
            }

            onMoved: root.moved(value)
        }
    }
}
