#!/usr/bin/env bash
# Focus-or-launch Obsidian strictly on workspace 13.

set -euo pipefail
WS=13
# Covers native + Flatpak class names
CLASS_RE='^(obsidian|md\.obsidian\.Obsidian)$'

# 1) Go to the Notes workspace
hyprctl dispatch workspace "$WS"

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
  hyprctl dispatch focuswindow "address:$ADDR_ON_WS"
  exit 0
fi

# 3) Otherwise, launch Obsidian on WS 13
exec uwsm app -- obsidian -disable-gpu --enable-wayland-ime
