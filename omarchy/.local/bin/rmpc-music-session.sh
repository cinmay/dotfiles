#!/usr/bin/env bash
set -euo pipefail

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rmpc"
script_dir="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
package_root="$(cd -- "$script_dir/../.." && pwd)"

config_file="$HOME/.config/rmpc/config.ron"
fallback_theme="$HOME/.config/rmpc/theme.ron"
fallback_tmux="$HOME/.config/rmpc/tmux.conf"
sync_script="$HOME/.local/bin/rmpc-theme-sync.sh"

[[ -r "$config_file" ]] || config_file="$package_root/.config/rmpc/config.ron"
[[ -r "$fallback_theme" ]] || fallback_theme="$package_root/.config/rmpc/theme.ron"
[[ -r "$fallback_tmux" ]] || fallback_tmux="$package_root/.config/rmpc/tmux.conf"
[[ -x "$sync_script" ]] || sync_script="$script_dir/rmpc-theme-sync.sh"

"$sync_script" >/dev/null 2>&1 || true

theme_file="$cache_dir/theme.ron"
tmux_file="$cache_dir/tmux.conf"

if [[ ! -r "$theme_file" ]]; then
  mkdir -p "$cache_dir"
  cp "$fallback_theme" "$theme_file"
fi

[[ -r "$tmux_file" ]] || tmux_file="$fallback_tmux"

exec tmux -L rmpc-music -f "$tmux_file" new-session -A -s music \
  "rmpc --config '$config_file' --theme '$theme_file'"
