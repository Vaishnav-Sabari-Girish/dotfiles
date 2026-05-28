#!/usr/bin/env bash
# File: send_file.sh
# Advanced TUI file sharing tool using fzf and magic-wormhole

set -e

# Configuration & Colors
SCRIPT_NAME="Magic Wormhole Share"
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;214m'
PINK='\033[38;5;212m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default fzf options for a nice floating TUI feel
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --prompt='> ' --pointer='▶' --marker='✓' --cycle"

check_dependencies() {
  local missing_deps=()

  command -v fzf >/dev/null 2>&1 || missing_deps+=("fzf")
  command -v wormhole >/dev/null 2>&1 || missing_deps+=("magic-wormhole")
  command -v wl-copy >/dev/null 2>&1 || missing_deps+=("wl-clipboard")

  if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
    exit 1
  fi
}

show_header() {
  clear
  echo -e "${PINK}${BOLD}========================================${NC}"
  echo -e "${PINK}${BOLD}          $SCRIPT_NAME          ${NC}"
  echo -e "${PINK}${BOLD}========================================${NC}"
  echo -e "Select files or directories to share\n"
}

get_items() {
  local depth=${1:-1}
  find . -maxdepth "$depth" -not -name ".*" -not -path "./.*" |
    grep -v "^\\.$" |
    sed 's|^\./||' |
    sort
}

extract_wormhole_code() {
  local output_file="$1"
  # Look for the code pattern in the output
  grep -oP 'wormhole receive \K[0-9]+-\w+-\w+' "$output_file" 2>/dev/null ||
    grep -oP '[0-9]+-\w+-\w+' "$output_file" | head -1 2>/dev/null || true
}

main() {
  check_dependencies
  show_header

  # Let user choose search depth
  local depth_choice
  depth_choice=$(printf "Current directory only\nInclude subdirectories (1 level)\nInclude subdirectories (2 levels)" |
    fzf --header "Search depth for files:") || {
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
  }

  local search_depth=1
  case "$depth_choice" in
  "Include subdirectories (1 level)") search_depth=2 ;;
  "Include subdirectories (2 levels)") search_depth=3 ;;
  esac

  # Get available items
  local items
  items=$(get_items "$search_depth")

  if [ -z "$items" ]; then
    echo -e "${RED}No files found!${NC}"
    exit 1
  fi

  # Let user select item(s)
  local selected_item
  selected_item=$(echo "$items" | fzf --header "Choose item to share:") || {
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
  }

  # Show item info
  if [ -f "$selected_item" ]; then
    local size
    size=$(du -h "$selected_item" | cut -f1)
    echo -e "\n${GREEN}Selected file: $selected_item ($size)${NC}"
  else
    echo -e "\n${GREEN}Selected directory: $selected_item${NC}"
  fi

  # Confirm sharing
  read -p "Share this item? [Y/n] " confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
  fi

  # Show preparation message
  echo -e "\n${GREEN}🚀 Starting secure transfer...${NC}\n"

  # Create named pipes for capturing output while showing it
  local temp_output
  temp_output=$(mktemp)

  # Start wormhole send and let it display normally
  {
    script -qec "wormhole send '$selected_item'" /dev/null | tee "$temp_output"
  } &

  local wormhole_pid=$!

  # Give it a moment to start and generate the code
  sleep 4

  # Try to extract the wormhole code from the output
  local wormhole_code
  wormhole_code=$(extract_wormhole_code "$temp_output")

  # If we got the code, copy it to clipboard and show success
  if [ -n "$wormhole_code" ]; then
    echo "$wormhole_code" | wl-copy
    echo -e "\n${GREEN}${BOLD}✓ Code copied to clipboard: $wormhole_code${NC}\n"
  fi

  # Wait for wormhole process to complete
  wait $wormhole_pid
  local exit_code=$?

  # Cleanup
  rm -f "$temp_output"

  # Show final status
  if [ $exit_code -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✅ Transfer Completed Successfully!${NC}"
  else
    echo -e "\n${RED}${BOLD}❌ Transfer Failed or Cancelled${NC}"
  fi
}

main "$@"
