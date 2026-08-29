#!/usr/bin/env bash
# Usage: obs-recording.sh toggle|toggle-pause

set -euo pipefail

ACTION="${1:-}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 toggle|toggle-pause"
  exit 1
fi

WS_FILE="$HOME/.config/niri/obs-websocket"
if [[ ! -f "$WS_FILE" ]]; then
  WS_FILE="$HOME/dotfiles/niri/.config/niri/obs-websocket"
fi

WS_ARGS=()
if [[ -f "$WS_FILE" ]]; then
  WS_ARGS=(--websocket "$(cat "$WS_FILE")")
fi

if pgrep -x obs >/dev/null 2>&1; then
  case "$ACTION" in
  toggle)
    obs-cmd "${WS_ARGS[@]}" recording toggle
    ;;
  toggle-pause)
    obs-cmd "${WS_ARGS[@]}" recording toggle-pause
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
  esac
else
  # OBS not running → open the profile chooser
  foot --app-id=obs-launcher \
    -o initial-window-mode=windowed \
    -o colors.dark.alpha=0.8 \
    "$HOME/dotfiles/niri/.config/niri/scripts/obs-launcher.sh"
fi
