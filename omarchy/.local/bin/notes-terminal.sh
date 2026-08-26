#!/usr/bin/env bash
# Always jump to the notes workspace (13); focus an existing terminal there or launch one.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
HYPR_DISPATCH="$SCRIPT_DIR/hypr-lua-dispatch"

WS=13

# 1) Go to the notes workspace
"$HYPR_DISPATCH" workspace "$WS"

# 2) Look for an existing terminal on this workspace
FOUND="$(
  hyprctl -j clients \
    | jq -r --argjson ws "$WS" \
          --arg re '^(com\.mitchellh\.ghostty|Ghostty|Alacritty|kitty|org\.wezfurlong\.wezterm|wezterm-gui|foot|Gnome-terminal|Tilix|konsole|XTerm)$' '
        .[]
        | select(.workspace.id == $ws)
        | select(
            # match by class (preferred)
            ((.class // "") | test($re; "i"))
            # or fallback: a terminal tag, if present
            or ((.tags // []) | any(. == "terminal*"))
          )
        | .address
      ' \
    | head -n1
)"

if [ -n "$FOUND" ]; then
  "$HYPR_DISPATCH" focus-window "$FOUND"
  exit 0
fi

# 3) No terminal on WS 13 → open one here
cd "$(omarchy-cmd-terminal-cwd 2>/dev/null || echo "$HOME")"
exec uwsm app -- "${TERMINAL:-alacritty}"
