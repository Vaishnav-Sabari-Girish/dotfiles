#!/usr/bin/env bash
#
# gcal-tui — a tiny bash TUI calendar widget for Google Calendar
#
# Requirements: bash, curl, jq, nvim, date (GNU coreutils)
#
# Credentials file (JSON), default: ~/.config/gcal-tui/credentials.json
# {
#   "client_id": "...",
#   "client_secret": "...",
#   "refresh_token": "..."
# }

set -uo pipefail

# ---------------------------------------------------------------------------
# Cleanup / Terminal State Restoration
# ---------------------------------------------------------------------------
cleanup() {
  tput cnorm 2>/dev/null # Restore cursor visibility
  printf '\e[?1049l'     # Leave alternate screen buffer
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Config / colors
# ---------------------------------------------------------------------------

CREDS_FILE="${GCAL_TUI_CREDS:-$HOME/.config/gcal-tui/credentials.json}"
CACHE_DIR="${GCAL_TUI_CACHE_DIR:-$HOME/.cache/gcal-tui}"
TOKEN_CACHE="$CACHE_DIR/access_token.json"
CALENDAR_ID="${GCAL_TUI_CALENDAR_ID:-primary}"

# Dynamically locate the gcal.jq file located in the same directory as this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
JQ_FILE="${SCRIPT_DIR}/gcal.jq"

RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
TODAY_FG=$'\e[97m'
TODAY_BG=$'\e[44m'
EVENT_BG=$'\e[42m'
EVENT_FG=$'\e[30m'
CURSOR_BG=$'\e[45m'
CURSOR_FG=$'\e[97m'
HEADER_FG=$'\e[36m'
DOW_FG=$'\e[90m'

CELL_WIDTH=3      # "NN " per cell
GRID_TITLE_ROWS=2 # title line + day-of-week header line, before the grid body

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

while [[ "${1:-}" == -* ]]; do
  case "$1" in
  -c | --creds)
    CREDS_FILE="$2"
    shift 2
    ;;
  -h | --help)
    sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

YEAR="${1:-$(date +%Y)}"
MONTH="${2:-$(date +%m)}"
MONTH=$((10#$MONTH))

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}
need curl
need jq
need date
need nvim

if [[ ! -f "$CREDS_FILE" ]]; then
  echo "Credentials file not found: $CREDS_FILE" >&2
  exit 1
fi

if [[ ! -f "$JQ_FILE" ]]; then
  echo "Missing helper script: $JQ_FILE" >&2
  echo "Please ensure gcal.jq is in the same directory as this script." >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"

# ---------------------------------------------------------------------------
# OAuth
# ---------------------------------------------------------------------------

get_access_token() {
  local now
  now=$(date +%s)

  if [[ -f "$TOKEN_CACHE" ]]; then
    local cached_token cached_exp
    cached_token=$(jq -r '.access_token // empty' "$TOKEN_CACHE" 2>/dev/null)
    cached_exp=$(jq -r '.expires_at // 0' "$TOKEN_CACHE" 2>/dev/null)
    [[ -z "$cached_exp" ]] && cached_exp=0
    if [[ -n "$cached_token" && "$now" -lt "$cached_exp" ]]; then
      printf '%s' "$cached_token"
      return 0
    fi
  fi

  local client_id client_secret refresh_token
  client_id=$(jq -r '.client_id' "$CREDS_FILE")
  client_secret=$(jq -r '.client_secret' "$CREDS_FILE")
  refresh_token=$(jq -r '.refresh_token' "$CREDS_FILE")

  if [[ -z "$client_id" || "$client_id" == "null" ||
    -z "$client_secret" || "$client_secret" == "null" ||
    -z "$refresh_token" || "$refresh_token" == "null" ]]; then
    echo "credentials.json missing client_id/client_secret/refresh_token" >&2
    return 1
  fi

  local resp http_code body
  resp=$(curl -sS -w '\n%{http_code}' -X POST https://oauth2.googleapis.com/token \
    -d client_id="$client_id" \
    -d client_secret="$client_secret" \
    -d refresh_token="$refresh_token" \
    -d grant_type=refresh_token)

  http_code=$(tail -n1 <<<"$resp")
  body=$(sed '$d' <<<"$resp")

  if [[ "$http_code" != "200" ]]; then
    echo "Token refresh failed (HTTP $http_code):" >&2
    echo "$body" >&2
    return 1
  fi

  local access_token expires_in expires_at
  access_token=$(jq -r '.access_token' <<<"$body")
  expires_in=$(jq -r '.expires_in // 3600' <<<"$body")
  expires_at=$((now + expires_in - 60))

  jq -n --arg t "$access_token" --argjson e "$expires_at" \
    '{access_token: $t, expires_at: $e}' >"$TOKEN_CACHE"
  chmod 600 "$TOKEN_CACHE"

  printf '%s' "$access_token"
  return 0
}

# ---------------------------------------------------------------------------
# Fetch events
# ---------------------------------------------------------------------------

fetch_events() {
  local token="$1" year="$2" month="$3"

  local first_of_month time_min time_max
  first_of_month=$(printf '%04d-%02d-01' "$year" "$month")
  time_min=$(date -d "$first_of_month -3 days" -u +%Y-%m-%dT%H:%M:%SZ)
  time_max=$(date -d "$first_of_month +1 month +3 days" -u +%Y-%m-%dT%H:%M:%SZ)

  local url="https://www.googleapis.com/calendar/v3/calendars/${CALENDAR_ID}/events"
  local resp http_code body
  resp=$(curl -sS -w '\n%{http_code}' -G "$url" \
    -H "Authorization: Bearer $token" \
    --data-urlencode "timeMin=${time_min}" \
    --data-urlencode "timeMax=${time_max}" \
    --data-urlencode "singleEvents=true" \
    --data-urlencode "orderBy=startTime" \
    --data-urlencode "maxResults=2500")

  http_code=$(tail -n1 <<<"$resp")
  body=$(sed '$d' <<<"$resp")

  if [[ "$http_code" != "200" ]]; then
    echo "Failed to fetch events (HTTP $http_code):" >&2
    echo "$body" >&2
    return 1
  fi

  printf '%s' "$body"
  return 0
}

# ---------------------------------------------------------------------------
# Date helpers
# ---------------------------------------------------------------------------

first_weekday() { date -d "$1-$2-01" +%w; }
days_in_month() { date -d "$1-$2-01 +1 month -1 day" +%d; }

# ---------------------------------------------------------------------------
# EXTERNAL JQ PROCESSORS
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# EXTERNAL JQ PROCESSORS
# ---------------------------------------------------------------------------

build_day_index() {
  local json="$1" year="$2" month="$3"
  local ym
  ym=$(printf '%04d-%02d' "$year" "$month")

  # Route to 'index' logic in gcal.jq
  # Passing an empty --arg day "" to satisfy the strict jq compiler
  jq -r --arg action "index" --arg ym "$ym" --arg day "" -f "$JQ_FILE" <<<"$json"
}

build_day_markdown() {
  local json="$1" year="$2" month="$3" day="$4" out_file="$5"
  local ym dd
  ym=$(printf '%04d-%02d' "$year" "$month")
  dd=$(printf '%02d' "$day")

  local heading
  heading=$(date -d "${year}-${month}-${dd}" +"%A, %B %-d, %Y")

  {
    echo "# Events on ${heading}"
    echo
    # Route to 'markdown' logic in gcal.jq
    jq -r --arg action "markdown" --arg ym "$ym" --arg day "$dd" -f "$JQ_FILE" <<<"$json"
  } >"$out_file"
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

GRID_FW=0
GRID_DIM=0
declare -A GRID_HAS_EVENT=()

cell_style_for_day() {
  local day="$1" today_year="$2" today_month="$3" today_day="$4"
  local is_today=0
  if [[ "$YEAR" == "$today_year" && "$MONTH" == "$today_month" && "$day" == "$today_day" ]]; then
    is_today=1
  fi
  if [[ "$is_today" == "1" && -n "${GRID_HAS_EVENT[$day]:-}" ]]; then
    printf '%s' "${TODAY_BG}${BOLD}${TODAY_FG}"
  elif [[ "$is_today" == "1" ]]; then
    printf '%s' "${TODAY_BG}${TODAY_FG}"
  elif [[ -n "${GRID_HAS_EVENT[$day]:-}" ]]; then
    printf '%s' "${EVENT_BG}${EVENT_FG}"
  else
    printf '%s' ""
  fi
}

render_initial_grid() {
  local year="$1" month="$2"
  shift 2
  GRID_HAS_EVENT=()
  local d
  for d in "$@"; do
    GRID_HAS_EVENT["$d"]=1
  done

  local month_name
  month_name=$(date -d "${year}-${month}-01" +"%B")
  local today_year today_month today_day
  today_year=$(date +%Y)
  today_month=$(date +%-m)
  today_day=$(date +%-d)

  local title="${month_name} ${year}"
  local pad=$(((20 - ${#title}) / 2))
  ((pad < 0)) && pad=0

  printf "%*s%s%s%s%s\n" "$pad" "" "$HEADER_FG" "$BOLD" "$title" "$RESET"
  printf "%sSu Mo Tu We Th Fr Sa%s\n" "$DOW_FG" "$RESET"

  GRID_FW=$(first_weekday "$year" "$month")
  GRID_DIM=$(days_in_month "$year" "$month")
  GRID_DIM=$((10#$GRID_DIM))

  local col=0
  for ((i = 0; i < GRID_FW; i++)); do
    printf "   "
    col=$((col + 1))
  done

  for ((d = 1; d <= GRID_DIM; d++)); do
    local cell style
    cell=$(printf "%2d" "$d")
    style=$(cell_style_for_day "$d" "$today_year" "$today_month" "$today_day")
    printf "%s%s%s " "$style" "$cell" "$RESET"
    col=$((col + 1))
    if ((col % 7 == 0)); then printf "\n"; fi
  done
  ((col % 7 != 0)) && printf "\n"
  echo
  printf "%s%s  %s%s today   %s  %s%s has events   %s  %s%s cursor%s\n" \
    "$DIM" "$TODAY_BG" "$RESET" "$DIM" "$EVENT_BG" "$RESET" "$DIM" "$CURSOR_BG" "$RESET" "$DIM" "$RESET"
  echo
}

day_rowcol() {
  local day="$1"
  local idx=$((GRID_FW + day - 1))
  echo "$((idx / 7)) $((idx % 7))"
}

redraw_cell() {
  local day="$1" style_mode="$2"
  local today_year today_month today_day
  today_year=$(date +%Y)
  today_month=$(date +%-m)
  today_day=$(date +%-d)

  local row col
  read -r row col <<<"$(day_rowcol "$day")"
  local screen_row=$((GRID_TITLE_ROWS + row + 1))
  local screen_col=$((col * CELL_WIDTH + 1))

  local cell style
  cell=$(printf "%2d" "$day")

  if [[ "$style_mode" == "cursor" ]]; then
    style="${CURSOR_BG}${CURSOR_FG}"
  else
    style=$(cell_style_for_day "$day" "$today_year" "$today_month" "$today_day")
  fi

  printf '\e[%d;%dH%s%s%s' "$screen_row" "$screen_col" "$style" "$cell" "$RESET"
}

# ---------------------------------------------------------------------------
# Keyboard input
# ---------------------------------------------------------------------------

read_key() {
  local key rest
  IFS= read -rsn1 key || {
    printf 'EOF'
    return 1
  }
  if [[ "$key" == $'\x1b' ]]; then
    IFS= read -rsn1 -t 0.01 rest
    if [[ "$rest" == "[" ]]; then
      IFS= read -rsn1 -t 0.01 rest
      case "$rest" in
      A) printf 'UP' ;;
      B) printf 'DOWN' ;;
      C) printf 'RIGHT' ;;
      D) printf 'LEFT' ;;
      Z) printf 'SHIFT_TAB' ;;
      *) printf 'OTHER' ;;
      esac
    else
      printf 'ESC'
    fi
  elif [[ "$key" == $'\t' ]]; then
    printf 'TAB'
  elif [[ "$key" == "c" || "$key" == "C" ]]; then
    printf 'CREATE'
  elif [[ "$key" == "" ]]; then
    printf 'ENTER'
  elif [[ "$key" == "" ]]; then
    printf 'ENTER'
  elif [[ "$key" == "q" || "$key" == "Q" ]]; then
    printf 'QUIT'
  else
    printf 'OTHER'
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  local token
  token=$(get_access_token) || exit 1

  local events_json
  events_json=$(fetch_events "$token" "$YEAR" "$MONTH") || exit 1

  local day_index
  day_index=$(build_day_index "$events_json" "$YEAR" "$MONTH")

  local -a event_days=()
  if [[ -n "$day_index" ]]; then
    local d _t _s
    while IFS=$'\t' read -r d _t _s; do
      [[ -z "$d" ]] && continue
      event_days+=("$((10#$d))")
    done <<<"$day_index"
    mapfile -t event_days < <(printf '%s\n' "${event_days[@]}" | sort -un)
  fi

  printf '\e[?1049h'
  printf '\e[2J\e[H'

  render_initial_grid "$YEAR" "$MONTH" "${event_days[@]}"

  if [[ ${#event_days[@]} -eq 0 ]]; then
    echo "No events found in ${CALENDAR_ID} for this month."
    echo "(If you expect events here, your events might be on a different"
    echo " calendar. Run ./gcal-list-calendars.sh to see all calendar IDs,"
    echo " then: GCAL_TUI_CALENDAR_ID=\"...\" ./gcal-tui.sh)"
    echo
    echo "Press any key to exit."
    IFS= read -rsn1 -t 10 _ 2>/dev/null
    return 0
  fi

  echo "Arrows: move   Tab/Shift+Tab: jump"
  echo "Enter: open in nvim   c: Create Event"
  echo "q: quit"

  local today_year today_month today_day
  today_year=$(date +%Y)
  today_month=$(date +%-m)
  today_day=$(date +%-d)

  local cursor_day="${event_days[0]}"
  if [[ "$YEAR" == "$today_year" && "$MONTH" == "$today_month" ]]; then
    cursor_day="$today_day"
  fi

  local status_row=$((GRID_TITLE_ROWS + 1 + ((GRID_FW + GRID_DIM + 6) / 7) + 5))

  print_status() {
    local day="$1"
    local count
    count=$(awk -F'\t' -v d="$(printf '%02d' "$day")" '$1==d' <<<"$day_index" | wc -l)
    printf '\e[%d;1H\e[K' "$status_row"
    if [[ "$count" -gt 0 ]]; then
      local plural="s"
      [[ "$count" == "1" ]] && plural=""
      printf '%s%s%s: %s event%s — press Enter to view%s' \
        "$BOLD" "$(date -d "${YEAR}-${MONTH}-${day}" +"%a %b %-d")" "$RESET" "$count" "$plural" "$RESET"
    else
      printf '%s%s: no events%s' "$DIM" "$(date -d "${YEAR}-${MONTH}-${day}" +"%a %b %-d")" "$RESET"
    fi
  }

  is_event_day() {
    local day="$1" d
    for d in "${event_days[@]}"; do
      [[ "$d" == "$day" ]] && return 0
    done
    return 1
  }

  next_event_day() {
    local day="$1" d best=""
    for d in "${event_days[@]}"; do
      if ((d > day)); then
        best="$d"
        break
      fi
    done
    [[ -z "$best" ]] && best="${event_days[0]}"
    printf '%s' "$best"
  }

  prev_event_day() {
    local day="$1" d best=""
    for d in "${event_days[@]}"; do
      if ((d < day)); then best="$d"; fi
    done
    [[ -z "$best" ]] && best="${event_days[-1]}"
    printf '%s' "$best"
  }

  tput civis 2>/dev/null
  redraw_cell "$cursor_day" cursor
  print_status "$cursor_day"

  local action exit_requested=0
  while [[ "$exit_requested" == "0" ]]; do
    action=$(read_key)
    local rc=$?
    if [[ "$rc" != "0" || "$action" == "EOF" || "$action" == "QUIT" || "$action" == "ESC" ]]; then
      exit_requested=1
      break
    fi

    local new_day="$cursor_day"
    case "$action" in
    LEFT)
      new_day=$((cursor_day - 1))
      ((new_day < 1)) && new_day=1
      ;;
    RIGHT)
      new_day=$((cursor_day + 1))
      ((new_day > GRID_DIM)) && new_day=$GRID_DIM
      ;;
    UP)
      new_day=$((cursor_day - 7))
      ((new_day < 1)) && new_day=$cursor_day
      ;;
    DOWN)
      new_day=$((cursor_day + 7))
      ((new_day > GRID_DIM)) && new_day=$cursor_day
      ;;
    TAB)
      new_day=$(next_event_day "$cursor_day")
      ;;
    SHIFT_TAB)
      new_day=$(prev_event_day "$cursor_day")
      ;;
    CREATE)
      # Calculate the YYYY-MM-DD string for the currently hovered day
      local target_date
      target_date=$(printf '%04d-%02d-%02d' "$YEAR" "$MONTH" "$cursor_day")

      # Restore cursor and call the external creation script
      tput cnorm 2>/dev/null
      "${SCRIPT_DIR}/gcal-create.sh" "$target_date"
      tput civis 2>/dev/null

      # After creation, we MUST fetch fresh data from Google so the new event appears
      events_json=$(fetch_events "$token" "$YEAR" "$MONTH")
      day_index=$(build_day_index "$events_json" "$YEAR" "$MONTH")

      event_days=()
      if [[ -n "$day_index" ]]; then
        local d _t _s
        while IFS=$'\t' read -r d _t _s; do
          [[ -z "$d" ]] && continue
          event_days+=("$((10#$d))")
        done <<<"$day_index"
        mapfile -t event_days < <(printf '%s\n' "${event_days[@]}" | sort -un)
      fi

      # Redraw the entire interface
      printf '\e[2J\e[H'
      render_initial_grid "$YEAR" "$MONTH" "${event_days[@]}"

      echo "Arrows: move   Tab/Shift+Tab: jump"
      echo "Enter: open in nvim   c: Create Event"
      echo "q: quit"

      redraw_cell "$cursor_day" cursor
      print_status "$cursor_day"

      new_day="$cursor_day"
      ;;
    ENTER)
      if is_event_day "$cursor_day"; then
        tput cnorm 2>/dev/null
        local md_file
        md_file=$(mktemp "${CACHE_DIR}/event-XXXXXX.md")
        build_day_markdown "$events_json" "$YEAR" "$MONTH" "$cursor_day" "$md_file"
        nvim "$md_file"
        rm -f "$md_file"
        tput civis 2>/dev/null
        printf '\e[2J\e[H'
        render_initial_grid "$YEAR" "$MONTH" "${event_days[@]}"

        echo "Arrows: move   Tab/Shift+Tab: jump"
        echo "Enter: open in nvim   c: Create Event"
        echo "q: quit"

        redraw_cell "$cursor_day" cursor
        print_status "$cursor_day"
      fi
      new_day="$cursor_day"
      ;;
    *)
      new_day="$cursor_day"
      ;;
    esac

    if [[ "$new_day" != "$cursor_day" ]]; then
      redraw_cell "$cursor_day" normal
      cursor_day="$new_day"
      redraw_cell "$cursor_day" cursor
      print_status "$cursor_day"
    fi
  done
}

main
