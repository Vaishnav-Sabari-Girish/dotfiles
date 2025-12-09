#!/usr/bin/env bash

# Note-taking script with TUI
# Dependencies: gum (or fzf), glow

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/note-script/config"
NOTES_DIR=""

# Check if gum is installed, otherwise fall back to fzf
if command -v gum &>/dev/null; then
  TUI="gum"
elif command -v fzf &>/dev/null; then
  TUI="fzf"
else
  echo "Error: Neither gum nor fzf is installed. Please install one of them."
  exit 1
fi

# Function to get user input based on TUI tool
get_input() {
  local prompt="$1"
  if [[ "$TUI" == "gum" ]]; then
    gum input --placeholder "$prompt"
  else
    read -p "$prompt: " input
    echo "$input"
  fi
}

# Function to show menu based on TUI tool
show_menu() {
  local options=("$@")
  if [[ "$TUI" == "gum" ]]; then
    gum choose "${options[@]}"
  else
    printf '%s\n' "${options[@]}" | fzf --prompt="Select option: "
  fi
}

# Function to confirm action
confirm_action() {
  local prompt="$1"
  if [[ "$TUI" == "gum" ]]; then
    gum confirm "$prompt"
  else
    read -p "$prompt (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]]
  fi
}

# Load or set notes directory
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    NOTES_DIR=$(cat "$CONFIG_FILE")
  else
    echo "First time setup: Please choose a directory for your notes."
    NOTES_DIR=$(get_input "Enter notes directory path")

    # Expand tilde and create directory if it doesn't exist
    NOTES_DIR="${NOTES_DIR/#\~/$HOME}"
    mkdir -p "$NOTES_DIR"

    # Save configuration
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "$NOTES_DIR" >"$CONFIG_FILE"

    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 212 "Notes directory set to: $NOTES_DIR"
    else
      echo "Notes directory set to: $NOTES_DIR"
    fi
  fi
}

# Create a new directory with option for nested directories
create_directory() {
  local current_path="$NOTES_DIR"

  while true; do
    local dir_name=$(get_input "Enter directory name")

    if [[ -z "$dir_name" ]]; then
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 196 "Directory name cannot be empty."
      else
        echo "Directory name cannot be empty."
      fi
      return
    fi

    current_path="$current_path/$dir_name"

    if [[ -d "$current_path" ]]; then
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 214 "Directory already exists: ${current_path#$NOTES_DIR/}"
      else
        echo "Directory already exists: ${current_path#$NOTES_DIR/}"
      fi
      return
    fi

    mkdir -p "$current_path"

    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 212 "Directory created: ${current_path#$NOTES_DIR/}"
    else
      echo "Directory created: ${current_path#$NOTES_DIR/}"
    fi

    # Ask if user wants to create a subdirectory
    if confirm_action "Create a subdirectory inside ${dir_name}?"; then
      continue
    else
      break
    fi
  done
}

# Add subdirectory to existing directory
add_subdirectory() {
  local parent_path=$(navigate_directories "Select parent directory:")

  if [[ -z "$parent_path" ]]; then
    return
  fi

  # Now create subdirectory
  while true; do
    local dir_name=$(get_input "Enter subdirectory name")

    if [[ -z "$dir_name" ]]; then
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 196 "Directory name cannot be empty."
      else
        echo "Directory name cannot be empty."
      fi
      return
    fi

    local new_path="$parent_path/$dir_name"

    if [[ -d "$new_path" ]]; then
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 214 "Directory already exists: ${new_path#$NOTES_DIR/}"
      else
        echo "Directory already exists: ${new_path#$NOTES_DIR/}"
      fi
      return
    fi

    mkdir -p "$new_path"

    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 212 "Subdirectory created: ${new_path#$NOTES_DIR/}"
    else
      echo "Subdirectory created: ${new_path#$NOTES_DIR/}"
    fi

    # Ask if user wants to create another subdirectory
    if confirm_action "Create another subdirectory inside ${dir_name}?"; then
      parent_path="$new_path"
      continue
    else
      break
    fi
  done
}

# Navigate directories hierarchically
navigate_directories() {
  local header="${1:-Select location:}"
  local current_path="$NOTES_DIR"

  while true; do
    # Get only direct subdirectories of current path
    local dirs=($(find "$current_path" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort))

    local all_options=()

    # Add "Select this directory" option
    all_options+=("✅ Select this directory")

    # Add back option if not at root
    if [[ "$current_path" != "$NOTES_DIR" ]]; then
      all_options+=("⬆️  Go back")
    fi

    # Add subdirectories
    if [[ ${#dirs[@]} -gt 0 ]]; then
      for dir in "${dirs[@]}"; do
        all_options+=("📁 $(basename "$dir")")
      done
    fi

    local display_path="${current_path#$NOTES_DIR}"
    [[ -z "$display_path" ]] && display_path="Root"

    local selected
    if [[ "$TUI" == "gum" ]]; then
      selected=$(printf '%s\n' "${all_options[@]}" | gum choose --header="$header
Current: $display_path")
    else
      echo "Current location: $display_path"
      selected=$(printf '%s\n' "${all_options[@]}" | fzf --prompt="$header ")
    fi

    if [[ -z "$selected" ]]; then
      echo ""
      return
    fi

    case "$selected" in
    "✅ Select this directory")
      echo "$current_path"
      return
      ;;
    "⬆️  Go back")
      current_path=$(dirname "$current_path")
      ;;
    📁*)
      local dir_name="${selected#📁 }"
      current_path="$current_path/$dir_name"
      ;;
    *)
      return
      ;;
    esac
  done
}

# Manage directories - add subdirectories or delete directories
manage_directories() {
  local action=$(show_menu "Add Subdirectory to Existing Folder" "Delete Directory" "Back")

  case "$action" in
  "Add Subdirectory to Existing Folder")
    add_subdirectory
    ;;
  "Delete Directory")
    delete_directory
    ;;
  "Back" | *)
    return
    ;;
  esac
}

# Delete directory
delete_directory() {
  local dir_path=$(navigate_directories "Select directory to delete:")

  if [[ -z "$dir_path" ]] || [[ "$dir_path" == "$NOTES_DIR" ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "Cannot delete root directory."
    else
      echo "Cannot delete root directory."
    fi
    return
  fi

  # Check if directory has contents
  if [[ -n "$(ls -A "$dir_path" 2>/dev/null)" ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 214 "Warning: Directory is not empty!"
    else
      echo "Warning: Directory is not empty!"
    fi

    if ! confirm_action "Delete directory and all its contents?"; then
      return
    fi
  else
    if ! confirm_action "Delete directory ${dir_path#$NOTES_DIR/}?"; then
      return
    fi
  fi

  rm -rf "$dir_path"

  if [[ "$TUI" == "gum" ]]; then
    gum style --foreground 212 "Deleted: ${dir_path#$NOTES_DIR/}"
  else
    echo "Deleted: ${dir_path#$NOTES_DIR/}"
  fi
}

# Create a new note
create_note() {
  local location=$(navigate_directories "Select location for new note:")

  if [[ -z "$location" ]]; then
    return
  fi

  local note_name=$(get_input "Enter note name (press Enter for today's date)")

  if [[ -z "$note_name" ]]; then
    note_name=$(date +%Y-%m-%d)
  fi

  # Add .md extension if not present
  if [[ ! "$note_name" =~ \.md$ ]]; then
    note_name="${note_name}.md"
  fi

  local note_path="$location/$note_name"

  if [[ -f "$note_path" ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 214 "Note already exists. Opening in editor..."
    else
      echo "Note already exists. Opening in editor..."
    fi
  fi

  # Open in default editor
  ${EDITOR:-vim} "$note_path"
}

# Open existing notes for editing
open_notes() {
  local location=$(navigate_directories "Navigate to folder:")

  if [[ -z "$location" ]]; then
    return
  fi

  local notes=($(find "$location" -maxdepth 1 -name "*.md" -type f 2>/dev/null))

  if [[ ${#notes[@]} -eq 0 ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found in this location."
    else
      echo "No notes found in this location."
    fi
    return
  fi

  # Show list of notes to open
  local selected_note
  if [[ "$TUI" == "gum" ]]; then
    selected_note=$(printf '%s\n' "${notes[@]##*/}" | gum choose)
  else
    selected_note=$(printf '%s\n' "${notes[@]##*/}" | fzf --prompt="Select note to open: ")
  fi

  if [[ -n "$selected_note" ]]; then
    ${EDITOR:-vim} "$location/$selected_note"
  fi
}

# Preview notes
preview_notes() {
  local location=$(navigate_directories "Navigate to folder:")

  if [[ -z "$location" ]]; then
    return
  fi

  local notes=($(find "$location" -maxdepth 1 -name "*.md" -type f 2>/dev/null))

  if [[ ${#notes[@]} -eq 0 ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found in this location."
    else
      echo "No notes found in this location."
    fi
    return
  fi

  # Show list of notes to preview
  local selected_note
  if [[ "$TUI" == "gum" ]]; then
    selected_note=$(printf '%s\n' "${notes[@]##*/}" | gum choose)
  else
    selected_note=$(printf '%s\n' "${notes[@]##*/}" | fzf --prompt="Select note to preview: ")
  fi

  if [[ -n "$selected_note" ]]; then
    if command -v glow &>/dev/null; then
      glow "$location/$selected_note"
    else
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 214 "glow is not installed. Showing raw content:"
      else
        echo "glow is not installed. Showing raw content:"
      fi
      cat "$location/$selected_note"
    fi
  fi
}

# Delete notes
delete_notes() {
  local location=$(navigate_directories "Navigate to folder:")

  if [[ -z "$location" ]]; then
    return
  fi

  local notes=($(find "$location" -maxdepth 1 -name "*.md" -type f 2>/dev/null))

  if [[ ${#notes[@]} -eq 0 ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found in this location."
    else
      echo "No notes found in this location."
    fi
    return
  fi

  local selected_note
  if [[ "$TUI" == "gum" ]]; then
    selected_note=$(printf '%s\n' "${notes[@]##*/}" | gum choose)
  else
    selected_note=$(printf '%s\n' "${notes[@]##*/}" | fzf --prompt="Select note to delete: ")
  fi

  if [[ -n "$selected_note" ]]; then
    if confirm_action "Delete $selected_note?"; then
      rm "$location/$selected_note"
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 212 "Deleted: $selected_note"
      else
        echo "Deleted: $selected_note"
      fi
    fi
  fi
}

# Search notes by filename using fzf
search_notes() {
  echo "Searching for notes by filename..."

  # Find all markdown files recursively and use fzf to search
  local selected=$(find "$NOTES_DIR" -name "*.md" -type f 2>/dev/null |
    sed "s|$NOTES_DIR/||" |
    fzf --prompt="Search notes by name: " \
      --preview="if command -v glow &>/dev/null; then glow '$NOTES_DIR/{}'; else cat '$NOTES_DIR/{}'; fi" \
      --preview-window=right:60%:wrap)

  if [[ -n "$selected" ]]; then
    ${EDITOR:-vim} "$NOTES_DIR/$selected"
  fi
}

# Main menu loop
main_menu() {
  while true; do
    if [[ "$TUI" == "gum" ]]; then
      gum style --border normal --padding "1 2" --border-foreground 212 "📝 Note Taking App"
    else
      echo "=== Note Taking App ==="
    fi

    choice=$(show_menu "Create New Note" "Create Directory" "Manage Directories" "Open Notes" "Preview Notes" "Delete Notes" "Search Notes" "Quit")

    case "$choice" in
    "Create New Note")
      create_note
      ;;
    "Create Directory")
      create_directory
      ;;
    "Manage Directories")
      manage_directories
      ;;
    "Open Notes")
      open_notes
      ;;
    "Preview Notes")
      preview_notes
      ;;
    "Delete Notes")
      delete_notes
      ;;
    "Search Notes")
      search_notes
      ;;
    "Quit")
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 212 "Goodbye! 👋"
      else
        echo "Goodbye!"
      fi
      exit 0
      ;;
    *)
      exit 0
      ;;
    esac

    echo ""
  done
}

# Main execution
load_config
main_menu
