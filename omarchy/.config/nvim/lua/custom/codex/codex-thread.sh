#!/usr/bin/env bash
set -euo pipefail

if ! command -v codex >/dev/null 2>&1; then
  echo "codex not found in PATH" >&2
  exit 127
fi

codex "$@"
