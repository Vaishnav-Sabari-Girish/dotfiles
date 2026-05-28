#!/usr/bin/env bash
# File: receive_file.sh
# Magic Wormhole file receiving TUI with fzf

set -e

# Configuration & Colors
SCRIPT_NAME="Magic Wormhole Receive"
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;214m'
BLUE='\033[38;5;33m'
GRAY='\033[38;5;245m'
NC='\033[0m' # No Color
BOLD='\033[1m'

export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --prompt='> ' --pointer='▶' --marker='✓'"

check_dependencies() {
  local missing_deps=()

  command -v fzf >/dev/null 2>&1 || missing_deps+=("fzf")
  command -v wormhole >/dev/null 2>&1 || missing_deps+=("magic-wormhole")
  command -v wl-paste >/dev/null 2>&1 || missing_deps+=("wl-clipboard")

  if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
    exit 1
  fi
}

show_header() {
  clear
  echo -e "${BLUE}${BOLD}========================================${NC}"
  echo -e "${BLUE}${BOLD}          $SCRIPT_NAME          ${NC}"
  echo -e "${BLUE}${BOLD}========================================${NC}"
  echo -e "Enter wormhole code to receive files\n"
}

get_wormhole_code() {
  local code=""
  local clipboard_content
  clipboard_content=$(wl-paste 2>/dev/null || true)

  # Check if clipboard contains a wormhole code pattern
  if [[ "$clipboard_content" =~ ^[0-9]+-[a-zA-Z]+-[a-zA-Z]+$ ]]; then
    # Redirected to stderr (>&2) so it displays to the user but isn't captured by the variable assignment
    echo -e "${GREEN}📋 Found wormhole code in clipboard: ${BOLD}$clipboard_content${NC}" >&2
    read -p "Use code from clipboard? [Y/n] " use_clip </dev/tty

    if [[ ! "$use_clip" =~ ^[Nn]$ ]]; then
      echo "$clipboard_content"
      return 0
    fi
  fi

  # Manual fallback
  read -p "Enter wormhole code (e.g., 7-guitarist-revenge): " code </dev/tty

  # Clean the code - remove any extra whitespace and newlines
  code=$(echo "$code" | tr -d '[:space:]')

  # Validate code format
  if [[ ! "$code" =~ ^[0-9]+-[a-zA-Z]+-[a-zA-Z]+$ ]]; then
    echo -e "${RED}Invalid code format! Expected: number-word-word${NC}" >&2
    echo -e "${RED}Received: '$code'${NC}" >&2
    return 1
  fi

  echo "$code"
}

choose_download_location() {
  local locations=(
    "Current directory (.)"
    "Downloads folder (~/Downloads)"
    "Desktop (~/Desktop)"
    "Documents (~/Documents)"
    "Custom location"
  )

  local choice
  choice=$(printf '%s\n' "${locations[@]}" | fzf --header "Choose download location:") || {
    echo -e "${YELLOW}Cancelled.${NC}" >&2
    exit 0
  }

  case "$choice" in
  "Current directory (.)") echo "." ;;
  "Downloads folder (~/Downloads)")
    mkdir -p ~/Downloads
    echo "$HOME/Downloads"
    ;;
  "Desktop (~/Desktop)")
    mkdir -p ~/Desktop
    echo "$HOME/Desktop"
    ;;
  "Documents (~/Documents)")
    mkdir -p ~/Documents
    echo "$HOME/Documents"
    ;;
  "Custom location")
    read -p "Enter full path (e.g., /path/to/folder): " custom_path </dev/tty
    if [ -z "$custom_path" ]; then
      echo "."
    elif [ ! -d "$custom_path" ]; then
      read -p "Directory doesn't exist. Create it? [Y/n] " create_dir </dev/tty
      if [[ ! "$create_dir" =~ ^[Nn]$ ]]; then
        mkdir -p "$custom_path" && echo "$custom_path" || echo "."
      else
        echo "."
      fi
    else
      echo "$custom_path"
    fi
    ;;
  *) echo "." ;;
  esac
}

main() {
  check_dependencies
  show_header

  # Get wormhole code
  local wormhole_code
  wormhole_code=$(get_wormhole_code)

  if [ -z "$wormhole_code" ]; then
    echo -e "${RED}No valid code provided. Exiting.${NC}"
    exit 1
  fi

  echo -e "${GRAY}Debug: Using code: '$wormhole_code'${NC}"

  # Choose download location
  local download_path
  download_path=$(choose_download_location)

  # Show confirmation
  echo -e "\n${GREEN}Code: $wormhole_code${NC}"
  echo -e "${GREEN}Download to: $download_path${NC}"

  read -p "Start receiving file? [Y/n] " confirm </dev/tty
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
  fi

  # Change to download directory
  local original_pwd
  original_pwd=$(pwd)

  if [ "$download_path" != "." ]; then
    cd "$download_path" || {
      echo -e "${RED}Failed to change to directory: $download_path${NC}"
      exit 1
    }
  fi

  show_header
  echo -e "${GREEN}📥 Receiving file with code: $wormhole_code${NC}"
  echo -e "${GREEN}📁 Download location: $(pwd)${NC}\n"

  # Start receiving
  # Check if alias/custom binary path was needed
  local wh_cmd="wormhole"
  if [ -x "$HOME/.local/bin/wormhole" ]; then
    wh_cmd="$HOME/.local/bin/wormhole"
  fi

  $wh_cmd receive "$wormhole_code"
  local exit_code=$?

  # Return to original directory
  cd "$original_pwd"

  # Show final status
  echo ""
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ File Received Successfully!${NC}"
    echo -e "${GREEN}📁 Location: $download_path${NC}"

    # Offer to open the download location
    if command -v nautilus >/dev/null 2>&1 || command -v dolphin >/dev/null 2>&1 || command -v thunar >/dev/null 2>&1; then
      read -p "Open download folder? [Y/n] " open_folder </dev/tty
      if [[ ! "$open_folder" =~ ^[Nn]$ ]]; then
        if command -v nautilus >/dev/null 2>&1; then
          nautilus "$download_path" 2>/dev/null &
        elif command -v dolphin >/dev/null 2>&1; then
          dolphin "$download_path" 2>/dev/null &
        elif command -v thunar >/dev/null 2>&1; then
          thunar "$download_path" 2>/dev/null &
        fi
      fi
    fi
  else
    echo -e "${RED}${BOLD}❌ Transfer Failed or Cancelled${NC}"
  fi
}

main "$@"
