#!/usr/bin/env bash
# Always jump to the git workspace (15); focus existing terminal there or launch one.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/workspace-terminal.sh" 15
