#!/usr/bin/env bash
# ==========================================
# tz - A lightweight CLI timezone helper
# ==========================================
# Usage:
#   tz                          # current time in your saved zones
#   tz 22:30                    # 22:30 (local) → all saved zones
#   tz 22:30 berlin             # 22:30 (local) → zones matching "berlin"
#   tz 22:30 cest               # 22:30 (local) → zones currently using CEST
#   tz 19:00 cest ist           # 19:00 CEST → IST  (explicit conversion)
#   tz 3pm bst asia/kolkata     # 3PM BST → Asia/Kolkata
# ==========================================

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
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
  # shellcheck source=/dev/null
  source "$HOME/.tzrc"
else
  ZONES=("${DEFAULT_ZONES[@]}")
fi

# Proper IANA zone validation (avoids the "any string works as TZ=" pitfall)
is_valid_zone() {
  local z="$1"
  case "$z" in
  UTC | GMT | Local) return 0 ;;
  esac
  if [ -f "/usr/share/zoneinfo/$z" ] || [ -L "/usr/share/zoneinfo/$z" ]; then
    return 0
  fi
  return 1
}

# Common abbreviation → preferred IANA zone mapping
resolve_abbr() {
  local abbr
  abbr=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  case "$abbr" in
  # India (preferred for IST) / also maps Irish/Israeli if needed later
  IST) echo "Asia/Kolkata" ;;
  # British
  BST) echo "Europe/London" ;;
  GMT) echo "Europe/London" ;;
  # Central Europe
  CEST | CET) echo "Europe/Paris" ;;
  # Eastern Europe
  EEST | EET) echo "Europe/Athens" ;;
  # US Pacific
  PDT | PST) echo "America/Los_Angeles" ;;
  # US Mountain
  MDT | MST) echo "America/Denver" ;;
  # US Central
  CDT) echo "America/Chicago" ;;
  # US Eastern
  EDT | EST) echo "America/New_York" ;;
  # Japan / Korea
  JST | KST) echo "Asia/Tokyo" ;;
  # Australia East
  AEST | AEDT) echo "Australia/Sydney" ;;
  # Australia West
  AWST) echo "Australia/Perth" ;;
  # China (CST is ambiguous; we prefer US Central via CDT above)
  # Singapore / Malaysia
  SGT | MYT) echo "Asia/Singapore" ;;
  # UAE
  GST) echo "Asia/Dubai" ;;
  # UTC
  UTC | Z) echo "UTC" ;;
  *) echo "" ;;
  esac
}

# Checks if the argument looks like a time (e.g. 15:00, 3PM, 10:30 AM)
is_time() {
  local input
  input=$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
  if [[ "$input" =~ ^[0-9]{1,2}:[0-9]{2}(AM|PM)?$ ]] || [[ "$input" =~ ^[0-9]{1,2}(AM|PM)$ ]]; then
    return 0
  fi
  return 1
}

# Cross-platform time → Unix epoch converter
# Optional 2nd argument: source timezone (IANA name)
parse_time_to_epoch() {
  local input="$1"
  local source_tz="${2:-}"
  local epoch=""
  local tz_env=""

  if [ -n "$source_tz" ]; then
    if ! is_valid_zone "$source_tz"; then
      echo ""
      return
    fi
    tz_env="TZ=$source_tz"
  fi

  if date --version >/dev/null 2>&1; then
    # Linux (GNU date)
    if [ -n "$tz_env" ]; then
      epoch=$(env $tz_env date -d "$input" +%s 2>/dev/null)
    else
      epoch=$(date -d "$input" +%s 2>/dev/null)
    fi
  else
    # macOS (BSD date)
    local up_input
    up_input=$(echo "$input" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
    local fmt=""
    if [[ "$up_input" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
      fmt="%H:%M"
    elif [[ "$up_input" =~ ^[0-9]{1,2}:[0-9]{2}(AM|PM)$ ]]; then
      fmt="%I:%M%p"
    elif [[ "$up_input" =~ ^[0-9]{1,2}(AM|PM)$ ]]; then
      fmt="%I%p"
    fi
    if [ -n "$fmt" ]; then
      if [ -n "$tz_env" ]; then
        epoch=$(env $tz_env date -j -f "$fmt" "$up_input" +%s 2>/dev/null)
      else
        epoch=$(date -j -f "$fmt" "$up_input" +%s 2>/dev/null)
      fi
    fi
  fi
  echo "$epoch"
}

print_header() {
  echo -e "${DIM}Timezone                         | Time       | Date                 | Offset${NC}"
  echo -e "${DIM}--------------------------------------------------------------------------------${NC}"
}

print_tz() {
  local zone="$1"
  local display_zone="$zone"
  local tz_env="TZ=$zone"

  # Handle the special "Local" case
  if [ "$zone" = "Local" ]; then
    tz_env=""
    display_zone="Local ($(date +"%Z"))"
  else
    if ! is_valid_zone "$zone"; then return; fi
  fi

  local time_str date_str offset abbr
  if [ -n "$TARGET_EPOCH" ]; then
    if date --version >/dev/null 2>&1; then
      time_str=$(env $tz_env date -d "@$TARGET_EPOCH" +"%H:%M:%S")
      date_str=$(env $tz_env date -d "@$TARGET_EPOCH" +"%a, %b %d, %Y")
      offset=$(env $tz_env date -d "@$TARGET_EPOCH" +"%z")
      abbr=$(env $tz_env date -d "@$TARGET_EPOCH" +"%Z")
    else
      time_str=$(env $tz_env date -r "$TARGET_EPOCH" +"%H:%M:%S")
      date_str=$(env $tz_env date -r "$TARGET_EPOCH" +"%a, %b %d, %Y")
      offset=$(env $tz_env date -r "$TARGET_EPOCH" +"%z")
      abbr=$(env $tz_env date -r "$TARGET_EPOCH" +"%Z")
    fi
  else
    time_str=$(env $tz_env date +"%H:%M:%S")
    date_str=$(env $tz_env date +"%a, %b %d, %Y")
    offset=$(env $tz_env date +"%z")
    abbr=$(env $tz_env date +"%Z")
  fi

  printf "${BLUE}%-32s${NC} | ${GREEN}%-10s${NC} | ${YELLOW}%-20s${NC} | %s (%s)\n" \
    "$display_zone" "$time_str" "$date_str" "$offset" "$abbr"
}

# Helper: list all IANA zones robustly (handles systems without working timedatectl)
list_all_zones() {
  if command -v timedatectl >/dev/null 2>&1 && timedatectl list-timezones >/dev/null 2>&1; then
    timedatectl list-timezones
  else
    find /usr/share/zoneinfo \( -type f -o -type l \) 2>/dev/null |
      sed 's|.*/usr/share/zoneinfo/||' |
      grep -vE 'posix|right|SystemV|\.tab|\.zi' |
      sort -u
  fi
}

# Find zones whose *current* abbreviation matches (case-insensitive)
find_zones_by_abbr() {
  local search
  search=$(echo "$1" | tr '[:lower:]' '[:upper:]')

  # Fast path via known mapping
  local mapped
  mapped=$(resolve_abbr "$search")
  if [ -n "$mapped" ] && is_valid_zone "$mapped"; then
    echo "$mapped"
    return
  fi

  # Slow but accurate scan of zoneinfo for current season
  local list
  list=$(list_all_zones)

  while IFS= read -r z; do
    [ -z "$z" ] && continue
    local current_abbr
    current_abbr=$(env TZ="$z" date +%Z 2>/dev/null)
    if [ "$(echo "$current_abbr" | tr '[:lower:]' '[:upper:]')" = "$search" ]; then
      echo "$z"
    fi
  done <<<"$list"
}

# Resolve a user-supplied zone / abbr / city fragment into one or more IANA zones
resolve_zones() {
  local search="$1"

  # 1. Exact valid IANA name
  if is_valid_zone "$search"; then
    echo "$search"
    return
  fi

  # 2. Known abbreviation → preferred zone
  local mapped
  mapped=$(resolve_abbr "$search")
  if [ -n "$mapped" ] && is_valid_zone "$mapped"; then
    echo "$mapped"
    return
  fi

  # 3. Substring search on zone names (case-insensitive)
  local matched
  matched=$(list_all_zones | grep -i "$search")

  if [ -n "$matched" ]; then
    echo "$matched"
    return
  fi

  # 4. Last resort: zones currently using this abbreviation
  find_zones_by_abbr "$search"
}

# ==========================================
# Main Logic
# ==========================================
TARGET_EPOCH=""

# 1. Check if the first argument is a time
if [ $# -gt 0 ] && is_time "$1"; then
  TIME_ARG="$1"
  shift
else
  TIME_ARG=""
fi

# 2. Decide mode based on remaining arguments
if [ $# -eq 2 ]; then
  # Explicit conversion: tz 19:00 CEST IST
  SRC_RAW="$1"
  DST_RAW="$2"

  SRC_ZONES=$(resolve_zones "$SRC_RAW")
  DST_ZONES=$(resolve_zones "$DST_RAW")

  if [ -z "$SRC_ZONES" ]; then
    echo -e "${RED}Error: Could not resolve source timezone/abbreviation '$SRC_RAW'.${NC}"
    exit 1
  fi
  if [ -z "$DST_ZONES" ]; then
    echo -e "${RED}Error: Could not resolve target timezone/abbreviation '$DST_RAW'.${NC}"
    exit 1
  fi

  # Use the first match for source
  SRC_ZONE=$(echo "$SRC_ZONES" | head -n1)

  if [ -n "$TIME_ARG" ]; then
    TARGET_EPOCH=$(parse_time_to_epoch "$TIME_ARG" "$SRC_ZONE")
    if [ -z "$TARGET_EPOCH" ]; then
      echo -e "${RED}Error: Could not parse time '$TIME_ARG' in zone '$SRC_ZONE'.${NC}"
      exit 1
    fi
    echo -e "${BOLD}Converting ${YELLOW}${TIME_ARG}${NC} ${DIM}(${SRC_RAW} → ${SRC_ZONE})${NC} ${BOLD}to${NC} ${CYAN}${DST_RAW}${NC}\n"
  else
    echo -e "${BOLD}Current time comparison: ${SRC_RAW} ↔ ${DST_RAW}${NC}\n"
  fi

  print_header
  # Show source for reference
  print_tz "$SRC_ZONE"
  # Show all matching targets
  while IFS= read -r z; do
    [ -n "$z" ] && print_tz "$z"
  done <<<"$DST_ZONES"

elif [ $# -eq 1 ]; then
  # Search / filter mode: tz 22:30 berlin   or   tz 22:30 cest
  search="$1"

  if [ -n "$TIME_ARG" ]; then
    TARGET_EPOCH=$(parse_time_to_epoch "$TIME_ARG")
    if [ -z "$TARGET_EPOCH" ]; then
      echo -e "${RED}Error: Could not parse time format '$TIME_ARG'. Use 15:00, 3PM, 03:30PM, etc.${NC}"
      exit 1
    fi
    echo -e "Converting ${YELLOW}${TIME_ARG}${NC} (local) to zones matching '${YELLOW}${search}${NC}'...\n"
  else
    echo -e "Searching for current time in '${YELLOW}${search}${NC}'...\n"
  fi

  matched_zones=$(resolve_zones "$search")

  if [ -z "$matched_zones" ]; then
    echo -e "${RED}No timezones found matching '$search'.${NC}"
    exit 1
  fi

  print_header
  while IFS= read -r z; do
    [ -n "$z" ] && print_tz "$z"
  done <<<"$matched_zones"

else
  # Default list mode (no search args)
  if [ -n "$TIME_ARG" ]; then
    TARGET_EPOCH=$(parse_time_to_epoch "$TIME_ARG")
    if [ -z "$TARGET_EPOCH" ]; then
      echo -e "${RED}Error: Could not parse time format '$TIME_ARG'. Use 15:00, 3PM, 03:30PM, etc.${NC}"
      exit 1
    fi
    echo -e "Converting ${YELLOW}${TIME_ARG}${NC} (local) across your saved timezones...\n"
  fi

  print_header
  for z in "${ZONES[@]}"; do
    print_tz "$z"
  done
fi
