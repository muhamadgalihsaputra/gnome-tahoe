# Solid Shadow — Personal GNOME Rice

Personal CachyOS (Arch Linux) GNOME dotfiles and desktop rice configuration focused on modern macOS-inspired ergonomics, modular top bar islands, shell customizations, and automated dconf backup routines.

## Overview & Highlights

- **Desktop Shell:** GNOME 50 (Wayland) with `MacTahoe-Dark` styling and San Francisco typography (`SF Pro Display` & `SF Mono`).
- **Top Panel:** Floating pill capsules (`Islands`) with dark translucent background, border outline, and solid drop shadow via OpenBar.
- **Widgets:**
  - Dynamic Music Pill with live audio visualizer and playback controls.
  - Rain Clock desktop clock widget with customizable typography.
  - Search Light (macOS Spotlight-style floating application search).
- **Window Management & FX:**
  - Compiz wobbly windows & Magic Lamp (Genie) minimize effects.
  - CoverflowAltTab & 3D Desktop Cube.
  - Tiling support with Forge and Tiling Assistant.
- **Custom Tooling:**
  - [HyprQuickPaper GNOME](https://github.com/muhamadgalihsaputra/hyprquickpaper-gnome) wallpaper picker (`<Super><Alt>w`).
  - Terminal: Ghostty with SF Mono.
  - Shell: Zsh with Powerlevel10k and Fastfetch system branding.

## Screenshots

| | |
|---|---|
| ![Desktop 01](asserts/screenshots/desktop/desktop-01.png) | ![Desktop 02](asserts/screenshots/desktop/desktop-02.png) |
| ![Desktop 03](asserts/screenshots/desktop/desktop-03.png) | ![Desktop 04](asserts/screenshots/desktop/desktop-04.png) |
| ![Application 01](asserts/screenshots/application/application-01.png) | ![Application 02](asserts/screenshots/application/application-02.png) |

## Documentation

- [Theme & Typography](theme/THEME.md)
- [GNOME Extensions](gnome/EXTENSIONS.md)
- [Wallpapers](wallpapers/WALLPAPERS.md)

## Usage & Installation

### 1. Install Packages (Arch / CachyOS)
```bash
make packages
```

### 2. Install GNOME Extensions
```bash
make install-extensions
```
> [!IMPORTANT]
> Log out and log back in to your GNOME session after installing extensions.

### 3. Deploy Dotfiles & Apply Settings
Deploys configuration files to `~/.config` and applies all tracked GNOME desktop & extension settings via dconf:
```bash
make install
```

### 4. Backup Current System State
Dumps active GNOME configurations and dotfiles back into this repository:
```bash
make backup
```

### 5. Reapply Dconf Settings Only
```bash
make dconf
```
