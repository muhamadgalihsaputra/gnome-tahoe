#!/usr/bin/env bash
# Mode Status Checker - Display current system mode configuration

set -uo pipefail

STATE_FILE="$HOME/.config/mode-switcher.state"
LOG_FILE="$HOME/.config/mode-switcher.log"

# Colors - Improved visibility
RED='\033[1;31m'      # Bright red
GREEN='\033[1;32m'    # Bright green
YELLOW='\033[1;33m'   # Bright yellow
BLUE='\033[1;34m'     # Bright blue
CYAN='\033[1;36m'     # Bright cyan
MAGENTA='\033[1;35m'  # Bright magenta
WHITE='\033[1;37m'    # Bright white
GRAY='\033[0;37m'     # Light gray (not dark gray)
DIM='\033[2m'         # Dim text
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}            ${BOLD}SYSTEM MODE STATUS${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

get_status() {
    local item=$1
    local current=$2
    local expected=$3
    
    if [[ "$current" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

print_header

# Check if mode is set
if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${YELLOW}⚠ No mode configured yet${NC}"
    echo ""
    echo -e "Run one of the following to configure:"
    echo -e "  ${CYAN}desktop-mode${NC} - Desktop/docked mode"
    echo -e "  ${CYAN}laptop-mode${NC}  - Laptop/portable mode"
    echo ""
    exit 0
fi

# Read current mode
source "$STATE_FILE" 2>/dev/null || true

# Mode Info
if [[ "$MODE" == "desktop" ]]; then
    echo -e "${BOLD}Current Mode:${NC} ${MAGENTA}${MODE^^}${NC}"
else
    echo -e "${BOLD}Current Mode:${NC} ${CYAN}${MODE^^}${NC}"
fi
[[ -n "${PROFILE:-}" ]] && echo -e "${BOLD}Profile:${NC} ${YELLOW}$PROFILE${NC}"
[[ -n "${TIMESTAMP:-}" ]] && echo -e "${WHITE}Activated:${NC} ${GRAY}$TIMESTAMP${NC}"
echo ""

# System Status
echo -e "${BLUE}┌─ Hardware Configuration${NC}"

# Fingerprint
FPRINTD_STATUS=$(systemctl is-active fprintd.service 2>/dev/null || echo "inactive")
if [[ "$MODE" == "desktop" ]]; then
    STATUS=$(get_status "fprintd" "$FPRINTD_STATUS" "inactive")
    echo -e "${WHITE}│${NC} $STATUS Fingerprint: ${RED}Disabled${NC} ${DIM}($([ "$FPRINTD_STATUS" == "inactive" ] && echo "masked" || echo "expected: masked"))${NC}"
else
    STATUS=$(get_status "fprintd" "$FPRINTD_STATUS" "active")
    echo -e "${WHITE}│${NC} $STATUS Fingerprint: ${GREEN}Enabled${NC} ${DIM}($([ "$FPRINTD_STATUS" == "active" ] && echo "active" || echo "expected: active"))${NC}"
fi

# Touchpad
TOUCHPAD_STATUS=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null || echo "unknown")
if [[ "$MODE" == "desktop" ]]; then
    STATUS=$(get_status "touchpad" "$TOUCHPAD_STATUS" "'disabled'")
    echo -e "${WHITE}│${NC} $STATUS Touchpad: ${RED}Disabled${NC}"
else
    STATUS=$(get_status "touchpad" "$TOUCHPAD_STATUS" "'enabled'")
    echo -e "${WHITE}│${NC} $STATUS Touchpad: ${GREEN}Enabled${NC}"
fi

# Display
MONITORS=$(xrandr --listmonitors 2>/dev/null | grep -c "^ " || echo "0")
LID_STATE=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}' || echo "unknown")
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} Displays: ${WHITE}$MONITORS${NC} active, Lid: ${WHITE}$LID_STATE${NC}"

echo -e "${BLUE}└─${NC}"
echo ""

# CPU Status
echo -e "${BLUE}┌─ CPU Performance${NC}"

CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} Governor: ${WHITE}$CPU_GOVERNOR${NC}"

TURBO_STATE=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "unknown")
if [[ "$TURBO_STATE" == "0" ]]; then
    echo -e "${WHITE}│${NC} ${GREEN}✓${NC} Turbo Boost: ${GREEN}Enabled${NC}"
elif [[ "$TURBO_STATE" == "1" ]]; then
    echo -e "${WHITE}│${NC} ${YELLOW}⚠${NC} Turbo Boost: ${YELLOW}Disabled${NC}"
else
    echo -e "${WHITE}│${NC} ${GRAY}?${NC} Turbo Boost: ${GRAY}Unknown${NC}"
fi

CPU_MAX=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || echo "unknown")
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} CPU Limit: ${WHITE}${CPU_MAX}%${NC}"

PLATFORM=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "unknown")
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} Platform Profile: ${WHITE}$PLATFORM${NC}"

echo -e "${BLUE}└─${NC}"
echo ""

# Battery Status
echo -e "${BLUE}┌─ Battery Management${NC}"

BAT_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo "N/A")
BAT_STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "N/A")
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} Charge Threshold: ${WHITE}${BAT_START}-${BAT_STOP}%${NC}"

BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
BAT_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "N/A")
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} Battery: ${WHITE}${BAT_CAPACITY}%${NC} ${DIM}($BAT_STATUS)${NC}"

echo -e "${BLUE}└─${NC}"
echo ""

# Power Status
echo -e "${BLUE}┌─ Power Management${NC}"

# WiFi
WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
if [[ -n "$WIFI_DEV" ]]; then
    WIFI_PS=$(iw dev "$WIFI_DEV" get power_save 2>/dev/null | awk '{print $NF}')
    if [[ "$WIFI_PS" == "on" ]]; then
        echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} WiFi Power Save: ${GREEN}Enabled${NC}"
    else
        echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} WiFi Power Save: ${RED}Disabled${NC}"
    fi
else
    echo -e "${WHITE}│${NC} ${GRAY}?${NC} WiFi: ${GRAY}Not detected${NC}"
fi

# USB
USB_AUTO_COUNT=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "auto" || echo "0")
USB_ON_COUNT=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "on" || echo "0")
USB_TOTAL=$((USB_AUTO_COUNT + USB_ON_COUNT))
echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} USB Autosuspend: ${WHITE}${USB_AUTO_COUNT}${NC} auto, ${WHITE}${USB_ON_COUNT}${NC} on ${DIM}(total: $USB_TOTAL)${NC}"

echo -e "${BLUE}└─${NC}"
echo ""

# Log file info
if [[ -f "$LOG_FILE" ]]; then
    LOG_LINES=$(wc -l < "$LOG_FILE")
    LOG_SIZE=$(du -h "$LOG_FILE" | awk '{print $1}')
    echo -e "${DIM}Log: $LOG_FILE ($LOG_LINES lines, $LOG_SIZE)${NC}"
    echo ""
fi

# Action hints
echo -e "${GRAY}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GRAY}Actions:${NC}"
if [[ "$MODE" == "desktop" ]]; then
    echo -e "  ${YELLOW}laptop-mode${NC}  - Switch to laptop mode"
else
    echo -e "  ${YELLOW}desktop-mode${NC} - Switch to desktop mode"
fi
echo -e "  ${YELLOW}m${NC} or ${YELLOW}aliases${NC}  - Open main menu"
echo ""
