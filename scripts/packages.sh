#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_FILE="$REPO_ROOT/packages.txt"

if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
elif command -v pacman >/dev/null 2>&1; then
    AUR_HELPER="sudo pacman"
else
    echo "Error: Neither paru, yay, nor pacman found."
    exit 1
fi

if [[ ! -f "$PACKAGE_FILE" ]]; then
    echo "Error: packages.txt not found: $PACKAGE_FILE"
    exit 1
fi

mapfile -t packages < <(
    grep -vE '^[[:space:]]*(#|$)' "$PACKAGE_FILE"
)

if [[ "${#packages[@]}" -eq 0 ]]; then
    echo "No packages found."
    exit 0
fi

echo "Installing packages with $AUR_HELPER:"
printf '  %s\n' "${packages[@]}"
echo

$AUR_HELPER -S --needed "${packages[@]}"
