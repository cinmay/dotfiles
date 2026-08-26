#!/usr/bin/env bash
# Focus-or-launch Obsidian strictly on workspace 13.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
HYPR_DISPATCH="$SCRIPT_DIR/hypr-lua-dispatch"

WS=13
# Covers native + Flatpak class names
CLASS_RE='^(obsidian|md\.obsidian\.Obsidian)$'

# 1) Go to the Notes workspace
"$HYPR_DISPATCH" workspace "$WS"

# 2) If Obsidian already exists on WS 13, focus it
ADDR_ON_WS="$(
  hyprctl -j clients \
    | jq -r --argjson ws "$WS" --arg re "$CLASS_RE" '
        [ .[] | select(.workspace.id == $ws and ((.class // "") | test($re; "i"))) ]
        | sort_by(.focusHistoryID)
        | (.[0].address // empty)
      '
)"

if [ -n "$ADDR_ON_WS" ]; then
  "$HYPR_DISPATCH" focus-window "$ADDR_ON_WS"
  exit 0
fi

# 3) Otherwise, launch Obsidian on WS 13
exec uwsm app -- obsidian -disable-gpu --enable-wayland-ime
