#!/usr/bin/env bash
# Jump to a workspace, focus an existing terminal there, or launch one.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: ${0##*/} <workspace-id> [command...]" >&2
  exit 2
fi

WS="$1"
shift

case "$WS" in
  '' | *[!0-9]*)
    echo "workspace id must be numeric: $WS" >&2
    exit 2
    ;;
esac

hyprctl dispatch workspace "$WS"

FOUND="$(
  hyprctl -j clients \
    | jq -r --argjson ws "$WS" \
          --arg re '^(com\.mitchellh\.ghostty|Ghostty|Alacritty|kitty|org\.wezfurlong\.wezterm|wezterm-gui|foot|Gnome-terminal|Tilix|konsole|XTerm)$' '
        [
          .[]
          | select(.workspace.id == $ws)
          | select(
              ((.class // "") | test($re; "i"))
              or ((.tags // []) | any(test("^terminal")))
            )
        ]
        | sort_by(.focusHistoryID)
        | (.[0].address // empty)
      '
)"

if [ -n "$FOUND" ]; then
  hyprctl dispatch focuswindow "address:$FOUND"
  exit 0
fi

CWD="$(omarchy-cmd-terminal-cwd 2>/dev/null || echo "$HOME")"
if [ ! -d "$CWD" ]; then
  CWD="$HOME"
fi

if [ "$#" -gt 0 ]; then
  printf -v command_args ' %q' "$@"
  hyprctl dispatch exec "bash -lc 'exec uwsm-app -- xdg-terminal-exec --dir=\"${CWD}\"${command_args}'"
else
  hyprctl dispatch exec "bash -lc 'cd \"${CWD}\"; exec uwsm app -- \"${TERMINAL:-alacritty}\"'"
fi
