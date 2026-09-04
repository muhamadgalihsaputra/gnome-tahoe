#!/usr/bin/env bash
# Desktop Mode - NO LAG VERSION
# Docked setup: disable fingerprint/touchpad, full performance

set -uo pipefail

LOG_FILE="$HOME/.config/mode-switcher.log"
STATE_FILE="$HOME/.config/mode-switcher.state"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}DESKTOP MODE${NC} - Docked Setup          ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# Main execution
print_header
mkdir -p "$HOME/.config"

log "========== DESKTOP MODE START =========="

# Get sudo early
echo -e "${CYAN}Applying desktop mode (docked setup)...${NC}"
echo -e "${YELLOW}Enter sudo password:${NC}"
if ! sudo -v; then
    echo -e "${RED}Sudo authentication failed.${NC}"
    exit 1
fi

# Batch ALL sudo commands in one session
echo -e "${CYAN}Configuring system (single sudo session)...${NC}"

sudo bash <<'SUDOSCRIPT'
# Fingerprint
systemctl stop fprintd.service 2>/dev/null || true
systemctl mask fprintd.service 2>/dev/null || true

# CPU: 100% - NO CAP!
if [[ -f /sys/devices/system/cpu/intel_pstate/max_perf_pct ]]; then
    echo 100 > /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || true
fi

# WiFi power save OFF (low latency)
WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
if [[ -n "$WIFI_DEV" ]]; then
    iw dev "$WIFI_DEV" set power_save off 2>/dev/null || true
fi

# USB autosuspend OFF (mouse/keyboard instant)
for device in /sys/bus/usb/devices/*/power/control; do
    if [[ -f "$device" ]]; then
        echo "on" > "$device" 2>/dev/null || true
    fi
done

# Platform: Balanced (default)
if [[ -f /sys/firmware/acpi/platform_profile ]]; then
    echo "balanced" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
fi

# Turbo OFF LAST (after platform, multiple times to ensure it sticks)
if [[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    printf '1\n' > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
    sleep 2
    printf '1\n' > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
fi
SUDOSCRIPT

# Touchpad - use gsettings with proper user context
if command -v gsettings &>/dev/null; then
    if [[ "$EUID" -eq 0 ]]; then
        REAL_USER="galyarder"
        USER_UID=$(id -u $REAL_USER)
        # Run as user with full environment
        runuser -u "$REAL_USER" -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_UID/bus gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled 2>/dev/null || true
    else
        gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled 2>/dev/null || true
    fi
fi

# Wait for kernel
sleep 0.5

log "Commands executed, verifying..."

# VERIFY - Read actual system state
echo ""
echo -e "${CYAN}Verification:${NC}"

# Fingerprint
FP_STATUS=$(systemctl is-enabled fprintd.service 2>&1 | head -1 | tr -d ' \n\r')
if [[ "$FP_STATUS" == "masked" ]]; then
    echo -e "  ${GREEN}✓${NC} Fingerprint: ${GREEN}DISABLED${NC}"
    log "Fingerprint: disabled ✓"
else
    echo -e "  ${YELLOW}⚠${NC} Fingerprint: ${YELLOW}$FP_STATUS${NC}"
    log "Fingerprint: $FP_STATUS"
fi

# Touchpad
if [[ "$EUID" -eq 0 ]]; then
    REAL_USER="galyarder"
    USER_UID=$(id -u $REAL_USER)
    TP_STATUS=$(runuser -u "$REAL_USER" -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_UID/bus gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null || echo "unknown")
else
    TP_STATUS=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null || echo "unknown")
fi

if [[ "$TP_STATUS" == "'disabled'" ]]; then
    echo -e "  ${GREEN}✓${NC} Touchpad: ${GREEN}DISABLED${NC}"
    log "Touchpad: disabled ✓"
else
    echo -e "  ${YELLOW}⚠${NC} Touchpad: ${YELLOW}$TP_STATUS${NC}"
    log "Touchpad: $TP_STATUS"
fi

# CPU Cap
CPU_CAP=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || echo "unknown")
if [[ "$CPU_CAP" == "100" ]]; then
    echo -e "  ${GREEN}✓${NC} CPU Limit: ${GREEN}100%${NC} (no cap, full power!)"
    log "CPU: 100% ✓"
else
    echo -e "  ${RED}✗${NC} CPU Limit: ${RED}$CPU_CAP%${NC} (expected: 100%)"
    log "CPU: FAILED ($CPU_CAP%)"
fi

# Turbo
TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "unknown")
if [[ "$TURBO" == "1" ]]; then
    echo -e "  ${GREEN}✓${NC} Turbo Boost: ${GREEN}DISABLED${NC} (balanced)"
    log "Turbo: disabled ✓"
else
    echo -e "  ${YELLOW}⚠${NC} Turbo Boost: ${YELLOW}$TURBO${NC}"
    log "Turbo: $TURBO"
fi

# Platform
PLATFORM=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "unknown")
if [[ "$PLATFORM" == "balanced" ]]; then
    echo -e "  ${GREEN}✓${NC} Platform: ${GREEN}balanced${NC} (smooth + cool)"
    log "Platform: balanced ✓"
else
    echo -e "  ${RED}✗${NC} Platform: ${RED}$PLATFORM${NC} (expected: balanced)"
    log "Platform: FAILED ($PLATFORM)"
fi

# WiFi
WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
if [[ -n "$WIFI_DEV" ]]; then
    WIFI_PS=$(iw dev "$WIFI_DEV" get power_save 2>/dev/null | awk '{print $NF}')
    if [[ "$WIFI_PS" == "off" ]]; then
        echo -e "  ${GREEN}✓${NC} WiFi Power Save: ${GREEN}OFF${NC} (low latency)"
        log "WiFi: power save off ✓"
    else
        echo -e "  ${YELLOW}⚠${NC} WiFi Power Save: ${YELLOW}$WIFI_PS${NC}"
        log "WiFi: $WIFI_PS"
    fi
fi

# USB
USB_COUNT=$(find /sys/bus/usb/devices/*/power/control -type f 2>/dev/null | wc -l)
USB_ON=$(grep -l "on" /sys/bus/usb/devices/*/power/control 2>/dev/null | wc -l)
echo -e "  ${GREEN}✓${NC} USB Autosuspend: ${GREEN}OFF${NC} ($USB_ON/$USB_COUNT devices)"

# Battery (not managed)
BAT_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo "N/A")
BAT_STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "N/A")
echo -e "  ${CYAN}ℹ${NC} Battery: ${CYAN}${BAT_START}-${BAT_STOP}%${NC} (GNOME controls)"

# Save state
cat > "$STATE_FILE" <<EOF
MODE=desktop
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EOF

log "Desktop mode complete"

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}Desktop Mode Applied${NC}                   ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo -e "  Input: ${GREEN}Mouse only${NC} (fingerprint + touchpad disabled)"
echo -e "  CPU: ${GREEN}100%${NC} (no limit, full power!)"
echo -e "  Platform: ${GREEN}$PLATFORM${NC}"
echo -e "  WiFi: ${GREEN}Low latency${NC} (power save off)"
echo -e "  USB: ${GREEN}Instant response${NC} (autosuspend off)"
echo -e "  Battery: ${BAT_START}-${BAT_STOP}% (GNOME controls)"
echo ""
echo -e "${GRAY}Switch to laptop mode: laptop-mode${NC}"
echo ""
