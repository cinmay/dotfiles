#!/usr/bin/env bash
# Always jump to the terminal workspace (6); focus existing terminal there or launch tmux.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/workspace-terminal.sh" 6 tmux new
