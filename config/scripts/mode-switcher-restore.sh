#!/usr/bin/env bash
# Auto-restore mode-switcher state after boot

USER_NAME="${TARGET_USER:-${SUDO_USER:-galyarder}}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
STATE_FILE="$USER_HOME/.config/mode-switcher.state"
LOG_FILE="$USER_HOME/.config/mode-switcher.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Wait for system to be ready
sleep 5

if [[ ! -f "$STATE_FILE" ]]; then
    log "No saved state found, skipping auto-restore"
    exit 0
fi

MODE=$(grep "^MODE=" "$STATE_FILE" | cut -d= -f2-)

log "========== AUTO-RESTORE START =========="
log "Restoring mode: $MODE"

case "$MODE" in
    Desktop)
        # Desktop: Disable fingerprint & touchpad
        systemctl stop fprintd.service 2>/dev/null || true
        systemctl mask fprintd.service 2>/dev/null || true
        
        sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $USER_NAME)/bus" gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled 2>/dev/null || true
        
        log "Desktop mode restored"
        ;;
        
    Laptop)
        # Laptop: Enable fingerprint & touchpad
        systemctl unmask fprintd.service 2>/dev/null || true
        systemctl start fprintd.service 2>/dev/null || true
        
        sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $USER_NAME)/bus" gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled 2>/dev/null || true
        
        log "Laptop mode restored"
        ;;
        
    *)
        log "Unknown mode: $MODE"
        exit 1
        ;;
esac

log "Auto-restore completed successfully"
