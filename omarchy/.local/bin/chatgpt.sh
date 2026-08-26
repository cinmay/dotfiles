#!/usr/bin/env bash
# Focus-or-launch the native ChatGPT client strictly on workspace 12.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
HYPR_DISPATCH="$SCRIPT_DIR/hypr-lua-dispatch"

WS=12
CLASS_RE='^(chatgpt|com\.openai\.ChatGPT)$'

# 1) Go to the ChatGPT workspace
"$HYPR_DISPATCH" workspace "$WS"

# 2) If a native ChatGPT window exists on WS 12, focus it
ADDR_ON_WS="$(
  hyprctl -j clients \
    | jq -r --argjson ws "$WS" --arg re "$CLASS_RE" '
        [
          .[]
          | select(.workspace.id == $ws)
          | select(
              ((.class // "") | test($re; "i"))
              or ((.initialClass // "") | test($re; "i"))
            )
        ]
        | sort_by(.focusHistoryID)
        | (.[0].address // empty)
      '
)"

if [ -n "$ADDR_ON_WS" ]; then
  "$HYPR_DISPATCH" focus-window "$ADDR_ON_WS"
  exit 0
fi

# 3) Otherwise, launch a new native client window on WS 12
exec uwsm app -- chatgpt
