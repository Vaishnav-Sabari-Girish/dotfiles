#!/usr/bin/env bash
#
# gcal-launcher.sh — fzf wrapper for gcal-tui

# Source the local untracked config
source "$HOME/.config/gcal-tui/calendars.conf"

declare -A CALENDARS=(
  ["1. Primary (Vaishnav)"]="$PRIMARY_EMAIL"
  ["2. Teach 'n Go (Classes)"]="$CLASS_CALENDAR"
)

# Clear the screen to make it look clean
printf '\e[2J\e[H'

# Pipe just the friendly names (the keys) into fzf, sorted numerically
SELECTED_NAME=$(printf "%s\n" "${!CALENDARS[@]}" | sort | fzf \
  --prompt="Select Calendar ❯ " \
  --pointer="▶" \
  --border=rounded \
  --margin=10%,20% \
  --layout=reverse \
  --info=hidden)

# If you press Esc to cancel, just exit
[[ -z "$SELECTED_NAME" ]] && exit 0

# Extract the matching ugly ID from the array
export GCAL_TUI_CALENDAR_ID="${CALENDARS[$SELECTED_NAME]}"

# Launch the main TUI
exec "$HOME/dotfiles/niri/.config/niri/scripts/gcal-tui.sh"
