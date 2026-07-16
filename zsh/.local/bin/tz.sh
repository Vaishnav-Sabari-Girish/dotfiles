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

print_header() {
  echo -e "${DIM}Timezone                       | Time       | Date                 | Offset${NC}"
  echo -e "${DIM}--------------------------------------------------------------------------------${NC}"
}

print_tz() {
  local zone="$1"

  # Handle the special "Local" case
  if [ "$zone" = "Local" ]; then
    local time_str=$(date +"%H:%M:%S")
    local date_str=$(date +"%a, %b %d, %Y")
    local offset=$(date +"%z")
    local display_zone="Local ($(date +"%Z"))"

    printf "${BLUE}%-30s${NC} | ${GREEN}%-10s${NC} | ${YELLOW}%-20s${NC} | %s\n" "$display_zone" "$time_str" "$date_str" "$offset"
    return
  fi

  # Skip if timezone is invalid
  if ! TZ="$zone" date >/dev/null 2>&1; then return; fi

  local time_str=$(TZ="$zone" date +"%H:%M:%S")
  local date_str=$(TZ="$zone" date +"%a, %b %d, %Y")
  local offset=$(TZ="$zone" date +"%z")
  local abbr=$(TZ="$zone" date +"%Z")

  printf "${BLUE}%-30s${NC} | ${GREEN}%-10s${NC} | ${YELLOW}%-20s${NC} | %s (%s)\n" "$zone" "$time_str" "$date_str" "$offset" "$abbr"
}

# Main Logic
if [ $# -gt 0 ]; then
  # Search mode
  search="$1"
  echo -e "Searching for timezones matching '${YELLOW}$search${NC}'...\n"

  # Find matching timezones cross-platform (Linux/macOS)
  if command -v timedatectl >/dev/null 2>&1; then
    matched_zones=$(timedatectl list-timezones | grep -i "$search")
  else
    # Fallback to scanning the zoneinfo directory directly
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
  # Default list mode
  print_header
  for z in "${ZONES[@]}"; do
    print_tz "$z"
  done
fi
