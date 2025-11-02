#!/usr/bin/env bash
# Focus-or-launch ChatGPT strictly on workspace 12.

set -euo pipefail
WS=12
CLASS_RE='^chrome-chatgpt\.com__-Default$'  # Your PWA class

# 1) Go to the ChatGPT workspace
hyprctl dispatch workspace "$WS"

# 2) If a ChatGPT window exists on WS 12, focus it
ADDR_ON_WS="$(
  hyprctl -j clients \
    | jq -r --argjson ws "$WS" --arg re "$CLASS_RE" '
        [ .[] | select(.workspace.id == $ws and ((.class // "") | test($re))) ]
        | sort_by(.focusHistoryID)
        | (.[0].address // empty)
      '
)"

if [ -n "$ADDR_ON_WS" ]; then
  hyprctl dispatch focuswindow "address:$ADDR_ON_WS"
  exit 0
fi

# 3) Otherwise, launch a new window on WS 12
exec omarchy-launch-webapp "https://chatgpt.com"
