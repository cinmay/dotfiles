#!/usr/bin/env bash
# Focus existing YouTube Music window if present; else go to WS 11 and launch.

# Look for any window whose title contains "YouTube Music"
FOUND="$(hyprctl -j clients \
  | jq -r '.[] | select(.title|test("YouTube Music")) | "\(.address) \(.workspace.id)"' \
  | head -n1)"

if [ -n "$FOUND" ]; then
  addr="${FOUND%% *}"
  ws="${FOUND##* }"
  hyprctl dispatch workspace "$ws"
  hyprctl dispatch focuswindow "address:$addr"
else
  hyprctl dispatch workspace 11
  omarchy-launch-webapp "https://music.youtube.com"
fi
