#!/bin/bash
# battery-alert.sh - Monitor battery and send swaync notifications
# Thresholds: 20% warning, 10% urgent, 5% critical (repeating)

BATTERY="/sys/class/power_supply/BAT0"
CAPACITY_FILE="$BATTERY/capacity"
STATUS_FILE="$BATTERY/status"

# Fixed replace-ID so swaync replaces the previous battery notification
# instead of stacking them. Any integer works; just needs to be consistent.
BATTERY_NOTIFY_ID=9901

# Track which notifications have already been sent (reset when plugged in)
NOTIFIED_50=false
NOTIFIED_20=false
NOTIFIED_10=false
NOTIFIED_5=false

send_notification() {
    local urgency="$1"
    local title="$2"
    local message="$3"
    local icon="$4"
    notify-send -u "$urgency" -r "$BATTERY_NOTIFY_ID" -i "$icon" "$title" "$message"
}

while true; do
    CAPACITY=$(cat "$CAPACITY_FILE" 2>/dev/null)
    STATUS=$(cat "$STATUS_FILE" 2>/dev/null)

    # Reset notification flags when plugged in
    if [[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]]; then
        NOTIFIED_50=false
        NOTIFIED_20=false
        NOTIFIED_10=false
        NOTIFIED_5=false
        # Dismiss the battery notification if it's still showing
        # notify-send with replace-id and empty body closes it on some implementations;
        # gdbus is the reliable way to close a specific notification by id.
        gdbus call --session \
            --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.CloseNotification \
            "$BATTERY_NOTIFY_ID" 2>/dev/null || true
        sleep 30
        continue
    fi

    # Only alert when discharging
    if [[ "$STATUS" == "Discharging" ]]; then
        if [[ "$CAPACITY" -le 5 && "$NOTIFIED_5" == false ]]; then
            NOTIFIED_5=true
            send_notification "critical" "Battery Critical: ${CAPACITY}%" "Plug in NOW — system will suspend in minutes." "battery-caution"
        elif [[ "$CAPACITY" -le 10 && "$NOTIFIED_10" == false ]]; then
            NOTIFIED_10=true
            send_notification "critical" "Battery Low: ${CAPACITY}%" "Plug in your charger immediately." "battery-caution"
        elif [[ "$CAPACITY" -le 20 && "$NOTIFIED_20" == false ]]; then
            NOTIFIED_20=true
            send_notification "normal" "Battery Low: ${CAPACITY}%" "You should plug in your charger." "battery-caution"
        elif [[ "$CAPACITY" -le 50 && "$NOTIFIED_50" == false ]]; then
            NOTIFIED_50=true
            send_notification "low" "Battery at ${CAPACITY}%" "Consider plugging in soon." "battery-low"
        fi
    fi

    sleep 60
done
