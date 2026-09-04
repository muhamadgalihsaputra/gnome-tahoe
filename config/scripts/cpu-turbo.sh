#!/usr/bin/env bash
set -euo pipefail

# CPU Turbo/EPP helpers for Intel (intel_pstate)
#
# Provides:
#   - turbo_on:  enable Turbo + dynamic boost (if present), set EPP=balance_performance
#   - turbo_off: disable Turbo, disable dynamic boost, set EPP=power
#   - with_turbo <cmd...>: run command with Turbo ON, then always revert
#
# Optional env:
#   CPU_TURBO_SET_PROFILE=1           # also toggle power-profiles-daemon
#   CPU_TURBO_EXIT_PROFILE=balanced   # profile to restore on exit (balanced|power-saver)

NO_TURBO=/sys/devices/system/cpu/intel_pstate/no_turbo
HWP_BOOST=/sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost
EPP_GLOB=(/sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference)

log() { printf "[cpu-turbo] %s\n" "$*"; }

sys_write() {
  local path="$1"; local val="$2"
  if [[ -e "$path" ]]; then
    printf '%s\n' "$val" | sudo tee "$path" >/dev/null
  fi
}

set_epp() {
  local val="$1"
  for f in "${EPP_GLOB[@]}"; do
    [[ -f "$f" ]] && printf '%s\n' "$val" | sudo tee "$f" >/dev/null || true
  done
}

set_profile() {
  local mode="$1" # performance|balanced|power-saver
  if [[ "${CPU_TURBO_SET_PROFILE:-0}" == "1" ]] && command -v powerprofilesctl >/dev/null 2>&1; then
    case "$mode" in
      performance|balanced|power-saver)
        powerprofilesctl set "$mode" || true ;;
      *) : ;; # ignore
    esac
  fi
}

turbo_on() {
  log "Turbo ON (EPP=balance_performance)"
  sys_write "$NO_TURBO" 0
  [[ -e "$HWP_BOOST" ]] && sys_write "$HWP_BOOST" 1
  set_epp balance_performance
  set_profile performance
}

turbo_off() {
  log "Turbo OFF (EPP=power)"
  sys_write "$NO_TURBO" 1
  [[ -e "$HWP_BOOST" ]] && sys_write "$HWP_BOOST" 0
  set_epp power
  set_profile "${CPU_TURBO_EXIT_PROFILE:-balanced}"
}

with_turbo() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: with_turbo <command> [args...]" >&2
    return 2
  fi
  turbo_on
  # Always revert even if command crashes
  trap 'turbo_off' EXIT INT TERM
  "$@"
}

