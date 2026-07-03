#!/usr/bin/env bash
set -euo pipefail

theme_file="${1:-$HOME/.config/omarchy/current/theme/ghostty.conf}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rmpc"
script_dir="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
quality_script="$HOME/.local/bin/music-system-quality.sh"

if [[ ! -x "$quality_script" ]]; then
  quality_script="$script_dir/music-system-quality.sh"
fi

mkdir -p "$cache_dir"

color_value() {
  local key="$1"
  awk -v key="$key" '$1 == key && $2 == "=" { print $3; exit }' "$theme_file" 2>/dev/null
}

palette_value() {
  local palette_index="$1"
  awk -v palette_index="$palette_index" '
    $1 == "palette" && $2 == "=" {
      split($3, parts, "=")
      if (parts[1] == palette_index) {
        print parts[2]
        exit
      }
    }
  ' "$theme_file" 2>/dev/null
}

background="$(color_value background)"
foreground="$(color_value foreground)"
dim="$(palette_value 8)"
primary="$(palette_value 6)"
secondary="$(palette_value 13)"
border="$(palette_value 4)"
warn="$(palette_value 11)"
error="$(palette_value 9)"
success="$(palette_value 10)"

background="${background:-#010112}"
foreground="${foreground:-#FAE4EF}"
dim="${dim:-#606167}"
primary="${primary:-#70A7B2}"
secondary="${secondary:-#BC92C0}"
border="${border:-#7E89B0}"
warn="${warn:-#A78D56}"
error="${error:-#C28D8F}"
success="${success:-#57977A}"

cat > "$cache_dir/theme.ron" <<EOF
#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    background_color: "$background",
    text_color: "$foreground",
    header_background_color: "$background",
    modal_background_color: "$background",
    modal_backdrop: true,
    preview_label_style: (fg: "$primary", modifiers: "Bold"),
    preview_metadata_group_style: (fg: "$secondary", modifiers: "Bold"),
    highlighted_item_style: (fg: "$primary", modifiers: "Bold"),
    current_item_style: (fg: "$background", bg: "$secondary", modifiers: "Bold"),
    borders_style: (fg: "$border"),
    highlight_border_style: (fg: "$secondary", modifiers: "Bold"),
    progress_bar: (
        elapsed_style: (fg: "$primary"),
        thumb_style: (fg: "$secondary"),
    ),
    scrollbar: (
        thumb_style: (fg: "$primary"),
    ),
    tab_bar: (
        active_style: (fg: "$background", bg: "$primary", modifiers: "Bold"),
        inactive_style: (fg: "$foreground"),
    ),
    level_styles: (
        info: (fg: "$primary", bg: "$background"),
        warn: (fg: "$warn", bg: "$background"),
        error: (fg: "$error", bg: "$background"),
        debug: (fg: "$success", bg: "$background"),
        trace: (fg: "$secondary", bg: "$background"),
    ),
    cava: (
        bar_symbols: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
        inverted_bar_symbols: ["▔", "▔", "▔", "▀", "▀", "▀", "▀", "█"],
        bar_color: (fg: "$primary"),
        bar_spacing: 1,
        bar_width: 1,
        orientation: Bottom,
    ),
)
EOF

cat > "$cache_dir/tmux.conf" <<EOF
set -g status on
set -g status-position bottom
set -g status-interval 2
set -g status-style "bg=$background,fg=$foreground"
set -g status-left "#[fg=$primary,bold] rmpc #[fg=$dim]#{session_name} "
set -g status-right "#[fg=$secondary,bold]#($quality_script) "
set -g message-style "bg=$background,fg=$foreground"
set -g mode-style "bg=$primary,fg=$background"
set -g pane-active-border-style "fg=$secondary"
set -g pane-border-style "fg=$border"
set -g window-status-current-style "fg=$background,bg=$primary,bold"
set -g window-status-style "fg=$foreground,bg=$background"
set -g allow-passthrough on
set -g mouse on
set -g escape-time 10
set -ga terminal-overrides ",xterm-ghostty:RGB"
EOF
