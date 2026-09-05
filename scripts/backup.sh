#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Backing up GNOME configuration and dotfiles..."
echo "Destination: $REPO_ROOT"
echo

# 1. Backup app configs
mkdir -p "$REPO_ROOT/config/ghostty" \
         "$REPO_ROOT/config/fastfetch" \
         "$REPO_ROOT/config/btop" \
         "$REPO_ROOT/config/cava" \
         "$REPO_ROOT/config/zsh" \
         "$REPO_ROOT/config/gtk-3.0" \
         "$REPO_ROOT/config/gtk-4.0"

[[ -d "$HOME/.config/ghostty" ]] && cp -r "$HOME/.config/ghostty/"* "$REPO_ROOT/config/ghostty/" 2>/dev/null || true
[[ -d "$HOME/.config/fastfetch" ]] && cp -r "$HOME/.config/fastfetch/"* "$REPO_ROOT/config/fastfetch/" 2>/dev/null || true
[[ -d "$HOME/.config/btop" ]] && cp -r "$HOME/.config/btop/"* "$REPO_ROOT/config/btop/" 2>/dev/null || true
[[ -d "$HOME/.config/cava" ]] && cp -r "$HOME/.config/cava/"* "$REPO_ROOT/config/cava/" 2>/dev/null || true
[[ -d "$HOME/.config/gtk-3.0" ]] && cp -r "$HOME/.config/gtk-3.0/"* "$REPO_ROOT/config/gtk-3.0/" 2>/dev/null || true
[[ -d "$HOME/.config/gtk-4.0" ]] && cp -r "$HOME/.config/gtk-4.0/"* "$REPO_ROOT/config/gtk-4.0/" 2>/dev/null || true

# Sanitize bookmarks and zshrc to avoid hardcoded user home paths
if [[ -f "$HOME/.config/gtk-3.0/bookmarks" ]]; then
    sed "s|$HOME|@HOME@|g" "$HOME/.config/gtk-3.0/bookmarks" > "$REPO_ROOT/config/gtk-3.0/bookmarks"
fi
if [[ -f "$HOME/.zshrc" ]]; then
    sed -e "s|$HOME|\$HOME|g" \
        -e 's|FORG_KEY=sk-[a-zA-Z0-9-]*|FORG_KEY="${FORG_KEY:-}"|g' \
        -e '/export [A-Z0-9_]*API_KEY="[a-zA-Z0-9_-]*"/d' \
        "$HOME/.zshrc" > "$REPO_ROOT/config/zsh/.zshrc"
fi
[[ -f "$HOME/.p10k.zsh" ]] && cp "$HOME/.p10k.zsh" "$REPO_ROOT/config/zsh/.p10k.zsh"

# 2. Backup dconf extensions
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

EXT_DIR="$REPO_ROOT/gnome/dconf/extensions"
mkdir -p "$EXT_DIR"

for uuid in "${!dconf_paths[@]}"; do
    path="${dconf_paths[$uuid]}"
    out_file="$EXT_DIR/$uuid/config.ini"
    mkdir -p "$(dirname "$out_file")"
    content="$(dconf dump "$path" 2>/dev/null | sed "s|$HOME|@HOME@|g" || true)"
    if [[ -n "$content" ]]; then
        printf '%s\n' "$content" > "$out_file"
        echo "[DCONF EXTENSION] $uuid"
    else
        printf '[/]\n' > "$out_file"
    fi
done

# 3. Backup desktop settings
DESKTOP_DIR="$REPO_ROOT/gnome/dconf/desktop"
mkdir -p "$DESKTOP_DIR"

echo "[DCONF DESKTOP] shell settings & enabled extensions"
dconf dump /org/gnome/shell/ | sed -n '1,/^\[extensions\//p' | head -n -1 | sed "s|$HOME|@HOME@|g" > "$DESKTOP_DIR/shell.ini"

dconf dump /org/gnome/desktop/interface/ | sed "s|$HOME|@HOME@|g" > "$DESKTOP_DIR/interface.ini"
dconf dump /org/gnome/desktop/wm/preferences/ | sed "s|$HOME|@HOME@|g" > "$DESKTOP_DIR/wm-preferences.ini"
dconf dump /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ | sed "s|$HOME|@HOME@|g" > "$DESKTOP_DIR/custom-keybindings.ini"
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ | sed "s|$HOME|@HOME@|g" > "$DESKTOP_DIR/media-keys.ini"

# 4. Backup & Merge Wallpapers
if [[ -d "$HOME/Pictures/Wallpapers" ]]; then
    echo "Merging wallpapers from ~/Pictures/Wallpapers to repo..."
    mkdir -p "$REPO_ROOT/wallpapers/images"
    cp -rn "$HOME/Pictures/Wallpapers/"* "$REPO_ROOT/wallpapers/images/" 2>/dev/null || true
fi

# 5. Backup theme info
THEME_FILE="$REPO_ROOT/theme/settings.ini"
mkdir -p "$REPO_ROOT/theme"
{
    printf '[theme]\n'
    printf 'gtk-theme=%s\n' "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")"
    printf 'icon-theme=%s\n' "$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
    printf 'cursor-theme=%s\n' "$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")"
    printf 'cursor-size=%s\n' "$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)"
    printf 'font-name=%s\n' "$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'")"
    printf 'color-scheme=%s\n' "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")"
    printf 'button-layout=%s\n' "$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null | tr -d "'")"
} > "$THEME_FILE"

echo
echo "Backup completed successfully."
