#!/usr/bin/env bash
set -euo pipefail

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rmpc"
script_dir="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
package_root="$(cd -- "$script_dir/../.." && pwd)"

config_file="$HOME/.config/rmpc/config.ron"
fallback_theme="$HOME/.config/rmpc/theme.ron"
sync_script="$HOME/.local/bin/rmpc-theme-sync.sh"

[[ -r "$config_file" ]] || config_file="$package_root/.config/rmpc/config.ron"
[[ -r "$fallback_theme" ]] || fallback_theme="$package_root/.config/rmpc/theme.ron"
[[ -x "$sync_script" ]] || sync_script="$script_dir/rmpc-theme-sync.sh"

"$sync_script" >/dev/null 2>&1 || true

theme_file="$cache_dir/theme.ron"

if [[ ! -r "$theme_file" ]]; then
  mkdir -p "$cache_dir"
  cp "$fallback_theme" "$theme_file"
fi

exec rmpc --config "$config_file" --theme "$theme_file"
