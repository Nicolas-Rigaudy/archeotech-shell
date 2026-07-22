import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Commons/Primitives"
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
                    GlassButton {
                        active: NetworkServices.Network.wifiEnabled
                        onClicked: NetworkServices.Network.toggleWifi()

                        RowLayout {
                            id: wifiToggleRow
                            spacing: 5

                            Text {
                                text: NetworkServices.Network.wifiEnabled ? "󰖩" : "󰖪"
                                color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                            Text {
                                text: NetworkServices.Network.wifiEnabled ? "On" : "Off"
                                color: NetworkServices.Network.wifiEnabled ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                        }
                    }
                }

                SettingsCard {
                    visible: root._tab === 0 && NetworkServices.Network.wifiEnabled

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
                            color: Commons.Appearance.colors.surface0
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
                    GlassButton {
                        visible: NetworkServices.Bluetooth.enabled
                        active: NetworkServices.Bluetooth.discovering
                        onClicked: NetworkServices.Bluetooth.discovering
                            ? NetworkServices.Bluetooth.stopScan()
                            : NetworkServices.Bluetooth.startScan()
                        RowLayout {
                            id: scanRow
                            spacing: 5
                            Text {
                                id: scanIco
                                text: NetworkServices.Bluetooth.discovering ? "󰑙" : "󰂰"
                                color: NetworkServices.Bluetooth.discovering ? Commons.Appearance.colors.base : Commons.Appearance.colors.accent
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                                RotationAnimator { target: scanIco; running: NetworkServices.Bluetooth.discovering; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                            }
                            Text {
                                text: NetworkServices.Bluetooth.discovering ? "Scanning…" : "Scan"
                                color: NetworkServices.Bluetooth.discovering ? Commons.Appearance.colors.base : Commons.Appearance.colors.accent
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                        }
                    }

                    GlassButton {
                        active: NetworkServices.Bluetooth.enabled
                        onClicked: NetworkServices.Bluetooth.toggle()

                        RowLayout {
                            id: btToggleRow
                            spacing: 5

                            Text {
                                text: NetworkServices.Bluetooth.enabled ? "󰂯" : "󰂲"
                                color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                            Text {
                                text: NetworkServices.Bluetooth.enabled ? "On" : "Off"
                                color: NetworkServices.Bluetooth.enabled ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                                font.pixelSize: 11; font.family: Commons.Appearance.font.family
                            }
                        }
                    }
                }

                SettingsCard {
                    visible: root._tab === 1 && NetworkServices.Bluetooth.enabled

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
                                    height: 1; color: Commons.Appearance.colors.surface0
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
                                        color: "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.trusted ? "󰓎" : "󰓒"
                                            color: modelData.trusted ? Commons.Appearance.colors.yellow : Commons.Appearance.colors.overlay0
                                            font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                        }
                                        StateLayer {
                                            anchors.fill: parent
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

                                        GlassButton {
                                            id: btActionBtn
                                            visible: !parent._busy
                                            onClicked: modelData.connected
                                                ? NetworkServices.Bluetooth.disconnectDevice(modelData.address)
                                                : NetworkServices.Bluetooth.connectDevice(modelData.address)

                                            Text {
                                                id: btActionTxt
                                                text: modelData.connected ? "Disconnect" : "Connect"
                                                color: modelData.connected ? Commons.Appearance.colors.red : Commons.Appearance.colors.mauve
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                                font.family: Commons.Appearance.font.family
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
                                            color: "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰩺"
                                                color: btRmLayer.hovered ? Commons.Appearance.colors.red : Commons.Appearance.colors.overlay0
                                                font.pixelSize: 14; font.family: Commons.Appearance.font.family
                                            }
                                            StateLayer {
                                                id: btRmLayer; anchors.fill: parent
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
                            height: 1; color: Commons.Appearance.colors.surface0
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
                                        GlassButton {
                                            id: pairBtn; visible: !parent._busy
                                            onClicked: NetworkServices.Bluetooth.pairDevice(modelData.address)
                                            Text {
                                                id: pairTxt
                                                text: "Pair"; color: Commons.Appearance.colors.mauve
                                                font.pixelSize: Commons.Appearance.font.sizeSm
                                                font.family: Commons.Appearance.font.family
                                            }
                                        }
                                    }
                                }
                            }
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

                GlassButton {
                    id: actionBtn
                    visible: !_busy
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.active) {
                            NetworkServices.Network.disconnect()
                        } else if (_needsPw) {
                            root._wifiAskPwFor = modelData.ssid
                        } else {
                            NetworkServices.Network.connect(modelData.ssid)
                        }
                    }

                    Text {
                        id: actionTxt
                        text: modelData.active ? "Disconnect" : "Connect"
                        color: modelData.active ? Commons.Appearance.colors.red : Commons.Appearance.colors.mauve
                        font.pixelSize: Commons.Appearance.font.sizeSm
                        font.family: Commons.Appearance.font.family
                    }
                }
            }

            // Auto-join toggle (saved networks) — NetworkManager autoconnect.
            GlassButton {
                id: autoBtn
                visible: modelData.saved
                active: modelData.autoconnect
                Layout.alignment: Qt.AlignVCenter
                onClicked: NetworkServices.Network.setAutoconnect(modelData.ssid, !modelData.autoconnect)
                RowLayout {
                    id: _autoRow
                    spacing: 4
                    Text {
                        text: "󰁪"
                        color: modelData.autoconnect ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                        font.pixelSize: 10; font.family: Commons.Appearance.font.family
                    }
                    Text {
                        text: "Auto"
                        color: modelData.autoconnect ? Commons.Appearance.colors.base : Commons.Appearance.colors.overlay0
                        font.pixelSize: 10; font.family: Commons.Appearance.font.family
                    }
                }
                ToolTip { visible: autoBtn.hovered; delay: 400; text: modelData.autoconnect ? "Auto-join: on" : "Auto-join: off" }
            }

            // Forget a saved network (deletes the stored profile).
            Rectangle {
                visible: modelData.saved
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: Commons.Appearance.radius.sm
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰩺"
                    color: forgetLayer.hovered ? Commons.Appearance.colors.red : Commons.Appearance.colors.overlay0
                    font.pixelSize: 14; font.family: Commons.Appearance.font.family
                }
                StateLayer {
                    id: forgetLayer; anchors.fill: parent
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

            GlassButton {
                implicitWidth: 60
                text: "Join"
                active: true
                onClicked: {
                    NetworkServices.Network.connectWithPassword(modelData.ssid, pwField.text)
                    root._wifiAskPwFor = ""
                    pwField.text = ""
                }
            }

            GlassButton {
                implicitWidth: 60
                text: "Cancel"
                onClicked: { root._wifiAskPwFor = ""; pwField.text = "" }
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
    component TabButton: GlassButton {
        id: tabBtn
        required property string label
        required property string glyph
        required property int idx
        active: root._tab === idx
        onClicked: root._tab = tabBtn.idx
        RowLayout {
            spacing: 7
            Text {
                text: tabBtn.glyph
                color: tabBtn.active ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext0
                font.pixelSize: 13; font.family: Commons.Appearance.font.family
            }
            Text {
                text: tabBtn.label
                color: tabBtn.active ? Commons.Appearance.colors.base : Commons.Appearance.colors.subtext0
                font.pixelSize: Commons.Appearance.font.sizeBase; font.family: Commons.Appearance.font.family
                font.weight: tabBtn.active ? Font.Medium : Font.Normal
            }
        }
    }
}
