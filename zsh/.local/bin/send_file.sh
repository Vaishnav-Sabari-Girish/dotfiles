#!/usr/bin/env bash
# File: share-file-advanced.sh
# Advanced TUI file sharing tool with QR code support

set -e

# Configuration
SCRIPT_NAME="Magic Wormhole Share"
MAX_DEPTH=3

check_dependencies() {
  local missing_deps=()

  command -v gum >/dev/null 2>&1 || missing_deps+=("gum")
  command -v wormhole >/dev/null 2>&1 || missing_deps+=("magic-wormhole")
  command -v wl-copy >/dev/null 2>&1 || missing_deps+=("wl-clipboard")

  if [ ${#missing_deps[@]} -ne 0 ]; then
    gum style --foreground 196 "Missing dependencies: ${missing_deps[*]}"
    exit 1
  fi
}

show_header() {
  gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --margin "1 2" --padding "2 4" \
    "$SCRIPT_NAME" \
    'Select files or directories to share'
}

get_items() {
  local depth=${1:-1}
  find . -maxdepth "$depth" -not -name ".*" -not -path "./.*" |
    grep -v "^\\.$" |
    sed 's|^\./||' |
    sort
}

select_search_depth() {
  gum choose --header "Search depth for files:" \
    "Current directory only" \
    "Include subdirectories (1 level)" \
    "Include subdirectories (2 levels)"
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
  depth_choice=$(select_search_depth)

  local search_depth=1
  case "$depth_choice" in
  "Include subdirectories (1 level)") search_depth=2 ;;
  "Include subdirectories (2 levels)") search_depth=3 ;;
  esac

  # Get available items
  local items
  items=$(get_items "$search_depth")

  if [ -z "$items" ]; then
    gum style --foreground 196 "No files found!"
    exit 1
  fi

  # Let user select item(s)
  local selected_item
  selected_item=$(echo "$items" | gum choose --header "Choose item to share:")

  if [ -z "$selected_item" ]; then
    gum style --foreground 196 "No item selected. Exiting."
    exit 0
  fi

  # Show item info
  if [ -f "$selected_item" ]; then
    local size
    size=$(du -h "$selected_item" | cut -f1)
    gum style --foreground 46 "Selected file: $selected_item ($size)"
  else
    gum style --foreground 46 "Selected directory: $selected_item"
  fi

  # Confirm sharing
  if ! gum confirm "Share this item?"; then
    gum style --foreground 214 "Cancelled."
    exit 0
  fi

  # Show preparation message
  gum style --foreground 46 "🚀 Starting secure transfer..."
  echo ""

  # Create named pipes for capturing output while showing it
  local temp_output
  temp_output=$(mktemp)

  # Start wormhole send and let it display normally
  # We'll capture the output in background while showing it to user
  {
    # Use script command to preserve terminal formatting including QR codes
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
    # Copy to clipboard
    echo "$wormhole_code" | wl-copy

    # Show success message without interrupting the wormhole output
    echo ""
    gum style \
      --foreground 46 --border-foreground 46 --border rounded \
      --align center --width 60 --margin "0 2" --padding "1 2" \
      "✓ Code copied to clipboard: $wormhole_code"
    echo ""
  fi

  # Wait for wormhole process to complete
  wait $wormhole_pid
  local exit_code=$?

  # Cleanup
  rm -f "$temp_output"

  # Show final status
  if [ $exit_code -eq 0 ]; then
    echo ""
    gum style \
      --foreground 46 --border-foreground 46 --border rounded \
      --align center --width 50 --margin "1 2" --padding "1 2" \
      "✅ Transfer Completed Successfully!"
  else
    echo ""
    gum style \
      --foreground 196 --border-foreground 196 --border rounded \
      --align center --width 50 --margin "1 2" --padding "1 2" \
      "❌ Transfer Failed or Cancelled"
  fi
}

main "$@"
