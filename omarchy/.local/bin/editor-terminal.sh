#!/usr/bin/env bash
# Always jump to the editor workspace (10); focus an existing terminal there or launch one.

set -euo pipefail
WS=10

# 1) Go to the editor workspace
hyprctl dispatch workspace "$WS"

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
  hyprctl dispatch focuswindow "address:$FOUND"
  exit 0
fi

# 3) No terminal on WS 10 → open one here
cd "$(omarchy-cmd-terminal-cwd 2>/dev/null || echo "$HOME")"
exec uwsm app -- "${TERMINAL:-alacritty}"
