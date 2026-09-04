#!/usr/bin/env bash

set -euo pipefail

EXTENSIONS=(
    "openbar@neuromorph"
    "dynamic-music-pill@andbal"
    "search-light@icedman.github.com"
    "quick-settings-avatar@d-go"
    "app-grid-tuner@m-lab"
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "space-bar@luchrioh"
    "just-perfection-desktop@just-perfection"
    "Vitals@CoreCoding.com"
    "logomenu@aryan_k"
    "compiz-windows-effect@hermes83.github.com"
    "compiz-alike-magic-lamp-effect@hermes83.github.com"
    "desktop-cube@schneegans.github.com"
    "CoverflowAltTab@palatis.blogspot.com"
    "forge@jmmaranan.com"
    "tiling-assistant@leleat-on-github"
    "clipboard-indicator@tudmotu.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "arch-update@RaphaelRochet"
    "caffeine@patapon.info"
    "gsconnect@andyholmes.github.io"
    "gnome-ui-tune@itstime.tech"
    "rainclock@hugo-sants.github.com"
    "cryptogold@makev1ch.github.com"
    "extension-list@tu.berry"
    "mute-unmute@mcast.gnomext.com"
    "thinkpad-red-led@juanmagd.dev"
    "wack-lockscreen-clock@rinzler69-wastaken.github.com"
)

DOWNLOAD_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$DOWNLOAD_DIR"
}

trap cleanup EXIT

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: '$1' is required."
        exit 1
    fi
}

is_installed() {
    local uuid="$1"
    gnome-extensions list | grep -Fxq "$uuid"
}

get_shell_version() {
    gnome-shell --version | grep -oE '[0-9]+' | head -1
}

get_extension_versions() {
    local uuid="$1"
    curl -fsSL "https://extensions.gnome.org/api/v1/extensions/${uuid}/versions/?page=1&page_size=100" || true
}

find_compatible_version() {
    local json="$1"
    local shell_version="$2"

    jq -r --arg shell_version "$shell_version" '
        [
            .results[]
            | select(.status == 2 or .status == 3)
            | select(
                any(
                    .shell_versions[];
                    (.major | tostring) == $shell_version
                )
            )
            | .version
        ]
        | max // empty
    ' <<< "$json"
}

find_latest_version() {
    local json="$1"
    jq -r '
        [
            .results[]
            | select(.status == 2 or .status == 3)
            | .version
        ]
        | max // empty
    ' <<< "$json"
}

download_extension() {
    local uuid="$1"
    local version="$2"
    local output="$3"

    curl \
        --fail \
        --location \
        --silent \
        --show-error \
        -H 'Accept: application/zip' \
        -o "$output" \
        "https://extensions.gnome.org/api/v1/extensions/${uuid}/versions/${version}/?format=zip"
}

install_extension() {
    local uuid="$1"
    local shell_version="$2"

    local json
    local version
    local package_file

    if is_installed "$uuid"; then
        echo "[SKIP] $uuid already installed"
        return 0
    fi

    echo "[CHECK] $uuid"

    json="$(get_extension_versions "$uuid")"

    if [[ -z "$json" ]]; then
        echo "[FAIL] Could not retrieve extension information for $uuid"
        return 0
    fi

    version="$(find_compatible_version "$json" "$shell_version")"

    if [[ -z "$version" ]]; then
        echo "[WARN] No officially compatible version found for GNOME $shell_version"
        echo "[FALLBACK] Using latest active version"
        version="$(find_latest_version "$json")"
    fi

    if [[ -z "$version" ]]; then
        echo "[FAIL] No downloadable version found for $uuid"
        return 0
    fi

    package_file="$DOWNLOAD_DIR/${uuid}.zip"

    echo "[DOWNLOAD] $uuid v$version"
    if ! download_extension "$uuid" "$version" "$package_file"; then
        echo "[FAIL] Failed to download $uuid"
        return 0
    fi

    echo "[INSTALL] $uuid v$version"
    gnome-extensions install --force "$package_file" 2>/dev/null || true

    # Ensure shell version compatibility patch if needed
    local target_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    if [[ -f "$target_dir/metadata.json" ]]; then
        python3 -c "
import json
try:
    with open('$target_dir/metadata.json', 'r') as f:
        d = json.load(f)
    if '$shell_version' not in d.get('shell-version', []):
        d.setdefault('shell-version', []).append('$shell_version')
        with open('$target_dir/metadata.json', 'w') as f:
            json.dump(d, f, indent=2)
except Exception:
    pass
" 2>/dev/null || true
    fi

    echo "[OK] $uuid"
}

main() {
    require_command curl
    require_command jq
    require_command gnome-extensions
    require_command gnome-shell

    local shell_version
    shell_version="$(get_shell_version)"

    echo "GNOME Shell version: $shell_version"
    echo

    for uuid in "${EXTENSIONS[@]}"; do
        install_extension "$uuid" "$shell_version"
    done

    # Deploy local custom extensions (MCP bridges, custom tools)
    local repo_root
    repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    if [[ -d "$repo_root/gnome/extensions/local" ]]; then
        echo
        echo "Installing local bundled extensions..."
        mkdir -p "$HOME/.local/share/gnome-shell/extensions"
        cp -r "$repo_root/gnome/extensions/local/"* "$HOME/.local/share/gnome-shell/extensions/" 2>/dev/null || true
    fi

    echo
    echo "Extension installation completed."
    echo "Please restart or re-login your GNOME session."
}

main "$@"
