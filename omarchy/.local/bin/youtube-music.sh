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
  hyprctl dispatch lockactivegroup unlock >/dev/null || true
}

lock_group() {
  local address="$1"

  focus_window "$address"
  if is_grouped "$address"; then
    hyprctl dispatch lockactivegroup lock >/dev/null || true
  fi
}

move_to_music_workspace() {
  local address="$1"

  hyprctl dispatch movetoworkspacesilent "$music_workspace,address:$address" >/dev/null || true
}

move_into_group() {
  local moving_address="$1"
  local group_address="$2"
  local direction

  move_to_music_workspace "$moving_address"
  focus_window "$group_address"
  ensure_group "$group_address"
  focus_window "$moving_address"

  for direction in l r u d; do
    hyprctl dispatch moveintogroup "$direction" >/dev/null || true
    if is_grouped "$moving_address"; then
      lock_group "$moving_address"
      return 0
    fi
  done

  lock_group "$group_address"
  return 1
}

launch_rmpc() {
  local launcher

  printf -v launcher "%q" "$rmpc_launcher"
  hyprctl dispatch exec "[workspace $music_workspace] bash -lc 'exec uwsm-app -- ghostty --class=$rmpc_class --title=rmpc-music -e $launcher'" >/dev/null
}

launch_youtube() {
  hyprctl dispatch exec "[workspace $music_workspace] omarchy-launch-webapp $youtube_url --class=$youtube_class" >/dev/null
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
  rmpc_address="$(address_from "$rmpc_window")"
  youtube_address="$(address_from "$youtube_window")"
  workspace_music
  if ! is_grouped "$rmpc_address" || ! is_grouped "$youtube_address"; then
    ensure_group "$rmpc_address"
    move_into_group "$youtube_address" "$rmpc_address" || true
    focus_window "$rmpc_address"
  fi
  exit 0
fi

if [[ -z "$rmpc_window" && -z "$youtube_window" ]]; then
  workspace_music
  launch_rmpc
  rmpc_window="$(wait_for_rmpc || true)"
  if [[ -n "$rmpc_window" ]]; then
    rmpc_address="$(address_from "$rmpc_window")"
    ensure_group "$rmpc_address"
  fi

  launch_youtube
  youtube_window="$(wait_for_youtube || true)"
  if [[ -n "$rmpc_window" && -n "$youtube_window" ]]; then
    youtube_address="$(address_from "$youtube_window")"
    move_into_group "$youtube_address" "$rmpc_address" || true
  fi

  [[ -n "$rmpc_window" ]] && focus_window "$rmpc_address"
  exit 0
fi

if [[ -n "$rmpc_window" ]]; then
  rmpc_address="$(address_from "$rmpc_window")"
  workspace_music
  ensure_group "$rmpc_address"
  launch_youtube
  youtube_window="$(wait_for_youtube || true)"
  if [[ -n "$youtube_window" ]]; then
    youtube_address="$(address_from "$youtube_window")"
    move_into_group "$youtube_address" "$rmpc_address" || true
  fi
  focus_window "$rmpc_address"
  exit 0
fi

youtube_address="$(address_from "$youtube_window")"
workspace_music
ensure_group "$youtube_address"
launch_rmpc
rmpc_window="$(wait_for_rmpc || true)"
if [[ -n "$rmpc_window" ]]; then
  rmpc_address="$(address_from "$rmpc_window")"
  move_into_group "$rmpc_address" "$youtube_address" || true
fi
focus_window "$youtube_address"
