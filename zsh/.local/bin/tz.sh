#!/usr/bin/env bash

# ==========================================
# tz - A lightweight CLI timezone helper
# ==========================================

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Default zones if no config file is found
DEFAULT_ZONES=(
  "Local"
  "UTC"
  "America/Los_Angeles"
  "America/New_York"
  "Europe/London"
  "Europe/Paris"
  "Asia/Kolkata"
  "Asia/Tokyo"
  "Australia/Sydney"
)

# Load custom zones from ~/.tzrc if it exists
if [ -f "$HOME/.tzrc" ]; then
  source "$HOME/.tzrc"
else
  ZONES=("${DEFAULT_ZONES[@]}")
fi

# Checks if the argument looks like a time (e.g. 15:00, 3PM, 10:30 AM)
is_time() {
  # Remove spaces and uppercase it for regex testing
  local input=$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr -d ' ')

  # Must contain a colon OR AM/PM to be confidently identified as a time
  if [[ "$input" =~ ^[0-9]{1,2}:[0-9]{2}(AM|PM)?$ ]] || [[ "$input" =~ ^[0-9]{1,2}(AM|PM)$ ]]; then
    return 0
  fi
  return 1
}

# Cross-platform time to Unix epoch converter
parse_time_to_epoch() {
  local input="$1"
  local epoch=""

  if date --version >/dev/null 2>&1; then
    # Linux (GNU date)
    epoch=$(date -d "$input" +%s 2>/dev/null)
  else
    # macOS (BSD date)
    local up_input=$(echo "$input" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
    if [[ "$up_input" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
      epoch=$(date -j -f "%H:%M" "$up_input" +%s 2>/dev/null)
    elif [[ "$up_input" =~ ^[0-9]{1,2}:[0-9]{2}(AM|PM)$ ]]; then
      epoch=$(date -j -f "%I:%M%p" "$up_input" +%s 2>/dev/null)
    elif [[ "$up_input" =~ ^[0-9]{1,2}(AM|PM)$ ]]; then
      epoch=$(date -j -f "%I%p" "$up_input" +%s 2>/dev/null)
    fi
  fi
  echo "$epoch"
}

print_header() {
  echo -e "${DIM}Timezone                       | Time       | Date                 | Offset${NC}"
  echo -e "${DIM}--------------------------------------------------------------------------------${NC}"
}

print_tz() {
  local zone="$1"
  local display_zone="$zone"
  local tz_env="TZ=$zone"

  # Handle the special "Local" case
  if [ "$zone" = "Local" ]; then
    tz_env="" # Run without TZ var for local
    display_zone="Local ($(date +"%Z"))"
  else
    # Skip if timezone is invalid
    if ! env TZ="$zone" date >/dev/null 2>&1; then return; fi
  fi

  local time_str date_str offset abbr

  if [ -n "$TARGET_EPOCH" ]; then
    # We are converting a specific time
    if date --version >/dev/null 2>&1; then
      # Linux (GNU)
      time_str=$(env $tz_env date -d "@$TARGET_EPOCH" +"%H:%M:%S")
      date_str=$(env $tz_env date -d "@$TARGET_EPOCH" +"%a, %b %d, %Y")
      offset=$(env $tz_env date -d "@$TARGET_EPOCH" +"%z")
      abbr=$(env $tz_env date -d "@$TARGET_EPOCH" +"%Z")
    else
      # macOS (BSD)
      time_str=$(env $tz_env date -r "$TARGET_EPOCH" +"%H:%M:%S")
      date_str=$(env $tz_env date -r "$TARGET_EPOCH" +"%a, %b %d, %Y")
      offset=$(env $tz_env date -r "$TARGET_EPOCH" +"%z")
      abbr=$(env $tz_env date -r "$TARGET_EPOCH" +"%Z")
    fi
  else
    # We are showing the current time
    time_str=$(env $tz_env date +"%H:%M:%S")
    date_str=$(env $tz_env date +"%a, %b %d, %Y")
    offset=$(env $tz_env date +"%z")
    abbr=$(env $tz_env date +"%Z")
  fi

  printf "${BLUE}%-30s${NC} | ${GREEN}%-10s${NC} | ${YELLOW}%-20s${NC} | %s (%s)\n" "$display_zone" "$time_str" "$date_str" "$offset" "$abbr"
}

# ==========================================
# Main Logic
# ==========================================

TARGET_EPOCH=""

# 1. Check if the first argument is a time
if [ $# -gt 0 ] && is_time "$1"; then
  TARGET_EPOCH=$(parse_time_to_epoch "$1")
  if [ -z "$TARGET_EPOCH" ]; then
    echo -e "${RED}Error: Could not parse time format '$1'. Use formats like 15:00, 3PM, or 03:30PM.${NC}"
    exit 1
  fi
  shift # Remove the time argument so we can check if there's a search term next
fi

# 2. Check if there are remaining arguments (Search mode)
if [ $# -gt 0 ]; then
  search="$1"
  if [ -n "$TARGET_EPOCH" ]; then
    echo -e "Converting time to timezones matching '${YELLOW}$search${NC}'...\n"
  else
    echo -e "Searching for current time in '${YELLOW}$search${NC}'...\n"
  fi

  if command -v timedatectl >/dev/null 2>&1; then
    matched_zones=$(timedatectl list-timezones | grep -i "$search")
  else
    matched_zones=$(find /usr/share/zoneinfo -type f -not -name "*.zi" -not -name "*.tab" | sed 's|.*/usr/share/zoneinfo/||' | grep -i "$search" | grep -v 'posix\|right\|SystemV')
  fi

  if [ -z "$matched_zones" ]; then
    echo -e "${RED}No timezones found matching '$search'.${NC}"
    exit 1
  fi

  print_header
  for z in $matched_zones; do
    print_tz "$z"
  done
else
  # 3. Default list mode
  if [ -n "$TARGET_EPOCH" ]; then
    echo -e "Converting time across your saved timezones...\n"
  fi

  print_header
  for z in "${ZONES[@]}"; do
    print_tz "$z"
  done
fi
