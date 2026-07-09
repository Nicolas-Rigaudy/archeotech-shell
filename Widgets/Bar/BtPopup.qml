import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../Commons" as Commons
import "../../Services/Networking" as NetworkServices

// Bluetooth popup — adapter toggle, paired device list, connect/disconnect.
Shape {
    id: card
    required property var holderRoot

    property real _r:  Commons.Appearance.radius.xl
    property real _rb: Commons.Appearance.radius.md
    property real _bw: 240

    x: Math.min(
           Math.max((holderRoot ? holderRoot._btAnchorX : 0) - width / 2,
                    Commons.Appearance.bar.marginSide + 4),
           (holderRoot ? holderRoot.width : 0) - width - Commons.Appearance.bar.marginSide - 4)
    y: Commons.Appearance.bar.marginTop + Commons.Appearance.bar.height
    width:  _bw + _r * 2
    height: _btContent.implicitHeight + 20

    layer.enabled: true
    layer.samples: 8
    transformOrigin: Item.Top
    scale:   (holderRoot && holderRoot._btPopupVisible) ? 1.0 : 0.85
    opacity: (holderRoot && holderRoot._btPopupVisible) ? 1.0 : 0.0
    visible: holderRoot && holderRoot.side === "top" && opacity > 0.01
    Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    ShapePath {
        fillColor: Commons.Appearance.colors.glassBgLight
        strokeWidth: 0; strokeColor: "transparent"
        startX: 0; startY: 0
        PathLine { x: card._bw + card._r * 2; y: 0 }
        PathArc  { x: card._bw + card._r;     y: card._r
                   radiusX: card._r; radiusY: card._r; direction: PathArc.Counterclockwise }
        PathLine { x: card._bw + card._r;     y: card.height - card._rb }
        PathArc  { x: card._bw + card._r - card._rb; y: card.height
                   radiusX: card._rb; radiusY: card._rb; direction: PathArc.Clockwise }
        PathLine { x: card._r + card._rb;     y: card.height }
        PathArc  { x: card._r;                y: card.height - card._rb
                   radiusX: card._rb; radiusY: card._rb; direction: PathArc.Clockwise }
        PathLine { x: card._r;                y: card._r }
        PathArc  { x: 0;                      y: 0
                   radiusX: card._r; radiusY: card._r; direction: PathArc.Counterclockwise }
        PathLine { x: 0; y: 0 }
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true
        onEntered: if (card.holderRoot) card.holderRoot.keepPopupsAlive()
    }

    Column {
        id: _btContent
        x: card._r + 12; y: 10
        width: card._bw - 24
        spacing: 0

        Item {
            width: parent.width; height: 40
            RowLayout {
                anchors.fill: parent; spacing: 8
                Rectangle {
                    width: 28; height: 28; radius: Commons.Appearance.radius.base
                    color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.mauve : Commons.Appearance.colors.surface0
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    Text {
                        anchors.centerIn: parent
                        text: NetworkServices.Bluetooth.icon()
                        color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                        font.pixelSize: 13; font.family: Commons.Appearance.font.family
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NetworkServices.Bluetooth.toggle() }
                }
                Text {
                    text: "Bluetooth"
                    color: Commons.Appearance.colors.text
                    font.pixelSize: Commons.Appearance.font.sizeMd; font.family: Commons.Appearance.font.family
                    font.weight: Font.Medium; Layout.fillWidth: true
                }
                Text {
                    text: !NetworkServices.Bluetooth.enabled ? "Off"
                        : NetworkServices.Bluetooth.connected ? NetworkServices.Bluetooth.device : "On"
                    color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.subtext0 : Commons.Appearance.colors.overlay0
                    font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
                    elide: Text.ElideRight; Layout.maximumWidth: 80
                }
                Text {
                    text: "✕"
                    color: _btCloseMA.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                    font.pixelSize: 11; font.family: Commons.Appearance.font.family
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    MouseArea {
                        id: _btCloseMA
                        anchors.fill: parent; anchors.margins: -4
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (card.holderRoot) card.holderRoot._btPopupVisible = false
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Commons.Appearance.colors.surface0 }

        Item {
            width: parent.width; height: 32
            visible: !NetworkServices.Bluetooth.enabled
            Text {
                anchors.centerIn: parent
                text: "Bluetooth adapter is off"
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
            }
        }

        Item {
            width: parent.width; height: 32
            visible: NetworkServices.Bluetooth.enabled && NetworkServices.Bluetooth.devices.length === 0
            Text {
                anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
                text: "No paired devices"
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
            }
        }

        Repeater {
            model: NetworkServices.Bluetooth.enabled ? NetworkServices.Bluetooth.devices : []
            delegate: Item {
                required property var modelData
                width: parent.width; height: 32
                RowLayout {
                    anchors.fill: parent; spacing: 8
                    Text {
                        text: modelData.connected ? "󰂱" : "󰂯"
                        color: modelData.connected ? Commons.Appearance.colors.mauve : Commons.Appearance.colors.overlay0
                        font.pixelSize: 14; font.family: Commons.Appearance.font.family
                    }
                    Text {
                        text: modelData.name
                        color: modelData.connected ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                        font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Item {
                        property bool _busy: NetworkServices.Bluetooth.connectingTo === modelData.address
                                          || NetworkServices.Bluetooth.disconnectingFrom === modelData.address
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth:  _busy ? 20 : _btDevBtn.width
                        implicitHeight: 22
                        Behavior on implicitWidth { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                        Text {
                            id: _btDevSpinner
                            visible: parent._busy
                            anchors.centerIn: parent
                            text: "󰑙"; color: Commons.Appearance.colors.accent
                            font.pixelSize: 12; font.family: Commons.Appearance.font.family
                            RotationAnimator { target: _btDevSpinner; running: _btDevSpinner.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                        }

                        Rectangle {
                            id: _btDevBtn
                            visible: !parent._busy
                            width: _btDevLbl.implicitWidth + 16; height: 22
                            radius: Commons.Appearance.radius.sm
                            color: _btDevMA.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.surface0
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                            Text {
                                id: _btDevLbl; anchors.centerIn: parent
                                text: modelData.connected ? "Disconnect" : "Connect"
                                color: modelData.connected ? Commons.Appearance.colors.red : Commons.Appearance.colors.mauve
                                font.pixelSize: Commons.Appearance.font.sizeSm - 1; font.family: Commons.Appearance.font.family
                            }
                            MouseArea {
                                id: _btDevMA; anchors.fill: parent; hoverEnabled: true
                                onClicked: modelData.connected
                                    ? NetworkServices.Bluetooth.disconnectDevice(modelData.address)
                                    : NetworkServices.Bluetooth.connectDevice(modelData.address)
                            }
                        }
                    }
                }
            }
        }
    }
}
