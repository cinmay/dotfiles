#!/usr/bin/env bash
# Always jump to editor workspace (10); focus existing terminal there or launch one on that workspace.

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
            ((.class // "") | test($re; "i"))
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

# 3) No terminal on WS 10 → ask Hyprland to launch it on the *current* workspace
CWD="$(omarchy-cmd-terminal-cwd 2>/dev/null || echo "$HOME")"
# Use hyprctl exec so the window opens on WS 10, not the previous workspace
hyprctl dispatch exec "bash -lc 'cd \"${CWD}\"; exec uwsm app -- \"${TERMINAL:-alacritty}\"'"
