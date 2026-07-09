import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Networking" as NetworkServices
import "../Widgets"

Item {
    id: root

    property string _wifiAskPwFor: ""
    property int    _tab: 0   // 0 = Wi-Fi, 1 = Bluetooth

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰤨"
            title: "Connections"
            description: "Manage WiFi networks and paired Bluetooth devices"
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

                // ── Segmented Wi-Fi | Bluetooth tabs ──────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 6
                    TabButton { label: "Wi-Fi";     glyph: "󰖩"; idx: 0 }
                    TabButton { label: "Bluetooth"; glyph: "󰂯"; idx: 1 }
                    Item { Layout.fillWidth: true }
                }

                // ── WiFi ──────────────────────────────────────────────────────
                RowLayout {
                    visible: root._tab === 0
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }

                    // Enable/disable toggle pill
                    Rectangle {
                        height: 22; width: wifiToggleRow.implicitWidth + 16
                        radius: 11
                        color: NetworkServices.Network.wifiEnabled
                            ? Commons.Appearance.colors.accentAlpha
                            : Commons.Appearance.colors.surface0
                        border.color: NetworkServices.Network.wifiEnabled
                            ? Commons.Appearance.colors.accentBorder
                            : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                        RowLayout {
                            id: wifiToggleRow
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8 }
                            spacing: 5

                            Text {
                                text: NetworkServices.Network.wifiEnabled ? "󰖩" : "󰖪"
                                color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                            Text {
                                text: NetworkServices.Network.wifiEnabled ? "On" : "Off"
                                color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NetworkServices.Network.toggleWifi()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: wifiCol.implicitHeight
                    visible: root._tab === 0 && NetworkServices.Network.wifiEnabled

                    ColumnLayout {
                        id: wifiCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 }
                        spacing: 0

                        Item { implicitHeight: 6; Layout.fillWidth: true }

                        // Connected
                        Repeater {
                            model: NetworkServices.Network.displayNetworks.filter(function(n) { return n.active })
                            delegate: WifiRow { Layout.fillWidth: true }
                        }

                        // Divider between connected and saved when both present
                        Item {
                            implicitHeight: 2; Layout.fillWidth: true
                            visible: NetworkServices.Network.displayNetworks.filter(function(n){ return n.active }).length > 0
                                  && NetworkServices.Network.displayNetworks.filter(function(n){ return n.saved && !n.active }).length > 0
                        }

                        // Saved
                        Repeater {
                            model: NetworkServices.Network.displayNetworks.filter(function(n) { return n.saved && !n.active })
                            delegate: WifiRow { Layout.fillWidth: true }
                        }

                        // Divider before available
                        Rectangle {
                            height: 1; Layout.fillWidth: true
                            color: Commons.Appearance.colors.base
                            visible: NetworkServices.Network.displayNetworks.filter(function(n){ return !n.saved && !n.active }).length > 0
                                  && (NetworkServices.Network.displayNetworks.filter(function(n){ return n.active }).length > 0
                                   || NetworkServices.Network.displayNetworks.filter(function(n){ return n.saved && !n.active }).length > 0)
                        }

                        Text {
                            visible: NetworkServices.Network.displayNetworks.filter(function(n){ return !n.saved && !n.active }).length > 0
                            text: "AVAILABLE"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: 9; font.family: Commons.Appearance.font.family
                            font.weight: Font.Medium; font.letterSpacing: 1.5
                            Layout.fillWidth: true
                            Layout.topMargin: 6; Layout.bottomMargin: 2
                        }

                        Repeater {
                            model: NetworkServices.Network.displayNetworks.filter(function(n) { return !n.saved && !n.active })
                            delegate: WifiRow { Layout.fillWidth: true }
                        }

                        Text {
                            visible: NetworkServices.Network.displayNetworks.length === 0
                            text: "Scanning for networks…"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                            Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4
                        }

                        Item { implicitHeight: 6; Layout.fillWidth: true }
                    }
                }

                Text {
                    visible: root._tab === 0 && !NetworkServices.Network.wifiEnabled
                    text: "Wi-Fi is disabled."
                    color: Commons.Appearance.colors.overlay0
                    font.pixelSize: Commons.Appearance.font.sizeBase
                    font.family: Commons.Appearance.font.family
                }

                // ── Bluetooth ─────────────────────────────────────────────────
                RowLayout {
                    visible: root._tab === 1
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }

                    // Scan for new devices — toggles discovery (bt-agent.py --scan).
                    Rectangle {
                        visible: NetworkServices.Bluetooth.enabled
                        height: 22; width: scanRow.implicitWidth + 16
                        radius: 11
                        color: (scanMa.containsMouse || NetworkServices.Bluetooth.discovering)
                            ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0
                        border.color: NetworkServices.Bluetooth.discovering ? Commons.Appearance.colors.accentBorder : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                        RowLayout {
                            id: scanRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                id: scanIco
                                text: NetworkServices.Bluetooth.discovering ? "󰑙" : "󰂰"
                                color: Commons.Appearance.colors.accent
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                                RotationAnimator { target: scanIco; running: NetworkServices.Bluetooth.discovering; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                            }
                            Text {
                                text: NetworkServices.Bluetooth.discovering ? "Scanning…" : "Scan"
                                color: Commons.Appearance.colors.accent
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                        }
                        MouseArea {
                            id: scanMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NetworkServices.Bluetooth.discovering
                                ? NetworkServices.Bluetooth.stopScan()
                                : NetworkServices.Bluetooth.startScan()
                        }
                    }

                    Rectangle {
                        height: 22; width: btToggleRow.implicitWidth + 16
                        radius: 11
                        color: NetworkServices.Bluetooth.enabled
                            ? Commons.Appearance.colors.accentAlpha
                            : Commons.Appearance.colors.surface0
                        border.color: NetworkServices.Bluetooth.enabled
                            ? Commons.Appearance.colors.accentBorder
                            : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                        RowLayout {
                            id: btToggleRow
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8 }
                            spacing: 5

                            Text {
                                text: NetworkServices.Bluetooth.enabled ? "󰂯" : "󰂲"
                                color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                            Text {
                                text: NetworkServices.Bluetooth.enabled ? "On" : "Off"
                                color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NetworkServices.Bluetooth.toggle()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: Commons.Appearance.colors.surface0
                    radius: Commons.Appearance.radius.md
                    implicitHeight: btCol.implicitHeight
                    visible: root._tab === 1 && NetworkServices.Bluetooth.enabled

                    ColumnLayout {
                        id: btCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 }
                        spacing: 0

                        Item { implicitHeight: 6; Layout.fillWidth: true }

                        Text {
                            visible: NetworkServices.Bluetooth.devices.filter(function(d){ return d.paired }).length === 0
                            text: "No paired devices"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeBase
                            font.family: Commons.Appearance.font.family
                            Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
                        }

                        Repeater {
                            model: NetworkServices.Bluetooth.devices.filter(function(d){ return d.paired })
                            delegate: Item {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 40

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1; color: Commons.Appearance.colors.base
                                }

                                RowLayout {
                                    anchors { fill: parent; topMargin: index > 0 ? 1 : 0 }
                                    spacing: 10

                                    Text {
                                        text: modelData.connected ? "󰂱" : "󰂯"
                                        color: modelData.connected ? Commons.Appearance.colors.mauve : Commons.Appearance.colors.overlay0
                                        font.pixelSize: 16; font.family: Commons.Appearance.font.family
                                        Layout.alignment: Qt.AlignVCenter
                                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData.name
                                            color: modelData.connected ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                                            font.pixelSize: Commons.Appearance.font.sizeBase
                                            font.family: Commons.Appearance.font.family
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        }
                                        Text {
                                            visible: modelData.connected
                                            text: "Connected"
                                                + (modelData.battery !== undefined && modelData.battery !== null
                                                   ? "  ·  󰁹 " + modelData.battery + "%" : "")
                                            color: Commons.Appearance.colors.mauve
                                            font.pixelSize: Commons.Appearance.font.sizeSm
                                            font.family: Commons.Appearance.font.family
                                        }
                                    }

                                    // Trust toggle — authorises audio profiles +
                                    // auto-reconnect. Star fills when trusted.
                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        width: 26; height: 26; radius: Commons.Appearance.radius.sm
                                        color: _btTrustMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent"
                                        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.trusted ? "󰓎" : "󰓒"
                                            color: modelData.trusted ? Commons.Appearance.colors.yellow : Commons.Appearance.colors.overlay0
                                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                        }
                                        MouseArea {
                                            id: _btTrustMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: NetworkServices.Bluetooth.setTrusted(modelData.address, !modelData.trusted)
                                        }
                                    }

                                    // Spinner while (dis)connecting, else the action button.
                                    Item {
                                        property bool _busy: NetworkServices.Bluetooth.connectingTo === modelData.address
                                                          || NetworkServices.Bluetooth.disconnectingFrom === modelData.address
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth:  _busy ? 20 : btActionBtn.width
                                        implicitHeight: 26
                                        Behavior on implicitWidth { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                                        Text {
                                            id: btSpinner
                                            visible: parent._busy
                                            anchors.centerIn: parent
                                            text: "󰑙"; color: Commons.Appearance.colors.accent
                                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                            RotationAnimator { target: btSpinner; running: btSpinner.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                                        }

                                        Rectangle {
                                            id: btActionBtn
                                            visible: !parent._busy
                                            height: 26; width: btActionTxt.implicitWidth + 16
                                            radius: Commons.Appearance.radius.sm
                                            color: btActionMa.containsMouse
                                                ? Commons.Appearance.colors.surface1
                                                : Commons.Appearance.colors.base
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                                            Text {
                                                id: btActionTxt
                                                anchors.centerIn: parent
                                                text: modelData.connected ? "Disconnect" : "Connect"
                                                color: modelData.connected ? Commons.Appearance.colors.red : Commons.Appearance.colors.mauve
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                                font.family: Commons.Appearance.font.family
                                            }

                                            MouseArea {
                                                id: btActionMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelData.connected
                                                    ? NetworkServices.Bluetooth.disconnectDevice(modelData.address)
                                                    : NetworkServices.Bluetooth.connectDevice(modelData.address)
                                            }
                                        }
                                    }

                                    // Remove / unpair (spinner while removing).
                                    Item {
                                        property bool _busy: NetworkServices.Bluetooth.removingFrom === modelData.address
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: 26; implicitHeight: 26

                                        Text {
                                            id: btRmSpin
                                            visible: parent._busy; anchors.centerIn: parent
                                            text: "󰑙"; color: Commons.Appearance.colors.red
                                            font.pixelSize: 13; font.family: Commons.Appearance.font.family
                                            RotationAnimator { target: btRmSpin; running: btRmSpin.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                                        }
                                        Rectangle {
                                            visible: !parent._busy
                                            anchors.fill: parent; radius: Commons.Appearance.radius.sm
                                            color: btRmMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent"
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰩺"
                                                color: btRmMa.containsMouse ? Commons.Appearance.colors.red : Commons.Appearance.colors.overlay0
                                                font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                            }
                                            MouseArea {
                                                id: btRmMa; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NetworkServices.Bluetooth.removeDevice(modelData.address)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Discovered (unpaired) devices — appear during a scan ───
                        Rectangle {
                            visible: NetworkServices.Bluetooth.discovering
                                  || NetworkServices.Bluetooth.devices.filter(function(d){ return !d.paired }).length > 0
                            Layout.fillWidth: true; Layout.topMargin: 6
                            height: 1; color: Commons.Appearance.colors.base
                        }
                        Text {
                            visible: NetworkServices.Bluetooth.discovering
                                  || NetworkServices.Bluetooth.devices.filter(function(d){ return !d.paired }).length > 0
                            text: "AVAILABLE"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: 9; font.family: Commons.Appearance.font.family
                            font.weight: Font.Medium; font.letterSpacing: 1.5
                            Layout.fillWidth: true; Layout.topMargin: 6; Layout.bottomMargin: 2
                        }
                        Text {
                            visible: NetworkServices.Bluetooth.discovering
                                  && NetworkServices.Bluetooth.devices.filter(function(d){ return !d.paired }).length === 0
                            text: "Searching…"
                            color: Commons.Appearance.colors.overlay0
                            font.pixelSize: Commons.Appearance.font.sizeSm
                            font.family: Commons.Appearance.font.family
                            Layout.fillWidth: true; Layout.bottomMargin: 2
                        }
                        Repeater {
                            model: NetworkServices.Bluetooth.devices.filter(function(d){ return !d.paired })
                            delegate: Item {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 36
                                RowLayout {
                                    anchors.fill: parent; spacing: 10
                                    Text {
                                        text: "󰂯"; color: Commons.Appearance.colors.overlay0
                                        font.pixelSize: 16; font.family: Commons.Appearance.font.family
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text {
                                        text: modelData.name
                                        color: Commons.Appearance.colors.subtext1
                                        font.pixelSize: Commons.Appearance.font.sizeBase
                                        font.family: Commons.Appearance.font.family
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    // Pair (spinner while pairing)
                                    Item {
                                        property bool _busy: NetworkServices.Bluetooth.pairingTo === modelData.address
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: _busy ? 20 : pairBtn.width; implicitHeight: 26
                                        Behavior on implicitWidth { NumberAnimation { duration: Commons.Appearance.anim.fast } }
                                        Text {
                                            id: pairSpin; visible: parent._busy; anchors.centerIn: parent
                                            text: "󰑙"; color: Commons.Appearance.colors.accent
                                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                            RotationAnimator { target: pairSpin; running: pairSpin.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                                        }
                                        Rectangle {
                                            id: pairBtn; visible: !parent._busy
                                            height: 26; width: pairTxt.implicitWidth + 16
                                            radius: Commons.Appearance.radius.sm
                                            color: pairMa.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.base
                                            Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                                            Text {
                                                id: pairTxt; anchors.centerIn: parent
                                                text: "Pair"; color: Commons.Appearance.colors.mauve
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                                font.family: Commons.Appearance.font.family
                                            }
                                            MouseArea {
                                                id: pairMa; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NetworkServices.Bluetooth.pairDevice(modelData.address)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 6; Layout.fillWidth: true }
                    }
                }

                Text {
                    visible: root._tab === 1 && !NetworkServices.Bluetooth.enabled
                    text: "Bluetooth is disabled."
                    color: Commons.Appearance.colors.overlay0
                    font.pixelSize: Commons.Appearance.font.sizeBase
                    font.family: Commons.Appearance.font.family
                }

                Item { implicitHeight: 10; Layout.fillWidth: true }
            }
        }
    }

    // ── WiFi network row ──────────────────────────────────────────────────────
    component WifiRow: Item {
        required property var modelData

        property bool _showPw:     root._wifiAskPwFor === modelData.ssid
        property bool _busyConn:   NetworkServices.Network.connectingTo === modelData.ssid
        property bool _busyDisc:   modelData.active && NetworkServices.Network.disconnectingFrom === modelData.ssid
        property bool _busy:       _busyConn || _busyDisc
        property bool _needsPw:    !modelData.saved && modelData.security !== "" && modelData.security !== "--"

        implicitHeight: _showPw ? 82 : 40
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 40
            spacing: 8

            Text {
                text: NetworkServices.Network.signalIcon(modelData.signal, modelData.security !== "" && modelData.security !== "--")
                color: modelData.active ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                font.pixelSize: 14; font.family: Commons.Appearance.font.family
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: modelData.ssid
                    color: modelData.active ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext1
                    font.pixelSize: Commons.Appearance.font.sizeBase
                    font.family: Commons.Appearance.font.family
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                }
                Text {
                    visible: modelData.active
                    text: NetworkServices.Network.signal + "%  ·  " + NetworkServices.Network.band
                    color: Commons.Appearance.colors.overlay0
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                }
            }

            // Spinner or action button
            Item {
                Layout.preferredWidth: _busy ? 20 : (actionTxt.implicitWidth + 16)
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Commons.Appearance.anim.fast } }

                Text {
                    id: spinnerTxt
                    visible: _busy
                    anchors.centerIn: parent
                    text: "󰑙"; color: Commons.Appearance.colors.accent
                    font.pixelSize: 14; font.family: Commons.Appearance.font.family
                    RotationAnimator { target: spinnerTxt; running: _busy; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                }

                Rectangle {
                    id: actionBtn
                    visible: !_busy
                    anchors.fill: parent
                    radius: Commons.Appearance.radius.sm
                    color: actionMa.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.surface0
                    Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                    Text {
                        id: actionTxt
                        anchors.centerIn: parent
                        text: modelData.active ? "Disconnect" : "Connect"
                        color: modelData.active ? Commons.Appearance.colors.red : Commons.Appearance.colors.mauve
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                    }

                    MouseArea {
                        id: actionMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active) {
                                NetworkServices.Network.disconnect()
                            } else if (_needsPw) {
                                root._wifiAskPwFor = modelData.ssid
                            } else {
                                NetworkServices.Network.connect(modelData.ssid)
                            }
                        }
                    }
                }
            }

            // Auto-join toggle (saved networks) — NetworkManager autoconnect.
            Rectangle {
                visible: modelData.saved
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: _autoRow.implicitWidth + 14
                Layout.preferredHeight: 22
                radius: 11
                color: modelData.autoconnect ? Commons.Appearance.colors.accentAlpha
                     : (autoMa.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.surface0)
                border.color: modelData.autoconnect ? Commons.Appearance.colors.accentBorder : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                RowLayout {
                    id: _autoRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰁪"
                        color: modelData.autoconnect ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                        font.pixelSize: 10; font.family: Commons.Appearance.font.family
                    }
                    Text {
                        text: "Auto"
                        color: modelData.autoconnect ? Commons.Appearance.colors.accent : Commons.Appearance.colors.overlay0
                        font.pixelSize: 10; font.family: Commons.Appearance.font.family
                    }
                }
                MouseArea {
                    id: autoMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkServices.Network.setAutoconnect(modelData.ssid, !modelData.autoconnect)
                }
                ToolTip { visible: autoMa.containsMouse; delay: 400; text: modelData.autoconnect ? "Auto-join: on" : "Auto-join: off" }
            }

            // Forget a saved network (deletes the stored profile).
            Rectangle {
                visible: modelData.saved
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: Commons.Appearance.radius.sm
                color: forgetMa.containsMouse ? Commons.Appearance.colors.surface1 : "transparent"
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
                Text {
                    anchors.centerIn: parent
                    text: "󰩺"
                    color: forgetMa.containsMouse ? Commons.Appearance.colors.red : Commons.Appearance.colors.overlay0
                    font.pixelSize: 14; font.family: Commons.Appearance.font.family
                }
                MouseArea {
                    id: forgetMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkServices.Network.forget(modelData.ssid)
                }
            }
        }

        // Inline password field
        RowLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 42 }
            height: 34
            spacing: 8
            visible: _showPw

            TextField {
                id: pwField
                Layout.fillWidth: true
                height: 30
                placeholderText: "Password for " + modelData.ssid
                echoMode: TextInput.Password
                font.pixelSize: Commons.Appearance.font.sizeSm
                font.family: Commons.Appearance.font.family
                color: Commons.Appearance.colors.text
                background: Rectangle {
                    radius: Commons.Appearance.radius.sm
                    color: Commons.Appearance.colors.base
                    border.color: pwField.activeFocus ? Commons.Appearance.colors.accentBorder : Commons.Appearance.colors.surface1
                    border.width: 1
                }
                onAccepted: {
                    NetworkServices.Network.connectWithPassword(modelData.ssid, pwField.text)
                    root._wifiAskPwFor = ""
                    pwField.text = ""
                }
            }

            Rectangle {
                height: 30; width: 60
                radius: Commons.Appearance.radius.sm
                color: connectMa.containsMouse ? Commons.Appearance.colors.accentAlpha : Commons.Appearance.colors.surface0
                border.color: Commons.Appearance.colors.accentBorder; border.width: 1
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "Join"
                    color: Commons.Appearance.colors.accent
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                }

                MouseArea {
                    id: connectMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        NetworkServices.Network.connectWithPassword(modelData.ssid, pwField.text)
                        root._wifiAskPwFor = ""
                        pwField.text = ""
                    }
                }
            }

            Rectangle {
                height: 30; width: 60
                radius: Commons.Appearance.radius.sm
                color: cancelMa.containsMouse ? Commons.Appearance.colors.surface1 : Commons.Appearance.colors.surface0
                Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Commons.Appearance.colors.subtext0
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    font.family: Commons.Appearance.font.family
                }

                MouseArea {
                    id: cancelMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root._wifiAskPwFor = ""; pwField.text = "" }
                }
            }
        }
    }

    component SectionLabel: Text {
        color: Commons.Appearance.colors.overlay0
        font.pixelSize: 10
        font.family: Commons.Appearance.font.family
        font.weight: Font.Medium
        font.letterSpacing: 1.5
    }

    // Segmented tab button (Wi-Fi | Bluetooth).
    component TabButton: Rectangle {
        id: tabBtn
        required property string label
        required property string glyph
        required property int idx
        readonly property bool _on: root._tab === idx
        implicitWidth: _tabRow.implicitWidth + 24
        implicitHeight: 30
        radius: Commons.Appearance.radius.base
        color: _on ? Commons.Appearance.colors.accentAlpha
             : (_tabMa.containsMouse ? Commons.Appearance.colors.surface0 : "transparent")
        border.color: _on ? Commons.Appearance.colors.accentBorder : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: Commons.Appearance.anim.fast } }
        RowLayout {
            id: _tabRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                text: tabBtn.glyph
                color: tabBtn._on ? Commons.Appearance.colors.accent : Commons.Appearance.colors.subtext0
                font.pixelSize: 13; font.family: Commons.Appearance.font.family
            }
            Text {
                text: tabBtn.label
                color: tabBtn._on ? Commons.Appearance.colors.text : Commons.Appearance.colors.subtext0
                font.pixelSize: Commons.Appearance.font.sizeBase; font.family: Commons.Appearance.font.family
                font.weight: tabBtn._on ? Font.Medium : Font.Normal
            }
        }
        MouseArea {
            id: _tabMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._tab = tabBtn.idx
        }
    }
}
