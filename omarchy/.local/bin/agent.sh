#!/usr/bin/env bash
# Focus-or-launch Omarchy's default coding agent strictly on workspace 12.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
HYPR_DISPATCH="$SCRIPT_DIR/hypr-lua-dispatch"

WS=12
# omarchy-agent gives every agent window this app-id, whichever agent is the default.
CLASS_RE='^org\.omarchy\.agent$'

# 1) Go to the agent workspace
"$HYPR_DISPATCH" workspace "$WS"

# 2) If an agent window exists on WS 12, focus it
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

# 3) Otherwise, launch the default agent on WS 12 (--pick opens the chooser if none is set)
exec omarchy-agent --pick
