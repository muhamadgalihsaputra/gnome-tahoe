#!/usr/bin/env bash
set -Eeuo pipefail

# Arch/Arch-based system updater
# - Prefers paru, then yay, else pacman
# - Updates archlinux-keyring first to avoid signature issues
# - Supports AUR-only or repo-only modes
# - Optional logging to assets/ with --log

usage() {
  cat <<'EOF'
Usage: scripts/update.sh [--aur-only | --repo-only] [--noconfirm] [--log]

Options:
  --aur-only     Update only AUR packages (paru/yay required).
  --repo-only    Update only official repo packages (pacman).
  --noconfirm    Pass --noconfirm to the underlying tool.
  --log          Save a timestamped log to assets/.
  -h, --help     Show this help and exit.

Examples:
  scripts/update.sh --log
  scripts/update.sh --repo-only --noconfirm --log
  scripts/update.sh --aur-only
EOF
}

aur_only=false
repo_only=false
noconfirm=false
enable_log=false

for arg in "$@"; do
  case "$arg" in
    --aur-only) aur_only=true ;;
    --repo-only) repo_only=true ;;
    --noconfirm) noconfirm=true ;;
    --log) enable_log=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

if [[ "$aur_only" == true && "$repo_only" == true ]]; then
  echo "Cannot use --aur-only and --repo-only together." >&2
  exit 2
fi

timestamp() { date +"%Y%m%d-%H%M%S"; }

log_setup() {
  if [[ "$enable_log" == true ]]; then
    mkdir -p assets
    LOGFILE="assets/system-update-$(timestamp).log"
    # shellcheck disable=SC2064
    trap "echo; echo 'Log saved to: ' \"$LOGFILE\"" EXIT
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "Logging to $LOGFILE"
  fi
}

run() { echo "+ $*"; "$@"; }

have() { command -v "$1" >/dev/null 2>&1; }

main() {
  log_setup

  echo "==> Detecting updater..."
  helper=""
  if have paru; then helper="paru"; elif have yay; then helper="yay"; else helper="pacman"; fi
  echo "Using: $helper"

  # Always refresh keyring first to avoid signature errors
  echo "==> Refreshing archlinux-keyring"
  if have sudo; then
    run sudo pacman -Sy --needed archlinux-keyring
  else
    echo "sudo not found; attempting pacman directly (may require root)." >&2
    run pacman -Sy --needed archlinux-keyring
  fi

  nc_flag=()
  if [[ "$noconfirm" == true ]]; then nc_flag=(--noconfirm); fi

  echo "==> Starting system update"
  if [[ "$aur_only" == true ]]; then
    case "$helper" in
      paru) run paru -Sua "${nc_flag[@]}" ;;
      yay)  run yay -Sua  "${nc_flag[@]}" ;;
      *)    echo "No AUR helper (paru/yay) found for --aur-only." >&2; exit 1 ;;
    esac
  elif [[ "$repo_only" == true ]]; then
    if have sudo; then
      run sudo pacman -Syu "${nc_flag[@]}"
    else
      run pacman -Syu "${nc_flag[@]}"
    fi
  else
    case "$helper" in
      paru) run paru -Syu "${nc_flag[@]}" ;;
      yay)  run yay -Syu  "${nc_flag[@]}" ;;
      *)    if have sudo; then run sudo pacman -Syu "${nc_flag[@]}"; else run pacman -Syu "${nc_flag[@]}"; fi ;;
    esac
  fi

  echo "==> Update complete"
  echo "Tip: Reboot if kernel/glibc/systemd updated."
}

main "$@"

