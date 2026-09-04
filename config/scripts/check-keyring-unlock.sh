#!/bin/bash
# Script untuk memastikan keyring ter-unlock

if secret-tool search service any &>/dev/null; then
    echo "✓ Keyring sudah unlocked"
else
    echo "✗ Keyring masih locked, coba unlock dengan:"
    echo "  gnome-keyring-daemon --unlock"
fi
