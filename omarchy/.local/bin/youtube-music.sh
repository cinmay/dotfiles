#!/usr/bin/env bash
# Jump to the music workspace and show the last used player.
# Pressed again on the music workspace, switch between rmpc and YouTube Music.
# Workspace 11 uses the monocle layout (hypr/bindings.lua), so one player is visible at a time.

set -euo pipefail

music_workspace=11
rmpc_class="com.cinmay.rmpc"
# Chrome ignores --class on Wayland and derives the app id from the web app URL.
youtube_class="chrome-music.youtube.com__-Default"
youtube_url="https://music.youtube.com"
script_dir="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
hypr_dispatch="$script_dir/hypr-lua-dispatch"
rmpc_launcher="$script_dir/rmpc-music.sh"

most_recent_window() {
  hyprctl -j clients | jq -r --args '
    [.[] | select(.class as $class | $ARGS.positional | index($class))]
    | sort_by(.focusHistoryID)
    | (.[0].address // empty)
  ' "$@"
}

launch_rmpc() {
  local launcher

  printf -v launcher "%q" "$rmpc_launcher"
  "$hypr_dispatch" exec "bash -lc 'exec uwsm-app -- ghostty --class=$rmpc_class --title=rmpc-music -e $launcher'" >/dev/null
}

launch_youtube() {
  "$hypr_dispatch" exec "omarchy-launch-webapp $youtube_url" >/dev/null
}

show_player() {
  local class="$1"
  local address

  address="$(most_recent_window "$class")"
  if [[ -n "$address" ]]; then
    "$hypr_dispatch" focus-window "$address" >/dev/null
  elif [[ "$class" == "$rmpc_class" ]]; then
    launch_rmpc
  else
    launch_youtube
  fi
}

active_workspace="$(hyprctl -j activeworkspace | jq -r '.id')"
active_class="$(hyprctl -j activewindow | jq -r '.class // empty')"

if [[ "$active_workspace" != "$music_workspace" ]]; then
  "$hypr_dispatch" workspace "$music_workspace" >/dev/null
  last_player="$(most_recent_window "$rmpc_class" "$youtube_class")"
  if [[ -n "$last_player" ]]; then
    "$hypr_dispatch" focus-window "$last_player" >/dev/null
  else
    launch_rmpc
  fi
  exit 0
fi

if [[ "$active_class" == "$rmpc_class" ]]; then
  show_player "$youtube_class"
else
  show_player "$rmpc_class"
fi
