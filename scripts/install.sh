#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Deploying personal dotfiles to ~/.config..."
mkdir -p "$HOME/.config/ghostty" \
         "$HOME/.config/fastfetch" \
         "$HOME/.config/btop" \
         "$HOME/.config/cava" \
         "$HOME/.config/gtk-3.0" \
         "$HOME/.config/gtk-4.0"

[[ -d "$REPO_ROOT/config/ghostty" ]] && cp -r "$REPO_ROOT/config/ghostty/"* "$HOME/.config/ghostty/" 2>/dev/null || true
[[ -d "$REPO_ROOT/config/fastfetch" ]] && cp -r "$REPO_ROOT/config/fastfetch/"* "$HOME/.config/fastfetch/" 2>/dev/null || true
[[ -d "$REPO_ROOT/config/btop" ]] && cp -r "$REPO_ROOT/config/btop/"* "$HOME/.config/btop/" 2>/dev/null || true
[[ -d "$REPO_ROOT/config/cava" ]] && cp -r "$REPO_ROOT/config/cava/"* "$HOME/.config/cava/" 2>/dev/null || true
[[ -d "$REPO_ROOT/config/gtk-3.0" ]] && cp -r "$REPO_ROOT/config/gtk-3.0/"* "$HOME/.config/gtk-3.0/" 2>/dev/null || true
[[ -d "$REPO_ROOT/config/gtk-4.0" ]] && cp -r "$REPO_ROOT/config/gtk-4.0/"* "$HOME/.config/gtk-4.0/" 2>/dev/null || true
if [[ -f "$REPO_ROOT/config/gtk-3.0/bookmarks" ]]; then
    sed "s|@HOME@|$HOME|g" "$REPO_ROOT/config/gtk-3.0/bookmarks" > "$HOME/.config/gtk-3.0/bookmarks"
fi
[[ -f "$REPO_ROOT/config/zsh/.zshrc" ]] && cp "$REPO_ROOT/config/zsh/.zshrc" "$HOME/.zshrc"
[[ -f "$REPO_ROOT/config/zsh/.p10k.zsh" ]] && cp "$REPO_ROOT/config/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

echo
echo "==> Deploying wallpapers to ~/Pictures/Wallpapers..."
mkdir -p "$HOME/Pictures/Wallpapers"
if [[ -d "$REPO_ROOT/wallpapers/images" ]]; then
    cp -rn "$REPO_ROOT/wallpapers/images/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
fi

echo
echo "==> Applying GNOME desktop and extension configurations..."
"$REPO_ROOT/scripts/dconf.sh" all

echo
echo "==> Applying theme and background settings..."
if [[ -f "$REPO_ROOT/theme/settings.ini" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "MacTahoe-dark" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name "SF Pro Display Medium 11" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface monospace-font-name "SF Mono 10" 2>/dev/null || true
    gsettings set org.gnome.desktop.wm.preferences button-layout "close,minimize,maximize:" 2>/dev/null || true
fi

if [[ -f "$HOME/Pictures/Wallpapers/ascend.png" ]]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/ascend.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/Pictures/Wallpapers/ascend.png" 2>/dev/null || true
fi

echo
echo "Installation completed successfully! Please restart your GNOME session."
