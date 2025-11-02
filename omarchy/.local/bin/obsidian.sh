#!/usr/bin/env bash
# Open Obsidian on workspace 13 as a regular (tiled) window.

# Jump to the workspace first so the window opens there
hyprctl dispatch workspace 13

# Launch Obsidian normally (Wayland IME + GPU flag as you had)
exec uwsm app -- obsidian -disable-gpu --enable-wayland-ime
