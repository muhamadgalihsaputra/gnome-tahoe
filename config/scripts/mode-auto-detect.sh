#!/usr/bin/env bash
# Auto Mode Detection Script
# Detects lid state + external monitor and switches modes automatically

set -euo pipefail

USER_HOME="@HOME@"
LOG_FILE="$USER_HOME/.config/mode-switcher.log"
SCRIPT_DIR="$USER_HOME/scripts"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTO-DETECT: $*" >> "$LOG_FILE"
}

# Check lid state
check_lid_state() {
    local lid_state="unknown"
    if [[ -f /proc/acpi/button/lid/LID0/state ]]; then
        lid_state=$(cat /proc/acpi/button/lid/LID0/state | awk '{print $2}')
    elif [[ -f /proc/acpi/button/lid/LID/state ]]; then
        lid_state=$(cat /proc/acpi/button/lid/LID/state | awk '{print $2}')
    else
        # Try alternate method via sysfs
        for lid in /sys/class/input/input*/name; do
            if grep -qi "lid" "$lid" 2>/dev/null; then
                local lid_dir=$(dirname "$lid")
                if [[ -f "$lid_dir/state" ]]; then
                    lid_state=$(cat "$lid_dir/state")
                    break
                fi
            fi
        done
    fi
    echo "$lid_state"
}

# Check external monitor
check_external_monitor() {
    local monitor_count=0
    
    # For Wayland/X11
    if command -v xrandr &>/dev/null; then
        monitor_count=$(xrandr --listmonitors 2>/dev/null | grep -c "^ " || echo "0")
    fi
    
    # Fallback: check DRM devices
    if [[ "$monitor_count" -eq 0 ]] && [[ -d /sys/class/drm ]]; then
        monitor_count=$(find /sys/class/drm/card*/status -exec cat {} \; 2>/dev/null | grep -c "^connected" || echo "0")
    fi
    
    echo "$monitor_count"
}

# Main logic
LID_STATE=$(check_lid_state)
MONITOR_COUNT=$(check_external_monitor)

log "Lid state: $LID_STATE, External monitors: $MONITOR_COUNT"

# Decision logic - Only set input devices, don't touch performance
if [[ "$LID_STATE" == "closed" ]] && [[ "$MONITOR_COUNT" -ge 1 ]]; then
    log "Condition met: Lid closed + external monitor detected"
    log "Setting desktop inputs (fingerprint OFF, touchpad OFF)"
    bash "$SCRIPT_DIR/set-input-mode.sh" desktop
elif [[ "$LID_STATE" == "open" ]]; then
    log "Condition met: Lid open"
    log "Setting laptop inputs (fingerprint ON, touchpad ON)"
    bash "$SCRIPT_DIR/set-input-mode.sh" laptop
else
    log "No action needed (Lid: $LID_STATE, Monitors: $MONITOR_COUNT)"
fi
