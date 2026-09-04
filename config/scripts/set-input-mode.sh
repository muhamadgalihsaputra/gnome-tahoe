#!/usr/bin/env bash
# Set Input Mode - Only manages input devices (touchpad, fingerprint)
# Called by auto-detect, doesn't touch performance settings

set -euo pipefail

MODE="${1:-desktop}"  # desktop or laptop

LOG_FILE="@HOME@/.config/mode-switcher.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INPUT-MODE: $*" >> "$LOG_FILE"
}

log "Setting input mode: $MODE"

# Always set USB & WiFi to responsive (OFF) for smooth experience
# Performance profiles can override WiFi for Power Saver mode
log "Setting USB autosuspend: OFF, WiFi power save: OFF"

# USB autosuspend OFF (responsive)
for device in /sys/bus/usb/devices/*/power/control; do
    if [[ -f "$device" ]]; then
        echo "on" > "$device" 2>/dev/null || true
    fi
done

# WiFi power save OFF (responsive)
WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
if [[ -n "$WIFI_DEV" ]]; then
    iw dev "$WIFI_DEV" set power_save off 2>/dev/null || true
fi

if [[ "$MODE" == "desktop" ]]; then
    # Desktop: Disable fingerprint & touchpad
    log "Desktop inputs: Disabling fingerprint and touchpad"
    
    # Fingerprint
    systemctl stop fprintd.service 2>/dev/null || true
    systemctl mask fprintd.service 2>/dev/null || true
    
    # Touchpad
    if command -v gsettings &>/dev/null; then
        if [[ "$EUID" -eq 0 ]]; then
            REAL_USER="galyarder"
            USER_UID=$(id -u $REAL_USER)
            runuser -u "$REAL_USER" -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_UID/bus gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled 2>/dev/null || true
        fi
    fi
    
    log "Desktop inputs applied"
    
elif [[ "$MODE" == "laptop" ]]; then
    # Laptop: Enable fingerprint & touchpad
    log "Laptop inputs: Enabling fingerprint and touchpad"
    
    # Fingerprint
    systemctl unmask fprintd.service 2>/dev/null || true
    systemctl start fprintd.service 2>/dev/null || true
    
    # Touchpad
    if command -v gsettings &>/dev/null; then
        if [[ "$EUID" -eq 0 ]]; then
            REAL_USER="galyarder"
            USER_UID=$(id -u $REAL_USER)
            runuser -u "$REAL_USER" -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_UID/bus gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled 2>/dev/null || true
        fi
    fi
    
    log "Laptop inputs applied"
fi
