#!/usr/bin/env bash
#
# gcal-notifier — Background daemon for Google Calendar notifications
# Shares credentials and token cache with gcal-tui.sh

set -uo pipefail

CREDS_FILE="${GCAL_TUI_CREDS:-$HOME/.config/gcal-tui/credentials.json}"
CACHE_DIR="${GCAL_TUI_CACHE_DIR:-$HOME/.cache/gcal-tui}"
TOKEN_CACHE="$CACHE_DIR/access_token.json"
NOTIFIED_LOG="$CACHE_DIR/notified_events.log"
CALENDAR_ID="${GCAL_TUI_CALENDAR_ID:-primary}"

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
  local token
  token=$(get_access_token) || return 1

  local time_min=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local time_max=$(date -d "+1 day" -u +%Y-%m-%dT%H:%M:%SZ)
  local url="https://www.googleapis.com/calendar/v3/calendars/${CALENDAR_ID}/events"

  local json
  json=$(curl -sS -G "$url" -H "Authorization: Bearer $token" \
    --data-urlencode "timeMin=${time_min}" \
    --data-urlencode "timeMax=${time_max}" \
    --data-urlencode "singleEvents=true" \
    --data-urlencode "orderBy=startTime")

  local now=$(date +%s)

  # Extract events, start times, and popup reminder minutes
  jq -r '
    .items[]? |
    select(.start.dateTime != null) |
    .summary as $title |
    .start.dateTime as $start |
    (if .reminders.useDefault == false and .reminders.overrides != null then
      (.reminders.overrides[] | select(.method == "popup") | .minutes)
    else
      10
    end) as $mins |
    [$start, $mins, $title] | @tsv
  ' <<<"$json" | while IFS=$'\t' read -r start mins title; do

    [[ -z "$start" ]] && continue

    local start_epoch notify_epoch event_id
    start_epoch=$(date -d "$start" +%s)
    notify_epoch=$((start_epoch - (mins * 60)))

    # Create a unique ID for this specific notification trigger
    # So we don't spam the desktop every 60 seconds
    event_id="${notify_epoch}_${title}"

    # If the notification time has passed, but the event hasn't started yet...
    if ((now >= notify_epoch)) && ((now < start_epoch)); then
      # Check if we already notified the user
      if ! grep -Fxq "$event_id" "$NOTIFIED_LOG"; then

        # Fire the desktop notification!
        notify-send "Upcoming Event" "$title starts in $mins minutes." \
          -a "Google Calendar" \
          -u normal \
          -i "x-office-calendar"

        # Log it so it doesn't fire again
        echo "$event_id" >>"$NOTIFIED_LOG"
      fi
    fi
  done

  # Keep log file from growing infinitely
  tail -n 100 "$NOTIFIED_LOG" >"$NOTIFIED_LOG.tmp" && mv "$NOTIFIED_LOG.tmp" "$NOTIFIED_LOG"
}

# The main daemon loop
while true; do
  check_events
  sleep 60 # Check every 60 seconds
done
