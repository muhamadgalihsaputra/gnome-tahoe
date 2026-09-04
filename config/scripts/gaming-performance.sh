#!/usr/bin/env bash
set -euo pipefail

# Colors
if command -v tput >/dev/null 2>&1; then
  t_reset="$(tput sgr0)"; t_bold="$(tput bold)"; t_red="$(tput setaf 1)"; t_green="$(tput setaf 2)"; t_yellow="$(tput setaf 3)"; t_blue="$(tput setaf 4)"; t_mag="$(tput setaf 5)"; t_cyan="$(tput setaf 6)"; t_white="$(tput setaf 7)";
else
  t_reset=""; t_bold=""; t_red=""; t_green=""; t_yellow=""; t_blue=""; t_mag=""; t_cyan=""; t_white="";
fi

banner() {
  printf "%s\n" "${t_cyan}${t_bold}┌──────────────────────────────────────────────┐${t_reset}"
  printf "%s\n" "${t_cyan}${t_bold}│${t_reset}     ${t_mag}${t_bold}GAMING PERFORMANCE TOOLKIT${t_reset}        ${t_cyan}${t_bold}│${t_reset}"
  printf "%s\n" "${t_cyan}${t_bold}└──────────────────────────────────────────────┘${t_reset}"
}

need_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "${t_red}Missing dependency: jq. Install with: sudo pacman -S jq${t_reset}"
    read -rp "Press Enter..." _
    return 1
  fi
}

need_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo "$0" "$@"; exit $?
    else
      echo "${t_red}This action requires root (sudo).${t_reset}"; return 1
    fi
  fi
}

show_status() {
  banner
  echo "${t_bold}System Status${t_reset}"
  prof=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo n/a)
  gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)
  epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo n/a)
  turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo n/a)
  gmstat=$(systemctl --user is-active gamemoded 2>/dev/null || true); gmstat=${gmstat:-unknown}
  echo "- Power profile: ${t_green}${prof}${t_reset}"
  echo "- Governor: ${t_green}${gov}${t_reset} | EPP: ${t_green}${epp}${t_reset} | Turbo off? ${t_green}${turbo}${t_reset}"
  echo "- GameMode: ${t_green}${gmstat}${t_reset}"
  echo "- MangoHud: $(command -v mangohud >/dev/null && echo enabled || echo not installed)"
  echo "- DXVK env: $(env | grep -q '^DXVK_' && echo present || echo none)"
  echo
  echo "${t_bold}USB Gamepads${t_reset} (autosuspend):"
  find /sys/bus/usb/devices -maxdepth 2 -type f -name idVendor 2>/dev/null | while read -r v; do
    vp=$(dirname "$v"); ven=$(cat "$vp/idVendor" 2>/dev/null); pro=$(cat "$vp/idProduct" 2>/dev/null)
    [ -f "$vp/power/control" ] || continue
    mode=$(cat "$vp/power/control" 2>/dev/null)
    name=$(cat "$vp/product" 2>/dev/null || echo "")
    case "${name}${ven}${pro}" in
      *Gamepad*|*08100001*) printf "- %s (%s:%s) power/control=%s\n" "${name:-usb}" "$ven" "$pro" "$mode";;
      *) :;;
    esac
  done
  echo
  read -rp "Press Enter to go back to menu... " _
}

apply_cpu_profile(){
  mode="$1"
  case "$mode" in
    performance)
      sudo bash -c '
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$f" ] && echo performance > "$f" || true; done
        for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$f" ] && echo performance > "$f" || true; done
        [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo || true
        [ -w /sys/firmware/acpi/platform_profile ] && echo performance > /sys/firmware/acpi/platform_profile || true
      '
      ;;
    balanced)
      sudo bash -c '
        [ -w /sys/firmware/acpi/platform_profile ] && echo balanced > /sys/firmware/acpi/platform_profile || true
      '
      ;;
    powersave)
      sudo bash -c '
        for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$f" ] && echo powersave > "$f" || true; done
        for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$f" ] && echo power > "$f" || true; done
        [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] && echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo || true
        [ -w /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost ] && echo 0 > /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost || true
        [ -w /sys/firmware/acpi/platform_profile ] && echo low-power > /sys/firmware/acpi/platform_profile || true
      '
      ;;
  esac
  echo "${t_green}Applied CPU profile: ${mode}${t_reset}"
  sleep 1
}

cpu_menu(){
  while :; do
    clear; banner
    echo "${t_bold}CPU Profiles${t_reset}"
    echo "1) Performance"
    echo "2) Balanced"
    echo "3) Power Saver"
    echo "4) Back"
    read -rp "> Choose: " c
    case "$c" in
      1) apply_cpu_profile performance;;
      2) apply_cpu_profile balanced;;
      3) apply_cpu_profile powersave;;
      4) break;;
    esac
  done
}

heroic_toggle_mangohud(){
  need_jq || return 1
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  [ -f "$cfg" ] || { echo "Missing: $cfg"; read -rp "Enter..." _; return 1; }
  local cur
  cur=$(jq -r '.trWcBpNjc4u2yWyunW1k94.showMangohud // false' "$cfg")
  local next="true"; [ "$cur" = "true" ] && next="false"
  tmp=$(mktemp)
  jq ".trWcBpNjc4u2yWyunW1k94.showMangohud = ${next}" "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  echo "MangoHud -> $next"; read -rp "Enter..." _
}

heroic_toggle_esync(){
  need_jq || return 1
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  [ -f "$cfg" ] || { echo "Missing: $cfg"; read -rp "Enter..." _; return 1; }
  local cur
  cur=$(jq -r '.trWcBpNjc4u2yWyunW1k94.enableEsync // true' "$cfg")
  local next="true"; [ "$cur" = "true" ] && next="false"
  tmp=$(mktemp)
  jq ".trWcBpNjc4u2yWyunW1k94.enableEsync = ${next}" "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  echo "ESYNC -> $next"; read -rp "Enter..." _
}

heroic_toggle_fsync(){
  need_jq || return 1
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  [ -f "$cfg" ] || { echo "Missing: $cfg"; read -rp "Enter..." _; return 1; }
  local cur
  cur=$(jq -r '.trWcBpNjc4u2yWyunW1k94.enableFsync // false' "$cfg")
  local next="true"; [ "$cur" = "true" ] && next="false"
  tmp=$(mktemp)
  jq ".trWcBpNjc4u2yWyunW1k94.enableFsync = ${next}" "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  tmp=$(mktemp)
  if [ "$next" = "true" ]; then
    jq '.trWcBpNjc4u2yWyunW1k94.enviromentOptions |= ( . // [] | map(select(.key != "WINEFSYNC")) + [{"key":"WINEFSYNC","value":"1"}] )' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  else
    jq '.trWcBpNjc4u2yWyunW1k94.enviromentOptions |= ( . // [] | map(select(.key != "WINEFSYNC")) + [{"key":"WINEFSYNC","value":"0"}] )' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  fi
  echo "FSYNC -> $next (WINEFSYNC synced)"; read -rp "Enter..." _
}

heroic_menu(){
  need_jq || return 1
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  while :; do
    clear; banner
    echo "${t_bold}Heroic Quick Toggles${t_reset}"
    if [ -f "$cfg" ]; then
      local mh es fs hud wf
      mh=$(jq -r '.trWcBpNjc4u2yWyunW1k94.showMangohud // false' "$cfg")
      es=$(jq -r '.trWcBpNjc4u2yWyunW1k94.enableEsync // true' "$cfg")
      fs=$(jq -r '.trWcBpNjc4u2yWyunW1k94.enableFsync // false' "$cfg")
      hud=$(jq -r '(.trWcBpNjc4u2yWyunW1k94.enviromentOptions // []) | any(.key=="DXVK_HUD")' "$cfg")
      wf=$(jq -r '(.trWcBpNjc4u2yWyunW1k94.enviromentOptions // []) | map(select(.key=="WINEFSYNC")) | .[0].value // "(n/a)"' "$cfg")
      echo "- MangoHud: $mh | ESYNC: $es | FSYNC: $fs (WINEFSYNC=$wf) | DXVK_HUD: $hud"
    else
      echo "Config not found: $cfg"
    fi
    echo "1) Toggle MangoHud"
    echo "2) Toggle ESYNC"
    echo "3) Toggle FSYNC (sync WINEFSYNC)"
    echo "4) Toggle DXVK HUD (Heroic)"
    echo "5) Back"
    read -rp "> Choose: " c
    case "$c" in
      1) heroic_toggle_mangohud;;
      2) heroic_toggle_esync;;
      3) heroic_toggle_fsync;;
      4) toggle_dxvk_hud;;
      5) break;;
    esac
  done
}

unapply_preset(){
  banner
  echo "${t_bold}Reverting to Balanced profile...${t_reset}"
  apply_cpu_profile balanced
  echo "${t_green}Balanced profile applied.${t_reset}"
  read -rp "Press Enter..." _
}

create_win32_prefix(){
  need_jq || return 1
  local def="$HOME/Games/Heroic/Prefixes/pes2017_win32"
  read -rp "Target Win32 prefix path [$def]: " p
  p=${p:-$def}
  echo "Creating 32-bit Wine prefix at: $p"
  WINEARCH=win32 WINEPREFIX="$p" wineboot -u || true
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  if [ -f "$cfg" ]; then
    tmp=$(mktemp)
    jq --arg p "$p" '.trWcBpNjc4u2yWyunW1k94.winePrefix=$p' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    echo "${t_green}Heroic switched to win32 prefix${t_reset}"
  else
    echo "${t_yellow}Heroic config not found, prefix created only${t_reset}"
  fi
  read -rp "Press Enter..." _
}

install_cpu_service(){
  banner
  echo "${t_bold}Installing CPU performance systemd service (sudo)${t_reset}"
  printf '%s\n' '#!/bin/sh
set -eu
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$f" ] && echo performance > "$f" || true; done
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$f" ] && echo performance > "$f" || true; done
[ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo || true
if [ -w /sys/firmware/acpi/platform_profile ]; then echo performance > /sys/firmware/acpi/platform_profile || true; fi
exit 0' | sudo tee /usr/local/sbin/cpu-performance.sh >/dev/null
  sudo chmod +x /usr/local/sbin/cpu-performance.sh
  printf '%s\n' '[Unit]
Description=Set CPU governor and EPP to performance
After=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cpu-performance.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/cpu-performance.service >/dev/null
  printf '%s\n' '#!/bin/sh
[ "$1" = "post" ] && /usr/local/sbin/cpu-performance.sh' | sudo tee /usr/lib/systemd/system-sleep/99-cpu-performance >/dev/null
  sudo chmod +x /usr/lib/systemd/system-sleep/99-cpu-performance
  sudo systemctl daemon-reload
  sudo systemctl enable --now cpu-performance.service
  echo "${t_green}Installed and enabled. Reboots/resumes will keep performance.${t_reset}"
  read -rp "Press Enter..." _
}

ensure_gamemode_ini(){
  mkdir -p "$HOME/.config"
  cat > "$HOME/.config/gamemode.ini" << 'GMEOF'
[general]

[cpu]
governor=performance
desiredgov=performance

[header]
version=1
GMEOF
  echo "${t_green}~/.config/gamemode.ini written${t_reset}"
}

gamemode_menu(){
  while :; do
    clear; banner
    stat=$(systemctl --user is-active gamemoded 2>/dev/null || echo unknown)
    echo "${t_bold}GameMode${t_reset} (status: ${stat})"
    echo "1) Start gamemoded (user)"
    echo "2) Stop gamemoded (user)"
    echo "3) Write ~/.config/gamemode.ini (performance)"
    echo "4) Back"
    read -rp "> Choose: " c
    case "$c" in
      1) systemctl --user start gamemoded || true;;
      2) systemctl --user stop gamemoded || true;;
      3) ensure_gamemode_ini;;
      4) break;;
    esac
  done
}

mangohud_menu(){
  while :; do
    clear; banner
    echo "${t_bold}MangoHud${t_reset}"
    echo "1) Create minimal ~/.config/MangoHud/MangoHud.conf"
    echo "2) Show MangoHud version"
    echo "3) Back"
    read -rp "> Choose: " c
    case "$c" in
      1)
        mkdir -p "$HOME/.config/MangoHud"
        cat > "$HOME/.config/MangoHud/MangoHud.conf" << 'MH'
no_display
legacy_layout=0
position=top-left
background_alpha=0.3
font_size=18
fps
frametime
frame_timing=0
MH
        echo "${t_green}MangoHud.conf written${t_reset}"
        ;;
      2) mangohud --version || echo "MangoHud not found";;
      3) break;;
    esac
  done
}

write_dxvk_conf(){
  dir="$1"
  mkdir -p "$dir"
  cat > "$dir/dxvk.conf" << 'DXVK'
# DXVK performance template
d3d9.maxFrameLatency = 1
d3d9.presentInterval = 0
# Keep shader compiler threads conservative for ULV CPUs
dxvk.numCompilerThreads = 2
DXVK
  echo "${t_green}dxvk.conf written to ${dir}${t_reset}"
}

dxvk_menu(){
  while :; do
    clear; banner
    echo "${t_bold}DXVK Config${t_reset}"
    echo "1) Write dxvk.conf to a directory"
    echo "2) Back"
    read -rp "> Choose: " c
    case "$c" in
      1)
        read -rp "Target directory (absolute path): " d
        [ -n "$d" ] && write_dxvk_conf "$d"
        ;;
      2) break;;
    esac
  done
}

install_heroic_hooks(){
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  local before="$HOME/scripts/gaming-before.sh"
  local after="$HOME/scripts/gaming-after.sh"
  # Write before script (performance profile + start gamemode)
  mkdir -p "$HOME/scripts"
  cat > "$before" << 'BEOF'
#!/usr/bin/env bash
set -euo pipefail
# Pre-game: switch to Performance via platform_profile
[ -w /sys/firmware/acpi/platform_profile ] && echo performance | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
systemctl --user start gamemoded 2>/dev/null || true
# Ensure DXVK state cache path exists if configured
mkdir -p "$HOME/Games/Heroic/EA FC 25 NEW UPDATE" 2>/dev/null || true
BEOF
  chmod +x "$before"
  # Write after script (revert to balanced)
  cat > "$after" << 'AEOF'
#!/usr/bin/env bash
set -euo pipefail
# Post-game: return to Balanced via platform_profile
[ -w /sys/firmware/acpi/platform_profile ] && echo balanced | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
AEOF
  chmod +x "$after"
  # Patch Heroic per-game config to use hooks
  if [ -f "$cfg" ]; then
    tmp=$(mktemp)
    jq --arg b "$before" --arg a "$after" '.trWcBpNjc4u2yWyunW1k94.beforeLaunchScriptPath=$b | .trWcBpNjc4u2yWyunW1k94.afterLaunchScriptPath=$a' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    echo "${t_green}Heroic hooks installed${t_reset}"
  else
    echo "${t_yellow}Heroic config not found, scripts created only${t_reset}"
  fi
  read -rp "Press Enter..." _
}

launch_pes2017_auto(){
  banner
  echo "${t_bold}Auto launching PES2017 with perf + revert${t_reset}"
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  local exe="$HOME/Games/Heroic/EA FC 25 NEW UPDATE/PES2017.exe"
  [ -f "$exe" ] || { echo "Missing EXE: $exe"; read -rp "Enter..." _; return 1; }
  if [ ! -f "$cfg" ]; then
    echo "Missing Heroic config: $cfg"; read -rp "Enter..." _; return 1
  fi
  local winebin prefix mh es fs wsrv
  winebin=$(jq -r '.trWcBpNjc4u2yWyunW1k94.wineVersion.bin' "$cfg")
  wsrv=$(jq -r '.trWcBpNjc4u2yWyunW1k94.wineVersion.wineserver // empty' "$cfg")
  prefix=$(jq -r '.trWcBpNjc4u2yWyunW1k94.winePrefix' "$cfg")
  mh=$(jq -r '.trWcBpNjc4u2yWyunW1k94.showMangohud // false' "$cfg")
  es=$(jq -r '.trWcBpNjc4u2yWyunW1k94.enableEsync // true' "$cfg")
  fs=$(jq -r '.trWcBpNjc4u2yWyunW1k94.enableFsync // false' "$cfg")
  # Build env from enviromentOptions
  local envfile; envfile=$(mktemp)
  jq -r '.trWcBpNjc4u2yWyunW1k94.enviromentOptions // [] | .[] | "export \(.key)=\"\(.value)\""' "$cfg" > "$envfile"
  echo 'export WINEGAME=1' >> "$envfile"
  [ "$es" = "true" ] && echo 'export WINEESYNC=1' >> "$envfile" || echo 'export WINEESYNC=0' >> "$envfile"
  [ "$fs" = "true" ] && echo 'export WINEFSYNC=1' >> "$envfile" || echo 'export WINEFSYNC=0' >> "$envfile"
  echo 'export WINE_GAMEPAD=1' >> "$envfile"
  # Pre: switch to Performance via platform_profile
  [ -w /sys/firmware/acpi/platform_profile ] && echo performance | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
  systemctl --user start gamemoded 2>/dev/null || true
  # Compose run command
  local runner=("$winebin" "$exe")
  [ -x "$winebin" ] || runner=("/usr/bin/wine" "$exe")
  local wrapcmd=()
  if [ "$mh" = "true" ] && command -v mangohud >/dev/null 2>&1; then
    wrapcmd+=(/usr/bin/mangohud --dlsym)
  fi
  if command -v gamemoderun >/dev/null 2>&1; then
    wrapcmd+=(/usr/bin/gamemoderun)
  fi
  echo "Using: WINEPREFIX=$prefix ${wrapcmd[*]} ${runner[*]}"
  bash -lc "set -e; source '$envfile'; export WINEPREFIX='$prefix'; ${wrapcmd[*]} ${runner[*]}" || true
  rm -f "$envfile"
  # Post: revert to balanced
  [ -w /sys/firmware/acpi/platform_profile ] && echo balanced | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
  echo "${t_green}Game exited. Restored balanced profile.${t_reset}"
  read -rp "Press Enter..." _
}

toggle_dxvk_hud(){
  need_jq || return 1
  local cfg="$HOME/.config/heroic/GamesConfig/trWcBpNjc4u2yWyunW1k94.json"
  if [ ! -f "$cfg" ]; then
    echo "Config not found: $cfg"
    read -rp "Press Enter..." _; return 1
  fi
  local has
  has=$(jq -r '(.trWcBpNjc4u2yWyunW1k94.enviromentOptions // []) | any(.key=="DXVK_HUD")' "$cfg")
  if [ "$has" = "true" ]; then
    # Remove to toggle off
    tmp=$(mktemp)
    jq '.trWcBpNjc4u2yWyunW1k94.enviromentOptions |= ( . // [] | map(select(.key != "DXVK_HUD")) )' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    echo "${t_yellow}DXVK_HUD: OFF (removed from Heroic config)${t_reset}"
  else
    tmp=$(mktemp)
    jq '.trWcBpNjc4u2yWyunW1k94.enviromentOptions |= ( . // [] ) + [{"key":"DXVK_HUD","value":"fps,frametimes"}]' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    echo "${t_green}DXVK_HUD: ON (fps,frametimes)${t_reset}"
  fi
  read -rp "Press Enter..." _
}

verify_dxvk_logs(){
  local gdir="$HOME/Games/Heroic/EA FC 25 NEW UPDATE"
  echo "Checking DXVK logs in: $gdir"
  local found=0
  for f in "$gdir"/d3d9.log "$gdir"/dxgi.log "$gdir"/d3d11.log; do
    if [ -f "$f" ]; then
      found=1
      echo "--- $f (first 30 lines) ---"
      sed -n '1,30p' "$f"
      echo
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "${t_yellow}No DXVK log files found. If HUD is enabled and still no logs, DXVK may not be loading.${t_reset}"
    echo "Tips: ensure WINEDLLOVERRIDES=d3d9,dxgi,d3d11=n,b and DXVK_LOG_LEVEL>=warn are set in Heroic env."
  fi
  read -rp "Press Enter..." _
}

usage_menu(){
  clear; banner
  echo "${t_bold}Usage & Quickstart${t_reset}"
  echo ""
  echo "${t_bold}- Quick smooth setup (once):${t_reset}"
  echo "  1) 12) Install Heroic Hooks → before/after scripts aktif (perf on when launch, revert on exit)."
  echo "  2) 15) Install CPU Performance Service → jaga governor/EPP/turbo saat boot/resume."
  echo "  3) 6) USB → 3) Install udev rule untuk gamepad (0810:0001), lalu cabut-colok pad."
  echo "  4) 8) Heroic Quick Toggles → ON-kan MangoHud atau 9) DXVK HUD untuk FPS overlay."
  echo ""
  echo "${t_bold}- Tiap mau main (manual):${t_reset}"
  echo "  A) 7) PES2017 Preset (apply all) → CPU perf + GameMode + DXVK conf + USB power on."
  echo "     Lalu jalankan dari Heroic (Hooks akan tetap jalan)."
  echo "  B) Atau 13) Auto Launch PES → Launch + perf + revert otomatis tanpa buka Heroic."
  echo ""
  echo "${t_bold}- Verifikasi DXVK aktif:${t_reset}"
  echo "  • 9) Toggle DXVK HUD, lalu buka game. HUD (FPS/frametime) muncul di kiri atas."
  echo "  • 10) Verify DXVK Active → tampilkan d3d9/dxgi.log jika DXVK memang loading."
  echo "  • Jika tidak muncul, pastikan WINEDLLOVERRIDES d3d9,dxgi,d3d11=n,b ada di Heroic env."
  echo ""
  echo "${t_bold}- Controller stabil (Twin USB Gamepad):${t_reset}"
  echo "  • 6) USB → 2) Set power/control=on now (ulang jika pindah port/boot)."
  echo "  • Gunakan XInput: di Settings.exe pilih \"XInput/360 Controller\" (Controller 2 kosong)."
  echo "  • Rekomendasi: x360ce (32-bit) di folder game untuk mapping ke XInput (taruh x360ce.exe → run via Wine → simpan)."
  echo ""
  echo "${t_bold}- Grafik & animasi:${t_reset}"
  echo "  • dxvk.conf sudah diset (latency rendah, compile konservatif)."
  echo "  • Jika cutscene berat, set 1280×720 + Quality Low/Medium di Settings.exe."
  echo ""
  echo "${t_bold}- WoW64 / Prefix:${t_reset}"
  echo "  • Wine 10.x default pakai WoW64 untuk app 32-bit di prefix 64-bit."
  echo "  • Untuk stabilitas ekstra: 14) Create Win32 Prefix → switch Heroic ke prefix 32-bit."
  echo ""
  echo "${t_bold}- Catatan performa CPU:${t_reset}"
  echo "  • i5-8365U sustain clock 1.8–2.2 GHz saat load 15W itu normal. Overclock CPU laptop tidak realistis."
  echo "  • Toolkit sudah set performance governor/EPP/turbo + GameMode; service persisten tersedia."
  echo ""
  echo "${t_bold}- Troubleshooting:${t_reset}"
  echo "  • Game tidak launch di Proton/UMU → pakai Wine Default 10.x (sudah diset), atau jalankan 13) Auto Launch PES."
  echo "  • FPS overlay tidak muncul → pastikan MangoHud terinstall (mangohud + lib32-mangohud) atau gunakan 9) DXVK HUD."
  echo "  • Pad putus → cek 6) USB, replug pad, dan pastikan rule sudah terpasang."
  echo ""
  read -rp "Press Enter to return... " _
}

pes2017_preset(){
  banner
  echo "${t_bold}Applying PES2017 preset...${t_reset}"
  # 1) CPU performance profile (requires sudo)
  if command -v sudo >/dev/null 2>&1; then
    echo "- Elevating CPU profile to performance"
    sudo bash -c '
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$f" ] && echo performance > "$f" || true; done
      for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$f" ] && echo performance > "$f" || true; done
      [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo || true
      [ -w /sys/firmware/acpi/platform_profile ] && echo performance > /sys/firmware/acpi/platform_profile || true
    '
  fi

  # 2) Ensure GameMode started (user service)
  echo "- Starting GameMode (user)"
  systemctl --user start gamemoded 2>/dev/null || true

  # 3) DXVK config to game dir
  local gdir="$HOME/Games/Heroic/EA FC 25 NEW UPDATE"
  if [ -d "$gdir" ]; then
    echo "- Writing dxvk.conf to game dir"
    write_dxvk_conf "$gdir"
  fi

  # 4) USB gamepad power on now (requires sudo)
  echo "- Forcing USB gamepad power/control=on"
  if command -v sudo >/dev/null 2>&1; then
    # Reuse listing and set power on
    while IFS='|' read -r vp name ven pro; do
      if echo "$name$ven$pro" | grep -qiE '(Gamepad|08100001)'; then
        sudo sh -c "echo on > \"$vp/power/control\"" 2>/dev/null || true
      fi
    done < <(usb_list_gamepads)
  fi

  echo "${t_green}Preset applied. You can launch the game now.${t_reset}"
  read -rp "Press Enter to return... " _
}

usb_list_gamepads(){
  find /sys/bus/usb/devices -maxdepth 2 -type f -name idVendor 2>/dev/null | while read -r v; do
    vp=$(dirname "$v"); ven=$(cat "$vp/idVendor" 2>/dev/null); pro=$(cat "$vp/idProduct" 2>/dev/null)
    [ -f "$vp/power/control" ] || continue
    name=$(cat "$vp/product" 2>/dev/null || echo "")
    printf "%s|%s|%s|%s\n" "$vp" "$name" "$ven" "$pro"
  done
}

usb_power_on_now(){
  any=0
  while IFS='|' read -r vp name ven pro; do
    if echo "$name$ven$pro" | grep -qiE '(Gamepad|08100001)'; then
      sudo sh -c "echo on > '$vp/power/control'" 2>/dev/null && echo "Set power/control=on for $name ($ven:$pro)" && any=1
    fi
  done < <(usb_list_gamepads)
  [ "${any:-0}" = 0 ] && echo "No matching gamepad found (Twin USB or any *Gamepad*)."
}

usb_install_rule(){
  vid="${1:-0810}"; pid="${2:-0001}"
  echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"${vid}\", ATTR{idProduct}==\"${pid}\", TEST==\"power/control\", ATTR{power/control}=\"on\"" | sudo tee /etc/udev/rules.d/99-gamepad-autosuspend.rules >/dev/null
  sudo udevadm control --reload || true
  sudo udevadm trigger || true
  echo "${t_green}udev rule installed for ${vid}:${pid}${t_reset}"
}

usb_menu(){
  while :; do
    clear; banner
    echo "${t_bold}USB Gamepad Autosuspend${t_reset}"
    echo "1) List USB game devices"
    echo "2) Set power/control=on now (match *Gamepad* or 0810:0001)"
    echo "3) Install udev rule for 0810:0001 (Twin USB Gamepad)"
    echo "4) Back"
    read -rp "> Choose: " c
    case "$c" in
      1) usb_list_gamepads | awk -F'|' '{printf "- %s (%s:%s) %s\n", $2,$3,$4,$1}';;
      2) usb_power_on_now;;
      3) usb_install_rule 0810 0001;;
      4) break;;
    esac
  done
}

main_menu(){
  while :; do
    clear; banner
    echo "${t_bold}0) Usage & Quickstart${t_reset}"
    echo "${t_bold}Main Menu${t_reset}"
    echo "1) Status Overview"
    echo "2) CPU Profiles"
    echo "3) GameMode"
    echo "4) MangoHud"
    echo "5) DXVK Config"
    echo "6) USB Gamepad Autosuspend"
    echo "7) PES2017 Preset (apply all)"
    echo "8) Heroic Quick Toggles (HUD/ESYNC/FSYNC)"
    echo "9) Toggle DXVK HUD (Heroic)"
    echo "10) Verify DXVK Active (show logs)"
    echo "11) Unapply Preset (Balanced)"
    echo "12) Install Heroic Hooks (before/after)"
    echo "13) Auto Launch PES (perf+revert)"
    echo "14) Create Win32 Prefix and switch Heroic"
    echo "15) Install CPU Performance Service (persistent)"
    echo "16) Exit"
    read -rp "> Choose: " ans
    case "$ans" in
      0) usage_menu;;
      1) show_status;;
      2) cpu_menu;;
      3) gamemode_menu;;
      4) mangohud_menu;;
      5) dxvk_menu;;
      6) usb_menu;;
      7) pes2017_preset;;
      8) heroic_menu;;
      9) toggle_dxvk_hud;;
      10) verify_dxvk_logs;;
      11) unapply_preset;;
      12) install_heroic_hooks;;
      13) launch_pes2017_auto;;
      14) create_win32_prefix;;
      15) install_cpu_service;;
      16) clear; exit 0;;
    esac
  done
}

main_menu
