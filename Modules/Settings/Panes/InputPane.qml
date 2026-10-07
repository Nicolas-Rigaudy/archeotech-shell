import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../Commons" as Commons
import "../../../Services/Hardware" as Hardware
import "../Widgets"

// Settings → Input (item_136): per-keyboard layouts, key repeat, touchpad.
// Everything is bound to Hardware.Input (real devices from mango, choices in
// the shell config, written to mango's archeotech-input.conf + reload).
Item {
    id: root

    // Re-read devices while the pane is open (keyboards come and go with docks).
    Timer {
        interval: 3000; repeat: true; triggeredOnStart: true
        running: root.visible && Hardware.Input.supported
        onTriggered: Hardware.Input.refresh()
    }

    function _label(kb) {
        return kb.identifier.indexOf("AT Translated Set 2 keyboard") >= 0 ? "Built-in keyboard" : kb.name
    }
    function _status(kb) {
        if (!kb.usable) return "Its name contains a comma, which a mango device rule cannot match"
        var v = Hardware.Input.layoutFor(kb.identifier)
        if (v === "default") return "Uses the default layouts (Alt+Shift switches)"
        if (!kb.matched) return Hardware.Input.settled ? "Not applied: mango rejected the rule (check its log)" : "Applying…"
        return v === "us-intl" ? "Own layout · accents with AltGr (AltGr+e = é, AltGr+, = ç)" : "Own layout"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PaneHeader {
            icon: "󰌌"
            title: "Input"
            description: "Keyboard layouts per keyboard, key repeat and touchpad"
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0 }

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
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Commons.Appearance.spacing.s6; leftMargin: Commons.Appearance.spacing.s6; rightMargin: Commons.Appearance.spacing.s6 }
                width: root.width - 48
                spacing: Commons.Appearance.spacing.s2

                Text {
                    visible: !Hardware.Input.supported
                    Layout.fillWidth: true
                    text: "Input settings are applied through MangoWC; under Hyprland use hyprland.conf."
                    color: Commons.Appearance.colors.textMuted
                    font.family: Commons.Appearance.font.family
                    font.pixelSize: Commons.Appearance.font.sizeSm
                    wrapMode: Text.WordWrap
                }

                // ── Keyboards ─────────────────────────────────────────────────
                SectionLabel { text: "KEYBOARDS"; visible: Hardware.Input.supported }
                SettingsCard {
                    visible: Hardware.Input.supported
                    Repeater {
                        model: Hardware.Input.keyboards
                        delegate: ColumnLayout {
                            id: kbRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0
                            Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true; visible: kbRow.index > 0 }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0; visible: kbRow.index > 0 }
                            Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                            ButtonGroupRow {
                                enabled: kbRow.modelData.usable
                                label: root._label(kbRow.modelData)
                                description: root._status(kbRow.modelData)
                                options: Hardware.Input.layouts.map(l => ({ value: l.value, label: l.label }))
                                currentValue: Hardware.Input.layoutFor(kbRow.modelData.identifier)
                                onSelected: v => Hardware.Input.setLayout(kbRow.modelData.identifier, v)
                            }
                        }
                    }
                    Text {
                        visible: Hardware.Input.keyboards.length === 0
                        Layout.fillWidth: true
                        text: "Reading keyboards…"
                        color: Commons.Appearance.colors.textMuted
                        font.family: Commons.Appearance.font.family
                        font.pixelSize: Commons.Appearance.font.sizeSm
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0 }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                    // Scratch field to try the layout of whichever keyboard you type on.
                    TextFieldRow {
                        label: "Try it"
                        description: "Type here to check a keyboard's layout (nothing is saved)"
                        placeholder: "azerty / qwerty / é à ç"
                    }
                    Item { implicitHeight: Commons.Appearance.spacing.s2; Layout.fillWidth: true }
                }

                // ── Key repeat ────────────────────────────────────────────────
                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true; visible: Hardware.Input.supported }
                SectionLabel { text: "KEY REPEAT"; visible: Hardware.Input.supported }
                SettingsCard {
                    visible: Hardware.Input.supported
                    SliderRow {
                        label: "Delay"
                        description: "How long a key is held before it repeats"
                        from: 150; to: 1000; stepSize: 25
                        value: Hardware.Input.repeatDelay
                        format: v => Math.round(v) + " ms"
                        onMoved: v => Hardware.Input.set("repeatDelay", Math.round(v))
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0 }
                    SliderRow {
                        label: "Rate"
                        description: "Characters per second while a key is held"
                        from: 10; to: 60; stepSize: 1
                        value: Hardware.Input.repeatRate
                        format: v => Math.round(v) + " /s"
                        onMoved: v => Hardware.Input.set("repeatRate", Math.round(v))
                    }
                }

                // ── Touchpad ──────────────────────────────────────────────────
                Item { implicitHeight: Commons.Appearance.spacing.s3; Layout.fillWidth: true; visible: Hardware.Input.supported && Hardware.Input.hasTouchpad }
                SectionLabel { text: "TOUCHPAD"; visible: Hardware.Input.supported && Hardware.Input.hasTouchpad }
                SettingsCard {
                    visible: Hardware.Input.supported && Hardware.Input.hasTouchpad
                    ToggleRow {
                        label: "Tap to click"
                        description: "A light tap counts as a click"
                        checked: Hardware.Input.tapToClick
                        onToggled: v => Hardware.Input.set("tapToClick", v)
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0 }
                    ToggleRow {
                        label: "Natural scrolling"
                        description: "Content follows your fingers"
                        checked: Hardware.Input.naturalScroll
                        onToggled: v => Hardware.Input.set("naturalScroll", v)
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0 }
                    ToggleRow {
                        label: "Disable while typing"
                        description: "Ignore the touchpad for a moment after a key press"
                        checked: Hardware.Input.disableWhileTyping
                        onToggled: v => Hardware.Input.set("disableWhileTyping", v)
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Commons.Appearance.colors.surface0 }
                    SliderRow {
                        label: "Pointer speed"
                        description: "Touchpad acceleration"
                        from: -1; to: 1; stepSize: 0.1
                        value: Hardware.Input.pointerSpeed
                        format: v => (v > 0 ? "+" : "") + v.toFixed(1)
                        onMoved: v => Hardware.Input.set("pointerSpeed", Math.round(v * 10) / 10)
                    }
                }
            }
        }
    }
}
