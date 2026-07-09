import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../Commons" as Commons
import "../../Services/Networking" as NetworkServices
import "../../Services/Shell" as ShellServices

// WiFi popup — adapter toggle, network list, connect/disconnect, rescan.
// Anchor x driven by holderRoot._wifiAnchorX (set by NetworkWidget on click).
Shape {
    id: card
    required property var holderRoot

    property real _r:  Commons.Appearance.radius.xl
    property real _rb: Commons.Appearance.radius.md
    property real _bw: 260

    x: Math.min(
           Math.max((holderRoot ? holderRoot._wifiAnchorX : 0) - width / 2,
                    Commons.Appearance.bar.marginSide + 4),
           (holderRoot ? holderRoot.width : 0) - width - Commons.Appearance.bar.marginSide - 4)
    y: Commons.Appearance.bar.marginTop + Commons.Appearance.bar.height
    width:  _bw + _r * 2
    height: _wifiContent.implicitHeight + 20

    layer.enabled: true
    layer.samples: 8
    transformOrigin: Item.Top
    scale:   (holderRoot && holderRoot._wifiPopupVisible) ? 1.0 : 0.85
    opacity: (holderRoot && holderRoot._wifiPopupVisible) ? 1.0 : 0.0
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
        id: _wifiContent
        x: card._r + 12; y: 10
        width: card._bw - 24
        spacing: 0

        // Header: adapter toggle + label + close
        Item {
            width: parent.width; height: 40
            RowLayout {
                anchors.fill: parent; spacing: 8
                Rectangle {
                    width: 28; height: 28; radius: Commons.Appearance.radius.base
                    color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.accent : Commons.Appearance.colors.surface0
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    Text {
                        anchors.centerIn: parent
                        text: NetworkServices.Network.icon()
                        color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                        font.pixelSize: 13; font.family: Commons.Appearance.font.family
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NetworkServices.Network.toggleWifi() }
                }
                Text {
                    text: !NetworkServices.Network.wifiEnabled ? "WiFi — Off"
                        : NetworkServices.Network.connected ? "WiFi · " + NetworkServices.Network.ssid : "WiFi — Not connected"
                    color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                    font.pixelSize: Commons.Appearance.font.sizeMd; font.family: Commons.Appearance.font.family
                    font.weight: Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    text: "✕"
                    color: _wifiCloseMA.containsMouse ? Commons.Appearance.colors.text : Commons.Appearance.colors.overlay0
                    font.pixelSize: 11; font.family: Commons.Appearance.font.family
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                    MouseArea {
                        id: _wifiCloseMA
                        anchors.fill: parent; anchors.margins: -4
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (card.holderRoot) card.holderRoot._wifiPopupVisible = false
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Commons.Appearance.colors.surface0 }

        Item {
            width: parent.width; height: 32
            visible: !NetworkServices.Network.wifiEnabled
            Text {
                anchors.centerIn: parent
                text: "Enable WiFi to see networks"
                color: Commons.Appearance.colors.overlay0
                font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
            }
        }

        Repeater {
            model: NetworkServices.Network.wifiEnabled ? NetworkServices.Network.displayNetworks.slice(0, 5) : []
            delegate: Item {
                required property var modelData
                width: parent.width; height: 32
                property bool _busy: NetworkServices.Network.connectingTo === modelData.ssid
                    || (modelData.active && NetworkServices.Network.disconnectingFrom === modelData.ssid)
                property bool _needsPw: !modelData.saved
                    && modelData.security !== "" && modelData.security !== "--"
                RowLayout {
                    anchors.fill: parent; spacing: 6
                    Text {
                        text: NetworkServices.Network.signalIcon(
                            modelData.signal, modelData.security !== "" && modelData.security !== "--")
                        color: modelData.active ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                        font.pixelSize: 13; font.family: Commons.Appearance.font.family
                    }
                    Text {
                        text: modelData.ssid
                        color: modelData.active ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                        font.pixelSize: Commons.Appearance.font.sizeSm; font.family: Commons.Appearance.font.family
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Item {
                        width: _busy ? 20 : _wBtnTxt.implicitWidth + 16; height: 22
                        Behavior on width { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                        Text {
                            id: _wBtnSpinner; visible: _busy; anchors.centerIn: parent
                            text: "󰑙"; color: Commons.Appearance.colors.accent
                            font.pixelSize: 13; font.family: Commons.Appearance.font.family
                            RotationAnimator { target: _wBtnSpinner; running: _busy; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                        }
                        Rectangle {
                            id: _wBtn; visible: !_busy; anchors.fill: parent
                            radius: Commons.Appearance.radius.sm
                            color: _wBtnMA.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.surface0
                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                            Text {
                                id: _wBtnTxt; anchors.centerIn: parent
                                text: modelData.active ? "Disconnect" : (_needsPw ? "Open CC" : "Connect")
                                color: modelData.active ? Commons.Appearance.colors.red
                                    : _needsPw ? Commons.Appearance.colors.subtext0
                                    : Commons.Appearance.colors.mauve
                                font.pixelSize: Commons.Appearance.font.sizeSm - 1; font.family: Commons.Appearance.font.family
                            }
                            MouseArea {
                                id: _wBtnMA; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (modelData.active) {
                                        NetworkServices.Network.disconnect()
                                    } else if (_needsPw) {
                                        Commons.State.settingsOpenPane = "connections"
                                        ShellServices.ShellState.openGlobal("settings")
                                        if (card.holderRoot) card.holderRoot._wifiPopupVisible = false
                                    } else {
                                        NetworkServices.Network.connect(modelData.ssid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width; height: 28
            visible: NetworkServices.Network.wifiEnabled
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: NetworkServices.Network.scanning ? "Scanning…" : "󰑙  Rescan"
                color: NetworkServices.Network.scanning ? Commons.Appearance.colors.overlay0 : Commons.Appearance.colors.mauve
                font.pixelSize: Commons.Appearance.font.sizeSm - 1; font.family: Commons.Appearance.font.family
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4
                    enabled: !NetworkServices.Network.scanning; cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkServices.Network.scan()
                }
            }
        }
    }
}
