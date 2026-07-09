import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Media" as MediaServices
import "../../../Services/Persistence" as Persistence
import "../Widgets"

Item {
    id: root

    // Output row whose inline options (alias + volume cap) are expanded; "" = none.
    property string expandedSink: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰕾"
            title: "Audio"
            description: "Select the default output device and configure audio behaviour"
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Commons.Appearance.colors.surface0 }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: col.implicitHeight + 32
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: col
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 24; leftMargin: 24; rightMargin: 24 }
                width: root.width - 48
                spacing: 6

                SectionLabel { text: "OUTPUT DEVICE" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: sinksCol.implicitHeight

                    ColumnLayout {
                        id: sinksCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 }
                        spacing: 0

                        Item { implicitHeight: 6; Layout.fillWidth: true }

                        Text {
                            visible: MediaServices.Audio.sinks.length === 0
                            text: "No audio output devices found."
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: MediaServices.Audio.sinks
                            delegate: Item {
                                id: sinkDelegate
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 44 + (_expanded ? optsItem.implicitHeight : 0)
                                clip: true

                                readonly property bool isDefault: modelData.name === MediaServices.Audio.defaultSink
                                readonly property bool _expanded: root.expandedSink === modelData.name

                                Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1; color: Commons.Appearance.colors.base
                                }

                                // ── Main row ──────────────────────────────────
                                Rectangle {
                                    id: sinkRow
                                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: index > 0 ? 1 : 0 }
                                    height: 44
                                    radius: index === 0
                                        ? Commons.Appearance.radius.md
                                        : (index === MediaServices.Audio.sinks.length - 1 && !sinkDelegate._expanded ? Commons.Appearance.radius.md : 0)
                                    color: isDefault
                                        ? Commons.Appearance.colors.accentAlpha
                                        : (sinkMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent")
                                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                        spacing: 10

                                        Text {
                                            text: isDefault ? "󰕾" : "󰖁"
                                            color: isDefault ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                                            font.pixelSize: 16; font.family: Commons.Appearance.font.family
                                            Layout.alignment: Qt.AlignVCenter
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        }

                                        Text {
                                            text: MediaServices.Audio.aliasFor(modelData.name) || modelData.description || modelData.name
                                            color: isDefault ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            font.family: Commons.Appearance.font.family
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        }

                                        Text {
                                            visible: isDefault
                                            text: "default"
                                            color: Commons.Appearance.colors.accent
                                            font.pixelSize: Commons.Appearance.font.sizeSm
                                            font.family: Commons.Appearance.font.family
                                        }

                                        // Expand toggle (options for this device)
                                        Rectangle {
                                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: Commons.Appearance.radius.sm
                                            color: gearMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent"
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰢻"
                                                rotation: sinkDelegate._expanded ? 90 : 0
                                                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                color: sinkDelegate._expanded ? Commons.Appearance.colors.accent
                                                     : (gearMa.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0)
                                                font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                            }
                                            MouseArea {
                                                id: gearMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.expandedSink = sinkDelegate._expanded ? "" : sinkDelegate.modelData.name
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: sinkMa
                                        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 40 }
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (!isDefault) MediaServices.Audio.setDefaultSink(modelData.name)
                                    }
                                }

                                // ── Inline options (alias + volume cap) ─────────
                                Item {
                                    id: optsItem
                                    anchors { left: parent.left; right: parent.right; top: sinkRow.bottom }
                                    visible: sinkDelegate._expanded
                                    implicitHeight: optsCol.implicitHeight + 12

                                    ColumnLayout {
                                        id: optsCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 26; rightMargin: 8; topMargin: 2 }
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Text {
                                                text: "Name"
                                                color: Commons.Appearance.colors.subtext0
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                                font.family: Commons.Appearance.font.family
                                                Layout.preferredWidth: 64
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                radius: Commons.Appearance.radius.sm
                                                color: Commons.Appearance.colors.base
                                                border.color: aliasField.activeFocus ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.surface1
                                                border.width: 1
                                                TextField {
                                                    id: aliasField
                                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: MediaServices.Audio.aliasFor(sinkDelegate.modelData.name)
                                                    placeholderText: sinkDelegate.modelData.description || sinkDelegate.modelData.name
                                                    color: Commons.Appearance.colors.text
                                                    placeholderTextColor: Commons.Appearance.colors.overlay0
                                                    font.pixelSize: Commons.Appearance.font.sizeSm
                                                    font.family: Commons.Appearance.font.family
                                                    background: null
                                                    onEditingFinished: MediaServices.Audio.setAlias(sinkDelegate.modelData.name, text)
                                                }
                                            }
                                        }

                                        SliderRow {
                                            label: "Max volume"
                                            from: 20; to: 100; stepSize: 5
                                            value: MediaServices.Audio.volumeLimitFor(sinkDelegate.modelData.name)
                                            valueDisplay: Math.round(value) + "%"
                                            onMoved: v => MediaServices.Audio.setVolumeLimit(sinkDelegate.modelData.name, v)
                                        }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 6; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "INPUT DEVICE" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: sourcesCol.implicitHeight

                    ColumnLayout {
                        id: sourcesCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 }
                        spacing: 0

                        Item { implicitHeight: 6; Layout.fillWidth: true }

                        Text {
                            visible: MediaServices.Audio.sources.length === 0
                            text: "No audio input devices found."
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: MediaServices.Audio.sources
                            delegate: Item {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 44

                                readonly property bool isDefault: modelData.name === MediaServices.Audio.defaultSource

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1; color: Commons.Appearance.colors.base
                                }

                                Rectangle {
                                    anchors { fill: parent; topMargin: index > 0 ? 1 : 0 }
                                    radius: index === 0
                                        ? Commons.Appearance.radius.md
                                        : (index === MediaServices.Audio.sources.length - 1 ? Commons.Appearance.radius.md : 0)
                                    color: isDefault
                                        ? Commons.Appearance.colors.accentAlpha
                                        : (sourceMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent")
                                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                        spacing: 10

                                        Text {
                                            text: isDefault ? "󰍬" : "󰍭"
                                            color: isDefault ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                                            font.pixelSize: 16; font.family: Commons.Appearance.font.family
                                            Layout.alignment: Qt.AlignVCenter
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        }

                                        Text {
                                            text: MediaServices.Audio.aliasFor(modelData.name) || modelData.description || modelData.name
                                            color: isDefault ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            font.family: Commons.Appearance.font.family
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        }

                                        Text {
                                            visible: isDefault
                                            text: "default"
                                            color: Commons.Appearance.colors.accent
                                            font.pixelSize: Commons.Appearance.font.sizeSm
                                            font.family: Commons.Appearance.font.family
                                        }
                                    }

                                    MouseArea {
                                        id: sourceMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (!isDefault) MediaServices.Audio.setDefaultSource(modelData.name)
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 6; Layout.fillWidth: true }
                    }
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
                SectionLabel { text: "BEHAVIOUR" }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: behavCol.implicitHeight

                    ColumnLayout {
                        id: behavCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                        spacing: 0
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                        ToggleRow {
                            label: "Remember volume on restart"
                            description: "Restore last volume level on login"
                            checked: Persistence.Config.get("audio.rememberVolume", true)
                            onToggled: value => Persistence.Config.set("audio.rememberVolume", value)
                        }
                        Item { implicitHeight: 4; Layout.fillWidth: true }
                    }
                }
            }
        }
    }

}
