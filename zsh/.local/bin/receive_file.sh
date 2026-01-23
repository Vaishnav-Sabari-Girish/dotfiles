#!/usr/bin/env bash

# File: receive_file.sh
# Magic Wormhole file receiving TUI with gum

set -e

# Configuration
SCRIPT_NAME="Magic Wormhole Receive"

check_dependencies() {
  local missing_deps=()

  command -v gum >/dev/null 2>&1 || missing_deps+=("gum")
  command -v wormhole >/dev/null 2>&1 || missing_deps+=("magic-wormhole")
  command -v wl-paste >/dev/null 2>&1 || missing_deps+=("wl-clipboard")

  if [ ${#missing_deps[@]} -ne 0 ]; then
    gum style --foreground 196 "Missing dependencies: ${missing_deps[*]}"
    exit 1
  fi
}

show_header() {
  gum style \
    --foreground 33 --border-foreground 33 --border double \
    --align center --width 60 --margin "1 2" --padding "2 4" \
    "$SCRIPT_NAME" \
    'Enter wormhole code to receive files'
}

get_wormhole_code() {
  local code=""

  # Check if there's a code in clipboard
  local clipboard_content
  clipboard_content=$(wl-paste 2>/dev/null || true)

  # Check if clipboard contains a wormhole code pattern
  if [[ "$clipboard_content" =~ ^[0-9]+-[a-zA-Z]+-[a-zA-Z]+$ ]]; then
    gum style --foreground 46 "📋 Found wormhole code in clipboard: $clipboard_content"

    if gum confirm "Use code from clipboard?"; then
      # Return ONLY the clipboard content, not the display message
      echo "$clipboard_content"
      return 0
    fi
  fi

  # Let user choose input method
  local input_method
  input_method=$(gum choose --header "How would you like to enter the code?" \
    "Type the code manually" \
    "Paste from clipboard" \
    "Scan QR code (if available)")

  case "$input_method" in
  "Type the code manually")
    code=$(gum input --placeholder "Enter wormhole code (e.g., 7-guitarist-revenge)")
    ;;
  "Paste from clipboard")
    code=$(wl-paste 2>/dev/null || echo "")
    if [ -z "$code" ]; then
      gum style --foreground 196 "No content found in clipboard"
      return 1
    fi
    # Clean the code - remove any extra whitespace
    code=$(echo "$code" | tr -d '[:space:]')
    ;;
  "Scan QR code (if available)")
    gum style --foreground 214 "QR code scanning not implemented yet"
    gum style --foreground 245 "Please use manual entry or clipboard paste"
    code=$(gum input --placeholder "Enter wormhole code (e.g., 7-guitarist-revenge)")
    ;;
  esac

  # Clean the code - remove any extra whitespace and newlines
  code=$(echo "$code" | tr -d '[:space:]')

  # Validate code format
  if [[ ! "$code" =~ ^[0-9]+-[a-zA-Z]+-[a-zA-Z]+$ ]]; then
    gum style --foreground 196 "Invalid code format! Expected: number-word-word"
    gum style --foreground 196 "Received: '$code'"
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
  choice=$(printf '%s\n' "${locations[@]}" | gum choose --header "Choose download location:")

  case "$choice" in
  "Current directory (.)")
    echo "."
    ;;
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
    local custom_path
    custom_path=$(gum input --placeholder "Enter full path (e.g., /path/to/folder)")

    if [ -z "$custom_path" ]; then
      echo "."
    elif [ ! -d "$custom_path" ]; then
      if gum confirm "Directory doesn't exist. Create it?"; then
        mkdir -p "$custom_path" && echo "$custom_path" || echo "."
      else
        echo "."
      fi
    else
      echo "$custom_path"
    fi
    ;;
  *)
    echo "."
    ;;
  esac
}

main() {
  check_dependencies
  show_header

  # Get wormhole code
  local wormhole_code
  wormhole_code=$(get_wormhole_code)

  if [ -z "$wormhole_code" ]; then
    gum style --foreground 196 "No code provided. Exiting."
    exit 1
  fi

  # Debug: Show the exact code we're using
  gum style --foreground 245 "Debug: Using code: '$wormhole_code'"

  # Choose download location
  local download_path
  download_path=$(choose_download_location)

  # Show confirmation
  gum style --foreground 46 "Code: $wormhole_code"
  gum style --foreground 46 "Download to: $download_path"

  if ! gum confirm "Start receiving file?"; then
    gum style --foreground 214 "Cancelled."
    exit 0
  fi

  # Change to download directory
  local original_pwd
  original_pwd=$(pwd)

  if [ "$download_path" != "." ]; then
    cd "$download_path" || {
      gum style --foreground 196 "Failed to change to directory: $download_path"
      exit 1
    }
  fi

  # Clear screen for clean wormhole output
  clear
  gum style \
    --foreground 33 --border-foreground 33 --border double \
    --align center --width 60 --margin "1 2" --padding "2 4" \
    "$SCRIPT_NAME"

  gum style --foreground 46 "📥 Receiving file with code: $wormhole_code"
  gum style --foreground 46 "📁 Download location: $(pwd)"
  echo ""

  # Start receiving - make sure we pass only the clean code
  wormhole receive "$wormhole_code"
  local exit_code=$?

  # Return to original directory
  cd "$original_pwd"

  # Show final status
  echo ""
  if [ $exit_code -eq 0 ]; then
    gum style \
      --foreground 46 --border-foreground 46 --border rounded \
      --align center --width 50 --margin "1 2" --padding "1 2" \
      "✅ File Received Successfully!" \
      "📁 Location: $download_path"

    # Offer to open the download location
    if command -v nautilus >/dev/null 2>&1 || command -v dolphin >/dev/null 2>&1 || command -v thunar >/dev/null 2>&1; then
      if gum confirm "Open download folder?"; then
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
    gum style \
      --foreground 196 --border-foreground 196 --border rounded \
      --align center --width 50 --margin "1 2" --padding "1 2" \
      "❌ Transfer Failed or Cancelled"
  fi
}

main "$@"

# File: receive_file.sh
# Magic Wormhole file receiving TUI with gum

set -e

alias wormhole="\$HOME/.local/bin/wormhole"

# Configuration
SCRIPT_NAME="Magic Wormhole Receive"

check_dependencies() {
  local missing_deps=()

  command -v gum >/dev/null 2>&1 || missing_deps+=("gum")
  command -v wormhole >/dev/null 2>&1 || missing_deps+=("magic-wormhole")
  command -v wl-paste >/dev/null 2>&1 || missing_deps+=("wl-clipboard")

  if [ ${#missing_deps[@]} -ne 0 ]; then
    gum style --foreground 196 "Missing dependencies: ${missing_deps[*]}"
    exit 1
  fi
}

show_header() {
  gum style \
    --foreground 33 --border-foreground 33 --border double \
    --align center --width 60 --margin "1 2" --padding "2 4" \
    "$SCRIPT_NAME" \
    'Enter wormhole code to receive files'
}

get_wormhole_code() {
  local code=""

  # Check if there's a code in clipboard
  local clipboard_content
  clipboard_content=$(wl-paste 2>/dev/null || true)

  # Check if clipboard contains a wormhole code pattern
  if [[ "$clipboard_content" =~ ^[0-9]+-[a-zA-Z]+-[a-zA-Z]+$ ]]; then
    gum style --foreground 46 "📋 Found wormhole code in clipboard: $clipboard_content"

    if gum confirm "Use code from clipboard?"; then
      # Return ONLY the clipboard content, not the display message
      echo "$clipboard_content"
      return 0
    fi
  fi

  # Let user choose input method
  local input_method
  input_method=$(gum choose --header "How would you like to enter the code?" \
    "Type the code manually" \
    "Paste from clipboard" \
    "Scan QR code (if available)")

  case "$input_method" in
  "Type the code manually")
    code=$(gum input --placeholder "Enter wormhole code (e.g., 7-guitarist-revenge)")
    ;;
  "Paste from clipboard")
    code=$(wl-paste 2>/dev/null || echo "")
    if [ -z "$code" ]; then
      gum style --foreground 196 "No content found in clipboard"
      return 1
    fi
    # Clean the code - remove any extra whitespace
    code=$(echo "$code" | tr -d '[:space:]')
    ;;
  "Scan QR code (if available)")
    gum style --foreground 214 "QR code scanning not implemented yet"
    gum style --foreground 245 "Please use manual entry or clipboard paste"
    code=$(gum input --placeholder "Enter wormhole code (e.g., 7-guitarist-revenge)")
    ;;
  esac

  # Clean the code - remove any extra whitespace and newlines
  code=$(echo "$code" | tr -d '[:space:]')

  # Validate code format
  if [[ ! "$code" =~ ^[0-9]+-[a-zA-Z]+-[a-zA-Z]+$ ]]; then
    gum style --foreground 196 "Invalid code format! Expected: number-word-word"
    gum style --foreground 196 "Received: '$code'"
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
  choice=$(printf '%s\n' "${locations[@]}" | gum choose --header "Choose download location:")

  case "$choice" in
  "Current directory (.)")
    echo "."
    ;;
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
    local custom_path
    custom_path=$(gum input --placeholder "Enter full path (e.g., /path/to/folder)")

    if [ -z "$custom_path" ]; then
      echo "."
    elif [ ! -d "$custom_path" ]; then
      if gum confirm "Directory doesn't exist. Create it?"; then
        mkdir -p "$custom_path" && echo "$custom_path" || echo "."
      else
        echo "."
      fi
    else
      echo "$custom_path"
    fi
    ;;
  *)
    echo "."
    ;;
  esac
}

main() {
  check_dependencies
  show_header

  # Get wormhole code
  local wormhole_code
  wormhole_code=$(get_wormhole_code)

  if [ -z "$wormhole_code" ]; then
    gum style --foreground 196 "No code provided. Exiting."
    exit 1
  fi

  # Debug: Show the exact code we're using
  gum style --foreground 245 "Debug: Using code: '$wormhole_code'"

  # Choose download location
  local download_path
  download_path=$(choose_download_location)

  # Show confirmation
  gum style --foreground 46 "Code: $wormhole_code"
  gum style --foreground 46 "Download to: $download_path"

  if ! gum confirm "Start receiving file?"; then
    gum style --foreground 214 "Cancelled."
    exit 0
  fi

  # Change to download directory
  local original_pwd
  original_pwd=$(pwd)

  if [ "$download_path" != "." ]; then
    cd "$download_path" || {
      gum style --foreground 196 "Failed to change to directory: $download_path"
      exit 1
    }
  fi

  # Clear screen for clean wormhole output
  clear
  gum style \
    --foreground 33 --border-foreground 33 --border double \
    --align center --width 60 --margin "1 2" --padding "2 4" \
    "$SCRIPT_NAME"

  gum style --foreground 46 "📥 Receiving file with code: $wormhole_code"
  gum style --foreground 46 "📁 Download location: $(pwd)"
  echo ""

  # Start receiving - make sure we pass only the clean code
  wormhole receive "$wormhole_code"
  local exit_code=$?

  # Return to original directory
  cd "$original_pwd"

  # Show final status
  echo ""
  if [ $exit_code -eq 0 ]; then
    gum style \
      --foreground 46 --border-foreground 46 --border rounded \
      --align center --width 50 --margin "1 2" --padding "1 2" \
      "✅ File Received Successfully!" \
      "📁 Location: $download_path"

    # Offer to open the download location
    if command -v nautilus >/dev/null 2>&1 || command -v dolphin >/dev/null 2>&1 || command -v thunar >/dev/null 2>&1; then
      if gum confirm "Open download folder?"; then
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
    gum style \
      --foreground 196 --border-foreground 196 --border rounded \
      --align center --width 50 --margin "1 2" --padding "1 2" \
      "❌ Transfer Failed or Cancelled"
  fi
}

main "$@"
