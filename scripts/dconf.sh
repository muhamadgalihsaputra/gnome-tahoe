#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSIONS_DIR="$REPO_ROOT/gnome/dconf/extensions"
DESKTOP_DIR="$REPO_ROOT/gnome/dconf/desktop"

apply_extensions() {
    declare -A dconf_paths=(
        ["openbar@neuromorph"]="/org/gnome/shell/extensions/openbar/"
        ["dynamic-music-pill@andbal"]="/org/gnome/shell/extensions/dynamic-music-pill/"
        ["rainclock@hugo-sants.github.com"]="/org/gnome/shell/extensions/rainclock/"
        ["search-light@icedman.github.com"]="/org/gnome/shell/extensions/search-light/"
        ["quick-settings-avatar@d-go"]="/org/gnome/shell/extensions/quick-settings-avatar/"
        ["app-grid-tuner@m-lab"]="/org/gnome/shell/extensions/app-grid-tuner/"
        ["blur-my-shell@aunetx"]="/org/gnome/shell/extensions/blur-my-shell/"
        ["dash-to-dock@micxgx.gmail.com"]="/org/gnome/shell/extensions/dash-to-dock/"
        ["space-bar@luchrioh"]="/org/gnome/shell/extensions/space-bar/"
        ["just-perfection-desktop@just-perfection"]="/org/gnome/shell/extensions/just-perfection/"
        ["Vitals@CoreCoding.com"]="/org/gnome/shell/extensions/vitals/"
        ["logomenu@aryan_k"]="/org/gnome/shell/extensions/Logo-menu/"
        ["compiz-windows-effect@hermes83.github.com"]="/org/gnome/shell/extensions/com/github/hermes83/compiz-windows-effect/"
        ["desktop-cube@schneegans.github.com"]="/org/gnome/shell/extensions/desktop-cube/"
        ["CoverflowAltTab@palatis.blogspot.com"]="/org/gnome/shell/extensions/coverflowalttab/"
        ["forge@jmmaranan.com"]="/org/gnome/shell/extensions/forge/"
        ["tiling-assistant@leleat-on-github"]="/org/gnome/shell/extensions/tiling-assistant/"
        ["clipboard-indicator@tudmotu.com"]="/org/gnome/shell/extensions/clipboard-indicator/"
        ["user-theme@gnome-shell-extensions.gcampax.github.com"]="/org/gnome/shell/extensions/user-theme/"
        ["arch-update@RaphaelRochet"]="/org/gnome/shell/extensions/arch-update/"
        ["caffeine@patapon.info"]="/org/gnome/shell/extensions/caffeine/"
        ["gsconnect@andyholmes.github.io"]="/org/gnome/shell/extensions/gsconnect/"
        ["gnome-ui-tune@itstime.tech"]="/org/gnome/shell/extensions/gnome-ui-tune/"
        ["cryptogold@makev1ch.github.com"]="/org/gnome/shell/extensions/cryptogold/"
        ["extension-list@tu.berry"]="/org/gnome/shell/extensions/extension-list/"
        ["thinkpad-red-led@juanmagd.dev"]="/org/gnome/shell/extensions/thinkpad-red-led/"
        ["wack-lockscreen-clock@rinzler69-wastaken.github.com"]="/org/gnome/shell/extensions/wack-lockscreen-clock/"
        ["mute-unmute@mcast.gnomext.com"]="/org/gnome/shell/extensions/mute-unmute/"
        ["hanabi-extension@jeffshee.github.io"]="/io/github/jeffshee/hanabi-extension/"
    )

    if ! command -v dconf >/dev/null 2>&1; then
        echo "Error: dconf is not installed."
        exit 1
    fi

    if [[ ! -d "$EXTENSIONS_DIR" ]]; then
        echo "Error: extension configuration directory not found: $EXTENSIONS_DIR"
        exit 1
    fi

    for uuid in "${!dconf_paths[@]}"; do
        config="$EXTENSIONS_DIR/$uuid/config.ini"
        dconf_path="${dconf_paths[$uuid]}"

        if [[ ! -f "$config" ]]; then
            continue
        fi

        echo "[APPLY EXTENSION] $uuid"
        sed "s|@HOME@|$HOME|g" "$config" | dconf load "$dconf_path"
    done
}

apply_desktop() {
    if [[ ! -d "$DESKTOP_DIR" ]]; then
        return
    fi

    if [[ -f "$DESKTOP_DIR/shell.ini" ]]; then
        echo "[APPLY DESKTOP] GNOME shell settings & enabled extensions"
        sed "s|@HOME@|$HOME|g" "$DESKTOP_DIR/shell.ini" | dconf load /org/gnome/shell/
    fi

    if [[ -f "$DESKTOP_DIR/interface.ini" ]]; then
        echo "[APPLY DESKTOP] interface settings"
        sed "s|@HOME@|$HOME|g" "$DESKTOP_DIR/interface.ini" | dconf load /org/gnome/desktop/interface/
    fi

    if [[ -f "$DESKTOP_DIR/wm-preferences.ini" ]]; then
        echo "[APPLY DESKTOP] window manager preferences"
        sed "s|@HOME@|$HOME|g" "$DESKTOP_DIR/wm-preferences.ini" | dconf load /org/gnome/desktop/wm/preferences/
    fi

    if [[ -f "$DESKTOP_DIR/custom-keybindings.ini" ]]; then
        echo "[APPLY DESKTOP] custom keybindings"
        sed "s|@HOME@|$HOME|g" "$DESKTOP_DIR/custom-keybindings.ini" | dconf load /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/
    fi

    if [[ -f "$DESKTOP_DIR/media-keys.ini" ]]; then
        sed "s|@HOME@|$HOME|g" "$DESKTOP_DIR/media-keys.ini" | dconf load /org/gnome/settings-daemon/plugins/media-keys/
    fi
}

apply_all() {
    apply_desktop
    apply_extensions
}

case "${1:-all}" in
    extensions)
        apply_extensions
        ;;
    desktop)
        apply_desktop
        ;;
    all)
        apply_all
        ;;
    *)
        echo "Usage: $0 [extensions|desktop|all]"
        exit 1
        ;;
esac
