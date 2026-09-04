#!/bin/bash
DIR=~/dotfiles
REMOTE=galycloud:dotfiles-backup

case "$1" in
  backup)
    echo "[+] Backing up dotfiles to OneDrive..."
    rclone sync "$DIR" "$REMOTE" --progress
    ;;
  restore)
    echo "[!] Restoring dotfiles from OneDrive..."
    rclone sync "$REMOTE" "$DIR" --progress
    ;;
  *)
    echo "Usage: $0 {backup|restore}"
    exit 1
    ;;
esac
