#!/usr/bin/env bash
set -euo pipefail

theme_file="${1:-${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/ghostty.conf}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rmpc"

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
    background_color: None,
    text_color: "$foreground",
    header_background_color: None,
    modal_background_color: "$background",
    modal_backdrop: true,
    preview_label_style: (fg: "$primary", modifiers: "Bold"),
    preview_metadata_group_style: (fg: "$secondary", modifiers: "Bold"),
    highlighted_item_style: (fg: "$primary", modifiers: "Bold"),
    current_item_style: (fg: "$background", bg: "$secondary", modifiers: "Bold"),
    borders_style: (fg: "$border"),
    highlight_border_style: (fg: "$secondary", modifiers: "Bold"),
    progress_bar: (
        symbols: ["█", "█", "█", " ", "█"],
        track_style: None,
        elapsed_style: (fg: "$primary"),
        thumb_style: (fg: "$secondary"),
        use_track_when_empty: true,
    ),
    scrollbar: (
        symbols: ["│", "█", "▲", "▼"],
        track_style: (),
        ends_style: (),
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
)
EOF
