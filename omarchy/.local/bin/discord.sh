#!/usr/bin/env bash
# Focus-or-launch Discord web strictly on workspace 14.

set -euo pipefail

WS=14
CLASS_RE='^(chrome-discord\.com__app-Default|chrome-discord\.com__-Default)$'
TITLE_RE='Discord'

hyprctl dispatch workspace "$WS"

ADDR_ON_WS="$(
  hyprctl -j clients \
    | jq -r --argjson ws "$WS" --arg class_re "$CLASS_RE" --arg title_re "$TITLE_RE" '
        [
          .[]
          | select(.workspace.id == $ws)
          | select(
              ((.class // "") | test($class_re; "i"))
              or ((.title // "") | test($title_re; "i"))
            )
        ]
        | sort_by(.focusHistoryID)
        | (.[0].address // empty)
      '
)"

if [ -n "$ADDR_ON_WS" ]; then
  hyprctl dispatch focuswindow "address:$ADDR_ON_WS"
  exit 0
fi

exec omarchy-launch-webapp "https://discord.com/app"
