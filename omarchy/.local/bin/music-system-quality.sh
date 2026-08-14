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

describe_format() {
  case "$1" in
    s16le) printf "16-bit signed PCM" ;;
    s24le) printf "24-bit signed PCM" ;;
    s32le) printf "32-bit signed PCM" ;;
    f32le | float32le) printf "32-bit float PCM" ;;
    f64le | float64le) printf "64-bit float PCM" ;;
    u8) printf "8-bit unsigned PCM" ;;
    *) printf "%s" "$1" ;;
  esac
}

describe_channels() {
  case "$1" in
    1ch) printf "mono" ;;
    2ch) printf "stereo" ;;
    6ch) printf "5.1 surround" ;;
    8ch) printf "7.1 surround" ;;
    *) printf "%s" "$1" ;;
  esac
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
  printf "System audio: unavailable"
  exit 0
fi

read -r format channels rate _ <<< "$spec"

if [[ -z "${format:-}" || -z "${channels:-}" || -z "${rate:-}" ]]; then
  printf "System audio: %s" "$spec"
else
  printf "System audio: %s, %s, %s" "$(format_rate "$rate")" "$(describe_channels "$channels")" "$(describe_format "$format")"
fi
