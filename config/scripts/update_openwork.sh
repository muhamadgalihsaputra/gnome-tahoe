#!/bin/bash

REPO="different-ai/openwork"
TEMP_DIR="/tmp/openwork_auto_update"

echo "🔍 Mengecek rilis terbaru di GitHub: $REPO..."

# Ambil URL download .deb terbaru dari API GitHub
# Filter: cari asset yang namanya berakhiran 'amd64.deb' (bukan arm64)
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url" | grep "amd64.deb" | head -n 1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Gagal nemu file .deb amd64 di release terbaru."
    echo "Cek koneksi internet atau mungkin rilisnya belum ada file .deb nya."
    exit 1
fi

VERSION=$(basename "$DOWNLOAD_URL" | grep -oP 'v\d+\.\d+\.\d+' || echo "Latest")
echo "⬇️ Ditemukan versi: $VERSION"
echo "🔗 URL: $DOWNLOAD_URL"

# Konfirmasi User (Opsional, biar gak kaget)
read -p "Gas update sekarang? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Oke, batal update."
    exit 1
fi

# Mulai Proses
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "📥 Downloading..."
wget -q --show-progress "$DOWNLOAD_URL" -O package.deb

echo "📦 Extracting..."
ar x package.deb
tar -xf data.tar.*

echo "🔧 Installing/Updating to /usr..."
sudo cp -r usr/* /usr/

# Fix Sandbox Permission (Standard Electron Arch)
# Kita coba detect path installasinya (biasanya /usr/lib/openwork atau /usr/lib/OpenWork)
INSTALL_PATH=$(find /usr/lib -maxdepth 1 -iname "openwork" -type d | head -n 1)

if [ -n "$INSTALL_PATH" ] && [ -f "$INSTALL_PATH/chrome-sandbox" ]; then
    echo "🔒 Fixing permissions for sandbox at $INSTALL_PATH..."
    sudo chown root:root "$INSTALL_PATH/chrome-sandbox"
    sudo chmod 4755 "$INSTALL_PATH/chrome-sandbox"
fi

# Cleanup
cd ~
rm -rf "$TEMP_DIR"
sudo update-desktop-database

echo "✅ SUKSES! OpenWork udah di-update ke versi terbaru."
