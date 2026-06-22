#!/usr/bin/env bash
#
# gcal-create.sh — External event creation script for gcal-tui
# Usage: ./gcal-create.sh [YYYY-MM-DD]

set -uo pipefail

CREDS_FILE="${GCAL_TUI_CREDS:-$HOME/.config/gcal-tui/credentials.json}"
CACHE_DIR="${GCAL_TUI_CACHE_DIR:-$HOME/.cache/gcal-tui}"
TOKEN_CACHE="$CACHE_DIR/access_token.json"
CALENDAR_ID="${GCAL_TUI_CALENDAR_ID:-primary}"

TARGET_DATE="${1:-$(date +%Y-%m-%d)}"

# ---------------------------------------------------------------------------
# Auth (Reuses existing cached token)
# ---------------------------------------------------------------------------
get_access_token() {
  local now=$(date +%s)
  if [[ -f "$TOKEN_CACHE" ]]; then
    local cached_exp=$(jq -r '.expires_at // 0' "$TOKEN_CACHE" 2>/dev/null)
    if [[ -n "$cached_exp" && "$now" -lt "$cached_exp" ]]; then
      jq -r '.access_token' "$TOKEN_CACHE"
      return 0
    fi
  fi
  # Fallback: if token is dead and main script isn't running, it will fail gracefully
  echo "No valid token. Please open the main calendar TUI first." >&2
  return 1
}

TOKEN=$(get_access_token) || exit 1

# ---------------------------------------------------------------------------
# Neovim Template Engine
# ---------------------------------------------------------------------------
TEMPLATE_FILE=$(mktemp "${CACHE_DIR}/new-event-XXXXXX.md")

cat <<EOF >"$TEMPLATE_FILE"
TITLE: 
DATE: $TARGET_DATE
START_TIME: 
END_TIME: 
LOCATION: 
ADD_MEET: false
REPEATS: 
GUESTS: 
---
DESCRIPTION/LINKS:
(Write your description or paste Google Drive links below this line)
EOF

printf '\e[2J\e[H'
echo "=== CREATE NEW EVENT ==="
echo "Instructions:"
echo "- Leave START_TIME and END_TIME blank for an 'All Day' event."
echo "- Use 24-hour HH:MM format for times (e.g., 14:30)."
echo "- ADD_MEET must be 'true' or 'false'."
echo "- REPEATS accepts: DAILY, WEEKLY, MONTHLY (or leave blank)."
echo "- GUESTS should be comma-separated emails."
echo ""
echo "Press Enter to open Neovim..."
read -r

nvim "$TEMPLATE_FILE"

# ---------------------------------------------------------------------------
# Parsing & API Submission
# ---------------------------------------------------------------------------
TITLE=$(grep "^TITLE:" "$TEMPLATE_FILE" | sed 's/^TITLE: *//')

if [[ -z "$TITLE" ]]; then
  echo "Title is empty. Aborting event creation."
  rm -f "$TEMPLATE_FILE"
  sleep 2
  exit 1
fi

DATE_VAL=$(grep "^DATE:" "$TEMPLATE_FILE" | sed 's/^DATE: *//')
START_TIME=$(grep "^START_TIME:" "$TEMPLATE_FILE" | sed 's/^START_TIME: *//')
END_TIME=$(grep "^END_TIME:" "$TEMPLATE_FILE" | sed 's/^END_TIME: *//')
LOCATION=$(grep "^LOCATION:" "$TEMPLATE_FILE" | sed 's/^LOCATION: *//')
MEET=$(grep "^ADD_MEET:" "$TEMPLATE_FILE" | sed 's/^ADD_MEET: *//' | tr '[:upper:]' '[:lower:]')
REPEATS=$(grep "^REPEATS:" "$TEMPLATE_FILE" | sed 's/^REPEATS: *//' | tr '[:lower:]' '[:upper:]')
GUESTS=$(grep "^GUESTS:" "$TEMPLATE_FILE" | sed 's/^GUESTS: *//')
DESC=$(awk '/^---/{flag=1; next} flag' "$TEMPLATE_FILE")

# Grab the local timezone offset (e.g., +05:30 for India)
TZ_OFFSET=$(date +%:z)

echo "Compiling and sending to Google..."

# Build JSON Payload
PAYLOAD=$(jq -n \
  --arg title "$TITLE" \
  --arg loc "$LOCATION" \
  --arg desc "$DESC" \
  --arg date "$DATE_VAL" \
  --arg start_t "$START_TIME" \
  --arg end_t "$END_TIME" \
  --arg tz "$TZ_OFFSET" \
  --arg meet "$MEET" \
  --arg repeats "$REPEATS" \
  --arg guests "$GUESTS" \
  '
  {
    summary: $title,
    location: $loc,
    description: $desc
  }
  # Time vs All Day
  | if ($start_t != "" and $end_t != "") then
      .start = { dateTime: "\($date)T\($start_t):00\($tz)" } |
      .end = { dateTime: "\($date)T\($end_t):00\($tz)" }
    else
      .start = { date: $date } |
      .end = { date: $date }
    end
  # Recurrence
  | if ($repeats != "") then
      .recurrence = ["RRULE:FREQ=\($repeats)"]
    else . end
  # Guests
  | if ($guests != "") then
      .attendees = ($guests | split(",") | map({email: (.|gsub("^\\s+|\\s+$";""))}))
    else . end
  # Google Meet
  | if ($meet == "true") then
      .conferenceData = {
        createRequest: {
          requestId: "\($date)-\($start_t)-meet",
          conferenceSolutionKey: { type: "hangoutsMeet" }
        }
      }
    else . end
  ')

# Send to Google Calendar API
curl -sS -X POST "https://www.googleapis.com/calendar/v3/calendars/${CALENDAR_ID}/events?conferenceDataVersion=1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" >/dev/null

rm -f "$TEMPLATE_FILE"
