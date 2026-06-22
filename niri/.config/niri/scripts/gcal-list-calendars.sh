#!/usr/bin/env bash

TOKEN_CACHE="$HOME/.cache/gcal-tui/access_token.json"

token=$(jq -r '.access_token // empty' "$TOKEN_CACHE" 2>/dev/null)

if [[ -z "$token" ]]; then
  echo "No token found! Please run the main gcal-tui.sh script first."
  exit 1
fi

echo -e "\nFetching your Google Calendars...\n"

curl -sS -H "Authorization: Bearer $token" \
  "https://www.googleapis.com/calendar/v3/users/me/calendarList" |
  jq -r '.items[]? | "Name: \(.summary)\nID:   \(.id)\n---"'
