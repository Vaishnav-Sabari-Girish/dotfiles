#!/usr/bin/env bash
#
# gcal-notifier — Background daemon for Google Calendar notifications
# Shares credentials and token cache with gcal-tui.sh

set -uo pipefail

CREDS_FILE="${GCAL_TUI_CREDS:-$HOME/.config/gcal-tui/credentials.json}"
CACHE_DIR="${GCAL_TUI_CACHE_DIR:-$HOME/.cache/gcal-tui}"
TOKEN_CACHE="$CACHE_DIR/access_token.json"
NOTIFIED_LOG="$CACHE_DIR/notified_events.log"

# Source the local untracked config
source "$HOME/.config/gcal-tui/calendars.conf"

CALENDARS=(
  "$PRIMARY_EMAIL"
  "$CLASS_CALENDAR"
)

mkdir -p "$CACHE_DIR"
touch "$NOTIFIED_LOG"

get_access_token() {
  local now=$(date +%s)
  if [[ -f "$TOKEN_CACHE" ]]; then
    local cached_exp=$(jq -r '.expires_at // 0' "$TOKEN_CACHE" 2>/dev/null)
    if [[ -n "$cached_exp" && "$now" -lt "$cached_exp" ]]; then
      jq -r '.access_token' "$TOKEN_CACHE"
      return 0
    fi
  fi

  local client_id=$(jq -r '.client_id' "$CREDS_FILE")
  local client_secret=$(jq -r '.client_secret' "$CREDS_FILE")
  local refresh_token=$(jq -r '.refresh_token' "$CREDS_FILE")

  local resp=$(curl -sS -X POST https://oauth2.googleapis.com/token \
    -d client_id="$client_id" -d client_secret="$client_secret" \
    -d refresh_token="$refresh_token" -d grant_type=refresh_token)

  local access_token=$(jq -r '.access_token // empty' <<<"$resp")
  [[ -z "$access_token" ]] && return 1

  local expires_in=$(jq -r '.expires_in // 3600' <<<"$resp")
  local expires_at=$((now + expires_in - 60))

  jq -n --arg t "$access_token" --argjson e "$expires_at" '{access_token: $t, expires_at: $e}' >"$TOKEN_CACHE"
  printf '%s' "$access_token"
}

check_events() {
  local target_calendar="$1"
  local token
  token=$(get_access_token) || return 1

  local time_min=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local time_max=$(date -d "+14 days" -u +%Y-%m-%dT%H:%M:%SZ)

  # Ensure the ugly ID is properly URL-encoded for the curl request
  local encoded_cal
  encoded_cal=$(jq -rn --arg x "$target_calendar" '$x|@uri')
  local url="https://www.googleapis.com/calendar/v3/calendars/${encoded_cal}/events"

  local json
  json=$(curl -sS -G "$url" -H "Authorization: Bearer $token" \
    --data-urlencode "timeMin=${time_min}" \
    --data-urlencode "timeMax=${time_max}" \
    --data-urlencode "singleEvents=true" \
    --data-urlencode "orderBy=startTime")

  local now=$(date +%s)

  # Extract events, start times, and popup reminder minutes
  # Extract events, start times, and popup reminder minutes
  jq -r '
    .items[]? |
    select(.start.dateTime != null) |
    .summary as $title |
    .start.dateTime as $start |
    (
      if .reminders.useDefault == true then
        10
      elif .reminders.useDefault == false and .reminders.overrides != null then
        (.reminders.overrides[] | select(.method == "popup") | .minutes)
      else
        empty
      end
    ) as $mins |
    [$start, $mins, $title] | @tsv
  ' <<<"$json" | while IFS=$'\t' read -r start mins title; do

    [[ -z "$start" ]] && continue

    local start_epoch notify_epoch event_id
    start_epoch=$(date -d "$start" +%s)
    notify_epoch=$((start_epoch - (mins * 60)))

    # Append the calendar ID to make the log entry truly unique
    event_id="${notify_epoch}_${title}_${target_calendar}"

    # If the notification time has passed, but the event hasn't started yet...
    if ((now >= notify_epoch)) && ((now < start_epoch)); then
      if ! grep -Fxq "$event_id" "$NOTIFIED_LOG"; then

        notify-send "Upcoming Event" "$title starts in $mins minutes." \
          -a "Google Calendar" \
          -u normal \
          -i "x-office-calendar"
        # Play the notification sound for exactly 1 second in the background
        timeout 1 paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga &

        echo "$event_id" >>"$NOTIFIED_LOG"
      fi
    fi
  done

  # Keep log file from growing infinitely
  tail -n 100 "$NOTIFIED_LOG" >"$NOTIFIED_LOG.tmp" && mv "$NOTIFIED_LOG.tmp" "$NOTIFIED_LOG"
}

# The main daemon loop
while true; do
  for cal in "${CALENDARS[@]}"; do
    check_events "$cal"
  done
  sleep 10 # Check every 10 seconds
done
