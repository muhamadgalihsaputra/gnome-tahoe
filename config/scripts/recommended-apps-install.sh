#!/bin/bash

# Top Recommended Open Source Apps Installation Script
# Run with: bash recommended-apps-install.sh

echo "🚀 Installing Top Recommended Open Source Apps..."
echo "================================================"

# Development
echo -e "\n📝 Development Tools:"
echo "Installing VSCodium (Open source VSCode)..."
paru -S --noconfirm vscodium-bin

echo "Installing Neovim (Modern Vim)..."
paru -S --noconfirm neovim

# Productivity
echo -e "\n📚 Productivity:"
echo "Installing Obsidian (Knowledge management)..."
paru -S --noconfirm obsidian

# Creative
echo -e "\n🎨 Creative Tools:"
echo "Installing Krita (Digital painting)..."
paru -S --noconfirm krita

echo "Installing Inkscape (Vector graphics)..."
paru -S --noconfirm inkscape

# Media
echo -e "\n🎬 Media:"
echo "Installing MPV (Best video player)..."
paru -S --noconfirm mpv

echo "Installing OBS Studio (Recording/Streaming)..."
paru -S --noconfirm obs-studio

# System Tools
echo -e "\n🔧 System Tools:"
echo "Installing Btop (System monitor)..."
paru -S --noconfirm btop

echo "Installing Alacritty (GPU terminal)..."
paru -S --noconfirm alacritty

# Internet
echo -e "\n🌐 Internet:"
echo "Installing Brave Browser..."
paru -S --noconfirm brave-bin

echo -e "\n✅ Installation Complete!"
echo "================================================"
echo "Installed apps:"
echo "  • VSCodium - Code editor"
echo "  • Neovim - Terminal editor"
echo "  • Obsidian - Note-taking"
echo "  • Krita - Digital art"
echo "  • Inkscape - Vector graphics"
echo "  • MPV - Media player"
echo "  • OBS Studio - Recording"
echo "  • Btop - System monitor"
echo "  • Alacritty - Terminal"
echo "  • Brave - Browser"
