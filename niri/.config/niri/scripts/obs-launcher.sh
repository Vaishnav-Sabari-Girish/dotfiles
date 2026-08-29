#!/usr/bin/env bash
# OBS Profile + Scene Collection launcher for niri

set -euo pipefail

OPTIONS=(
  "Silicon Sundays"
  "Youtube"
)

selected=$(printf '%s\n' "${OPTIONS[@]}" | fzf \
  --prompt="OBS Profile / Collection › " \
  --height=40% \
  --border \
  --layout=reverse \
  --info=inline \
  --header="Choose profile + scene collection")

[[ -z "$selected" ]] && exit 0

WS_FILE="$HOME/.config/niri/obs-websocket"
WS_ARGS=()
if [[ -f "$WS_FILE" ]]; then
  WS_ARGS=(--websocket "$(cat "$WS_FILE")")
fi

if pgrep -x obs >/dev/null 2>&1; then
  # OBS already running → switch collection (and profile if supported)
  obs-cmd "${WS_ARGS[@]}" scene-collection switch "$selected" 2>/dev/null || true
  obs-cmd "${WS_ARGS[@]}" profile switch "$selected" 2>/dev/null || true
else
  # Ask niri to spawn OBS with the correct profile + collection
  niri msg action spawn -- obs --profile "$selected" --collection "$selected"
fi

exit 0
