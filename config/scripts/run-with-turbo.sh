#!/usr/bin/env bash
set -euo pipefail

# Run any command with Turbo temporarily enabled.
# Usage: run-with-turbo.sh <command> [args...]

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/cpu-turbo.sh"

if [[ $# -eq 0 ]]; then
  echo "Usage: $(basename "$0") <command> [args...]" >&2
  exit 2
fi

with_turbo "$@"

