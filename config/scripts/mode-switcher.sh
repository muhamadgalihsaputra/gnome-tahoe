#!/usr/bin/env bash
# Mode Switcher - All-in-One Interactive
# Desktop/Laptop mode management in single script

set -eo pipefail

STATE_FILE="$HOME/.config/mode-switcher.state"
LOG_FILE="$HOME/.config/mode-switcher.log"

# Colors - Improved visibility
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}       ${BOLD}MODE SWITCHER${NC} - Desktop/Laptop Configuration        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_current_status() {
    set +e  # Disable exit on error
    # Read current mode
    if [[ -f "$STATE_FILE" ]]; then
        MODE=$(grep "^MODE=" "$STATE_FILE" | cut -d= -f2-)
        TIMESTAMP=$(grep "^TIMESTAMP=" "$STATE_FILE" | cut -d= -f2-)
        
        # Mode badge
        if [[ "$MODE" == "Desktop" ]]; then
            echo -e "${BOLD}Current Mode:${NC} ${MAGENTA}■ DESKTOP${NC} ${DIM}(Docked)${NC}"
        elif [[ "$MODE" == "Laptop" ]]; then
            echo -e "${BOLD}Current Mode:${NC} ${CYAN}■ LAPTOP${NC} ${DIM}(Portable)${NC}"
        else
            echo -e "${BOLD}Current Mode:${NC} ${GRAY}Not configured${NC}"
        fi
        
        [[ -n "${TIMESTAMP:-}" ]] && echo -e "${DIM}Last changed: $TIMESTAMP${NC}"
    else
        echo -e "${YELLOW}⚠ No mode configured yet${NC}"
    fi
    
    # Quick status
    echo ""
    echo -e "${BLUE}┌─ Quick Status${NC}"
    
    # Fingerprint
    FP_STATUS=$(systemctl is-active fprintd.service 2>/dev/null || echo "inactive")
    if [[ "$FP_STATUS" == "active" ]]; then
        echo -e "${WHITE}│${NC} ${GREEN}●${NC} Fingerprint: ${GREEN}Enabled${NC}"
    else
        echo -e "${WHITE}│${NC} ${RED}●${NC} Fingerprint: ${RED}Disabled${NC}"
    fi
    
    # Touchpad
    TP_STATUS=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null || echo "unknown")
    if [[ "$TP_STATUS" == "'enabled'" ]]; then
        echo -e "${WHITE}│${NC} ${GREEN}●${NC} Touchpad: ${GREEN}Enabled${NC}"
    else
        echo -e "${WHITE}│${NC} ${RED}●${NC} Touchpad: ${RED}Disabled${NC}"
    fi
    
    # CPU & Platform
    CPU_MAX=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || echo "?")
    PLATFORM=$(powerprofilesctl get 2>/dev/null || echo "unknown")
    TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "?")
    if [[ "$TURBO" == "0" ]]; then
        TURBO_STATUS="${GREEN}ON${NC}"
    elif [[ "$TURBO" == "1" ]]; then
        TURBO_STATUS="${RED}OFF${NC}"
    else
        TURBO_STATUS="${GRAY}N/A${NC}"
    fi
    echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} CPU: ${WHITE}${CPU_MAX}%${NC}, Turbo: $TURBO_STATUS, Platform: ${WHITE}$PLATFORM${NC}"
    
    # Battery
    BAT_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo "N/A")
    BAT_STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "N/A")
    BAT_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "N/A")
    echo -e "${WHITE}│${NC} ${YELLOW}◆${NC} Battery: ${WHITE}${BAT_CAPACITY}%${NC}, Limit: ${WHITE}${BAT_START}-${BAT_STOP}%${NC}"
    
    echo -e "${BLUE}└─${NC}"
    echo ""
    set -e  # Re-enable exit on error
}

show_menu() {
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Main Menu:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC} - ${BOLD}Desktop Mode${NC} ${DIM}(Docked workstation)${NC}"
    echo -e "  ${CYAN}2${NC} - ${BOLD}Laptop Mode${NC}  ${DIM}(Portable usage)${NC}"
    echo -e "  ${YELLOW}3${NC} - ${BOLD}Status${NC}"
    echo ""
    echo -e "  ${MAGENTA}0${NC} - Exit"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
}

show_desktop_submenu() {
    clear
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}  ${BOLD}DESKTOP MODE - Select Profile${NC}         ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC} - Max Performance"
    echo -e "      CPU: ${GREEN}100%${NC}, WiFi: ${RED}OFF${NC}, USB: ${GREEN}ON${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC} - Balanced Performance"
    echo -e "      CPU: ${YELLOW}90%${NC}, WiFi: ${RED}OFF${NC}, USB: ${GREEN}ON${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC} - Quiet Mode"
    echo -e "      CPU: ${GREEN}100%${NC}, WiFi: ${GREEN}ON${NC}, USB: ${YELLOW}AUTO${NC}"
    echo ""
    echo -e "  ${GRAY}0${NC} - Back"
    echo ""
    echo -n "Select profile: "
}

show_laptop_submenu() {
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}LAPTOP MODE - Select Profile${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}1${NC} - Performance Portable"
    echo -e "      CPU: ${GREEN}100%${NC}, WiFi: ${RED}OFF${NC}, USB: ${GREEN}ON${NC}"
    echo ""
    echo -e "  ${BOLD}2${NC} - Balanced"
    echo -e "      CPU: ${GREEN}100%${NC}, WiFi: ${GREEN}ON${NC}, USB: ${YELLOW}AUTO${NC}"
    echo ""
    echo -e "  ${BOLD}3${NC} - Power Saver"
    echo -e "      CPU: ${YELLOW}90%${NC}, WiFi: ${GREEN}ON${NC}, USB: ${YELLOW}AUTO${NC}"
    echo ""
    echo -e "  ${GRAY}0${NC} - Back"
    echo ""
    echo -n "Select profile: "
}





apply_desktop_mode() {
    set +e  # Disable exit on error
    local profile="${1:-1}"
    local cpu_cap=100
    local wifi_ps="off"
    local usb_mode="on"
    local profile_name="Max Performance"
    
    # Profile settings
    case "$profile" in
        1)
            cpu_cap=100
            wifi_ps="off"
            usb_mode="on"
            profile_name="Max Performance"
            ;;
        2)
            cpu_cap=90
            wifi_ps="off"
            usb_mode="on"
            profile_name="Balanced Performance"
            ;;
        3)
            cpu_cap=100
            wifi_ps="on"
            usb_mode="auto"
            profile_name="Quiet Mode"
            ;;
    esac
    
    clear
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}  ${BOLD}DESKTOP MODE - $profile_name${NC}    ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "========== DESKTOP MODE - $profile_name =========="
    
    echo -e "${CYAN}Applying...${NC}"
    echo ""
    
    # Disable fingerprint
    sudo systemctl stop fprintd.service 2>/dev/null || true
    sudo systemctl mask fprintd.service 2>/dev/null || true
    
    # Disable touchpad
    gsettings set org.gnome.desktop.peripherals.touchpad send-events disabled 2>/dev/null || true
    
    # Set CPU limit
    echo "$cpu_cap" | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct >/dev/null 2>&1 || true
    
    # WiFi power save
    WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
    [[ -n "$WIFI_DEV" ]] && sudo iw dev "$WIFI_DEV" set power_save "$wifi_ps" 2>/dev/null || true
    
    # USB autosuspend
    for device in /sys/bus/usb/devices/*/power/control; do
        [[ -f "$device" ]] && echo "$usb_mode" | sudo tee "$device" >/dev/null 2>&1 || true
    done
    
    sleep 0.5
    
    # Verify
    echo ""
    FP=$(systemctl is-enabled fprintd.service 2>&1 | head -1 | tr -d '\n\r')
    [[ "$FP" == "masked" ]] && echo -e "  ${GREEN}✓${NC} Fingerprint disabled" || echo -e "  ${YELLOW}⚠${NC} Fingerprint: $FP"
    
    TP=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null)
    [[ "$TP" == "'disabled'" ]] && echo -e "  ${GREEN}✓${NC} Touchpad disabled" || echo -e "  ${YELLOW}⚠${NC} Touchpad: $TP"
    
    CPU=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null)
    [[ "$CPU" == "$cpu_cap" ]] && echo -e "  ${GREEN}✓${NC} CPU ${cpu_cap}%" || echo -e "  ${YELLOW}⚠${NC} CPU: $CPU% (expected: $cpu_cap%)"
    
    if [[ -n "$WIFI_DEV" ]]; then
        WIFI_CUR=$(iw dev "$WIFI_DEV" get power_save 2>/dev/null | awk '{print $NF}')
        [[ "$WIFI_CUR" == "$wifi_ps" ]] && echo -e "  ${GREEN}✓${NC} WiFi power save: $wifi_ps" || echo -e "  ${YELLOW}⚠${NC} WiFi: $WIFI_CUR (expected: $wifi_ps)"
    fi
    
    if [[ "$usb_mode" == "on" ]]; then
        USB_ON=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "on")
        echo -e "  ${GREEN}✓${NC} USB: $USB_ON devices responsive"
    else
        USB_AUTO=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "auto")
        echo -e "  ${GREEN}✓${NC} USB: $USB_AUTO devices auto-suspend"
    fi
    
    # Save state
    cat > "$STATE_FILE" <<EOF
MODE=Desktop
PROFILE=$profile_name
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    log "Desktop mode applied: $profile_name"
    
    echo ""
    echo -e "${GREEN}${BOLD}Desktop Mode Applied - $profile_name!${NC}"
    echo -e "  • Fingerprint: ${RED}OFF${NC}"
    echo -e "  • Touchpad: ${RED}OFF${NC}"
    echo -e "  • CPU: ${GREEN}${cpu_cap}%${NC}"
    [[ "$wifi_ps" == "off" ]] && echo -e "  • WiFi: ${GREEN}Responsive${NC} (power save off)" || echo -e "  • WiFi: ${YELLOW}Power Save ON${NC}"
    [[ "$usb_mode" == "on" ]] && echo -e "  • USB: ${GREEN}Responsive${NC} (no delay)" || echo -e "  • USB: ${YELLOW}Auto-suspend${NC}"
    echo ""
    echo -e "${DIM}Press Enter to continue...${NC}"
    read
    set -e  # Re-enable exit on error
}

apply_laptop_mode() {
    set +e  # Disable exit on error
    local profile="${1:-2}"
    local cpu_cap=100
    local wifi_ps="on"
    local usb_mode="auto"
    local profile_name="Balanced"
    
    # Profile settings
    case "$profile" in
        1)
            cpu_cap=100
            wifi_ps="off"
            usb_mode="on"
            profile_name="Performance Portable"
            ;;
        2)
            cpu_cap=100
            wifi_ps="on"
            usb_mode="auto"
            profile_name="Balanced"
            ;;
        3)
            cpu_cap=90
            wifi_ps="on"
            usb_mode="auto"
            profile_name="Power Saver"
            ;;
    esac
    
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}LAPTOP MODE - $profile_name${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "========== LAPTOP MODE - $profile_name =========="
    
    echo -e "${CYAN}Applying...${NC}"
    echo ""
    
    # Enable fingerprint
    sudo systemctl unmask fprintd.service 2>/dev/null || true
    sudo systemctl start fprintd.service 2>/dev/null || true
    
    # Enable touchpad
    gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled 2>/dev/null || true
    
    # Set CPU limit
    echo "$cpu_cap" | sudo tee /sys/devices/system/cpu/intel_pstate/max_perf_pct >/dev/null 2>&1 || true
    
    # WiFi power save
    WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
    [[ -n "$WIFI_DEV" ]] && sudo iw dev "$WIFI_DEV" set power_save "$wifi_ps" 2>/dev/null || true
    
    # USB autosuspend
    for device in /sys/bus/usb/devices/*/power/control; do
        [[ -f "$device" ]] && echo "$usb_mode" | sudo tee "$device" >/dev/null 2>&1 || true
    done
    
    sleep 0.5
    
    # Verify
    echo ""
    FP=$(systemctl is-active fprintd.service 2>&1 | head -1 | tr -d '\n\r')
    [[ "$FP" == "active" ]] && echo -e "  ${GREEN}✓${NC} Fingerprint enabled" || echo -e "  ${YELLOW}⚠${NC} Fingerprint: $FP"
    
    TP=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null)
    [[ "$TP" == "'enabled'" ]] && echo -e "  ${GREEN}✓${NC} Touchpad enabled" || echo -e "  ${YELLOW}⚠${NC} Touchpad: $TP"
    
    CPU=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null)
    [[ "$CPU" == "$cpu_cap" ]] && echo -e "  ${GREEN}✓${NC} CPU ${cpu_cap}%" || echo -e "  ${YELLOW}⚠${NC} CPU: $CPU% (expected: $cpu_cap%)"
    
    if [[ -n "$WIFI_DEV" ]]; then
        WIFI_CUR=$(iw dev "$WIFI_DEV" get power_save 2>/dev/null | awk '{print $NF}')
        [[ "$WIFI_CUR" == "$wifi_ps" ]] && echo -e "  ${GREEN}✓${NC} WiFi power save: $wifi_ps" || echo -e "  ${YELLOW}⚠${NC} WiFi: $WIFI_CUR (expected: $wifi_ps)"
    fi
    
    if [[ "$usb_mode" == "on" ]]; then
        USB_ON=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "on")
        echo -e "  ${GREEN}✓${NC} USB: $USB_ON devices responsive"
    else
        USB_AUTO=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "auto")
        echo -e "  ${GREEN}✓${NC} USB: $USB_AUTO devices auto-suspend"
    fi
    
    # Save state
    cat > "$STATE_FILE" <<EOF
MODE=Laptop
PROFILE=$profile_name
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    log "Laptop mode applied: $profile_name"
    
    echo ""
    echo -e "${GREEN}${BOLD}Laptop Mode Applied - $profile_name!${NC}"
    echo -e "  • Fingerprint: ${GREEN}ON${NC}"
    echo -e "  • Touchpad: ${GREEN}ON${NC}"
    echo -e "  • CPU: ${GREEN}${cpu_cap}%${NC}"
    [[ "$wifi_ps" == "off" ]] && echo -e "  • WiFi: ${GREEN}Responsive${NC} (power save off)" || echo -e "  • WiFi: ${YELLOW}Power Save ON${NC}"
    [[ "$usb_mode" == "on" ]] && echo -e "  • USB: ${GREEN}Responsive${NC} (no delay)" || echo -e "  • USB: ${YELLOW}Auto-suspend${NC}"
    echo ""
    echo -e "${DIM}Press Enter to continue...${NC}"
    read
    set -e  # Re-enable exit on error
}

show_detailed_status() {
    set +e  # Disable exit on error for this function
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}            ${BOLD}DETAILED SYSTEM STATUS${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Current mode
    if [[ -f "$STATE_FILE" ]]; then
        MODE=$(grep "^MODE=" "$STATE_FILE" | cut -d= -f2-)
        TIMESTAMP=$(grep "^TIMESTAMP=" "$STATE_FILE" | cut -d= -f2-)
        if [[ "$MODE" == "Desktop" ]]; then
            echo -e "${BOLD}Current Mode:${NC} ${MAGENTA}DESKTOP${NC}"
        elif [[ "$MODE" == "Laptop" ]]; then
            echo -e "${BOLD}Current Mode:${NC} ${CYAN}LAPTOP${NC}"
        else
            echo -e "${BOLD}Current Mode:${NC} ${YELLOW}$MODE${NC}"
        fi
        [[ -n "${TIMESTAMP:-}" ]] && echo -e "${WHITE}Activated:${NC} ${GRAY}$TIMESTAMP${NC}"
    else
        echo -e "${YELLOW}No mode configured${NC}"
    fi
    echo ""
    
    # Hardware
    echo -e "${BLUE}┌─ Hardware Configuration${NC}"
    
    FP_ENABLED=$(systemctl is-enabled fprintd.service 2>&1 | head -1)
    FP_ACTIVE=$(systemctl is-active fprintd.service 2>&1 | head -1)
    echo -e "${WHITE}│${NC} Fingerprint: ${WHITE}$FP_ENABLED${NC} / ${WHITE}$FP_ACTIVE${NC}"
    
    TP=$(gsettings get org.gnome.desktop.peripherals.touchpad send-events 2>/dev/null)
    echo -e "${WHITE}│${NC} Touchpad: ${WHITE}$TP${NC}"
    
    MONITORS=$(xrandr --listmonitors 2>/dev/null | grep -c "^ " || echo "0")
    LID=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}' || echo "unknown")
    echo -e "${WHITE}│${NC} Displays: ${WHITE}$MONITORS${NC}, Lid: ${WHITE}$LID${NC}"
    
    echo -e "${BLUE}└─${NC}"
    echo ""
    
    # Performance
    echo -e "${BLUE}┌─ Performance Settings${NC}"
    
    CPU_MAX=$(cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null)
    echo -e "${WHITE}│${NC} CPU Limit: ${WHITE}${CPU_MAX}%${NC}"
    
    TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
    if [[ "$TURBO" == "0" ]]; then
        echo -e "${WHITE}│${NC} Turbo Boost: ${GREEN}ON${NC} ${DIM}(max performance)${NC}"
    elif [[ "$TURBO" == "1" ]]; then
        echo -e "${WHITE}│${NC} Turbo Boost: ${RED}OFF${NC} ${DIM}(kernel parameter)${NC}"
    else
        echo -e "${WHITE}│${NC} Turbo Boost: ${GRAY}N/A${NC}"
    fi
    
    PLATFORM=$(powerprofilesctl get 2>/dev/null || echo "unknown")
    echo -e "${WHITE}│${NC} Power Profile: ${WHITE}$PLATFORM${NC} ${DIM}(GNOME Settings)${NC}"
    
    WIFI_DEV=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
    if [[ -n "$WIFI_DEV" ]]; then
        WIFI_PS=$(iw dev "$WIFI_DEV" get power_save 2>/dev/null | awk '{print $NF}')
        echo -e "${WHITE}│${NC} WiFi Power Save: ${WHITE}$WIFI_PS${NC}"
    fi
    
    USB_AUTO=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "auto")
    USB_ON=$(find /sys/bus/usb/devices/*/power/control -type f -exec cat {} \; 2>/dev/null | grep -c "on")
    echo -e "${WHITE}│${NC} USB: ${WHITE}${USB_AUTO}${NC} auto, ${WHITE}${USB_ON}${NC} on"
    
    echo -e "${BLUE}└─${NC}"
    echo ""
    
    # Battery
    echo -e "${BLUE}┌─ Battery Information${NC}"
    
    BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    BAT_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    echo -e "${WHITE}│${NC} Battery: ${WHITE}${BAT_CAPACITY}%${NC} ${DIM}($BAT_STATUS)${NC}"
    
    BAT_START=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null)
    BAT_STOP=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)
    echo -e "${WHITE}│${NC} Charge Limit: ${WHITE}${BAT_START}-${BAT_STOP}%${NC}"
    
    echo -e "${BLUE}└─${NC}"
    echo ""
    
    echo -e "${DIM}Press Enter to return to menu...${NC}"
    read
    set -e  # Re-enable exit on error
}

show_log() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}            ${BOLD}MODE SWITCHER LOG${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${BOLD}Last 20 entries:${NC}"
        echo ""
        tail -20 "$LOG_FILE" | while IFS= read -r line; do
            echo -e "${GRAY}$line${NC}"
        done
        echo ""
        LOG_SIZE=$(du -h "$LOG_FILE" | awk '{print $1}')
        LOG_LINES=$(wc -l < "$LOG_FILE")
        echo -e "${DIM}Log file: $LOG_FILE ($LOG_LINES lines, $LOG_SIZE)${NC}"
    else
        echo -e "${YELLOW}No log file found${NC}"
    fi
    
    echo ""
    echo -e "${DIM}Press Enter to return to menu...${NC}"
    read
}

# Main loop
main() {
    mkdir -p "$HOME/.config"
    
    while true; do
        show_header
        show_current_status
        show_menu
        
        echo -n "Select option: "
        read -r choice
        
        case $choice in
            1)
                show_desktop_submenu
                read -r sub_choice
                case $sub_choice in
                    1|2|3)
                        apply_desktop_mode "$sub_choice"
                        ;;
                    0)
                        continue
                        ;;
                    *)
                        echo ""
                        echo -e "${RED}Invalid option${NC}"
                        sleep 1
                        ;;
                esac
                ;;
            2)
                show_laptop_submenu
                read -r sub_choice
                case $sub_choice in
                    1|2|3)
                        apply_laptop_mode "$sub_choice"
                        ;;
                    0)
                        continue
                        ;;
                    *)
                        echo ""
                        echo -e "${RED}Invalid option${NC}"
                        sleep 1
                        ;;
                esac
                ;;
            3)
                show_detailed_status
                ;;
            0)
                echo ""
                echo -e "${CYAN}Bye!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run
main
