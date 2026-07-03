#!/usr/bin/env bash
set -euo pipefail

music_workspace=11
rmpc_class="com.cinmay.rmpc"
youtube_class="com.cinmay.youtube-music"
youtube_url="https://music.youtube.com"
script_dir="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
rmpc_launcher="$script_dir/rmpc-music-session.sh"

clients() {
  hyprctl -j clients
}

find_rmpc() {
  clients | jq -r --arg class "$rmpc_class" '
    .[]
    | select(
        (.class // "") == $class
        or (.initialClass // "") == $class
        or ((.title // "") | test("^rmpc-music$"))
      )
    | "\(.address) \(.workspace.id)"
  ' | head -n1
}

find_youtube() {
  clients | jq -r --arg class "$youtube_class" '
    .[]
    | select(
        (.class // "") == $class
        or (.initialClass // "") == $class
        or ((.title // "") | test("YouTube Music"))
      )
    | "\(.address) \(.workspace.id)"
  ' | head -n1
}

address_from() {
  printf "%s" "${1%% *}"
}

focus_window() {
  hyprctl dispatch focuswindow "address:$1" >/dev/null
}

workspace_music() {
  hyprctl dispatch workspace "$music_workspace" >/dev/null
}

is_grouped() {
  local address="$1"

  clients | jq -e --arg address "$address" '
    .[]
    | select(.address == $address)
    | ((.grouped // []) | length > 0)
  ' >/dev/null
}

ensure_group() {
  local address="$1"

  focus_window "$address"
  if ! is_grouped "$address"; then
    hyprctl dispatch togglegroup >/dev/null || true
  fi
  hyprctl dispatch lockactivegroup lock >/dev/null || true
}

launch_rmpc() {
  local group_rule="$1"

  hyprctl dispatch exec "[workspace $music_workspace; group $group_rule] ghostty +new-window --class=$rmpc_class --title=rmpc-music --command=$rmpc_launcher" >/dev/null
}

launch_youtube() {
  local group_rule="$1"

  hyprctl dispatch exec "[workspace $music_workspace; group $group_rule] omarchy-launch-webapp $youtube_url --class=$youtube_class" >/dev/null
}

wait_for_rmpc() {
  local found

  for _ in {1..60}; do
    found="$(find_rmpc)"
    if [[ -n "$found" ]]; then
      printf "%s" "$found"
      return 0
    fi
    sleep 0.1
  done

  return 1
}

wait_for_youtube() {
  local found

  for _ in {1..80}; do
    found="$(find_youtube)"
    if [[ -n "$found" ]]; then
      printf "%s" "$found"
      return 0
    fi
    sleep 0.1
  done

  return 1
}

rmpc_window="$(find_rmpc)"
youtube_window="$(find_youtube)"

if [[ -n "$rmpc_window" && -n "$youtube_window" ]]; then
  workspace_music
  exit 0
fi

if [[ -z "$rmpc_window" && -z "$youtube_window" ]]; then
  workspace_music
  launch_rmpc "new lock"
  sleep 0.2
  launch_youtube "invade"

  rmpc_window="$(wait_for_rmpc || true)"
  [[ -n "$rmpc_window" ]] && focus_window "$(address_from "$rmpc_window")"
  exit 0
fi

if [[ -n "$rmpc_window" ]]; then
  rmpc_address="$(address_from "$rmpc_window")"
  workspace_music
  ensure_group "$rmpc_address"
  launch_youtube "invade"
  sleep 0.5
  focus_window "$rmpc_address"
  exit 0
fi

youtube_address="$(address_from "$youtube_window")"
workspace_music
ensure_group "$youtube_address"
launch_rmpc "invade"
sleep 0.5
focus_window "$youtube_address"
