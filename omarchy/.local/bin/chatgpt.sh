#!/usr/bin/env bash
# Focus existing ChatGPT window if present; else go to WS 12 and launch.

# Find any window whose title contains "ChatGPT"
FOUND="$(hyprctl -j clients \
  | jq -r '.[] | select(.title|test("ChatGPT")) | "\(.address) \(.workspace.id)"' \
  | head -n1)"

if [ -n "$FOUND" ]; then
  addr="${FOUND%% *}"
  ws="${FOUND##* }"
  hyprctl dispatch workspace "$ws"
  hyprctl dispatch focuswindow "address:$addr"
else
  hyprctl dispatch workspace 12
  omarchy-launch-webapp "https://chatgpt.com"
fi
