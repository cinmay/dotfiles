#!/usr/bin/env bash
# Open a website I don't fully trust in Firefox with a fresh, empty profile:
# no accounts, cookies, extensions or history, and the profile is deleted on
# close so nothing the site leaves behind survives into the next visit.
# Usage: untrusted-browser.sh [url]

set -euo pipefail

PROFILE_DIR="$(mktemp -d --tmpdir untrusted-browser.XXXXXX)"
trap 'rm -rf -- "$PROFILE_DIR"' EXIT

# --no-remote keeps the URL from being handed to an already running Firefox,
# which would open it in my normal profile. No exec: the trap must run after
# Firefox exits.
firefox --no-remote --profile "$PROFILE_DIR" "$@"
