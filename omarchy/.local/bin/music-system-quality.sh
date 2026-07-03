#!/usr/bin/env bash
set -euo pipefail

format_rate() {
  local rate="${1%Hz}"

  if [[ "$rate" =~ ^[0-9]+$ ]]; then
    if (( rate % 1000 == 0 )); then
      printf "%dkHz" "$((rate / 1000))"
    else
      awk -v rate="$rate" 'BEGIN { printf "%.1fkHz", rate / 1000 }'
    fi
  else
    printf "%s" "$1"
  fi
}

sink_spec() {
  local default_sink
  default_sink="$(pactl get-default-sink 2>/dev/null || true)"
  [[ -n "$default_sink" ]] || return 1

  pactl list sinks 2>/dev/null | awk -v sink="$default_sink" '
    $1 == "Name:" { in_sink = ($2 == sink) }
    in_sink && /Sample Specification:/ {
      sub(/^[[:space:]]*Sample Specification:[[:space:]]*/, "")
      print
      exit
    }
  '
}

spec="$(sink_spec || true)"

if [[ -z "$spec" ]]; then
  printf "SYS audio unavailable"
  exit 0
fi

read -r format channels rate _ <<< "$spec"

if [[ -z "${format:-}" || -z "${channels:-}" || -z "${rate:-}" ]]; then
  printf "SYS %s" "$spec"
else
  printf "SYS %s %s %s" "$format" "$channels" "$(format_rate "$rate")"
fi
