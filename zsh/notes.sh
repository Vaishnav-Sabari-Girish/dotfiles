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

# Create a new note
create_note() {
  local note_name=$(get_input "Enter note name (press Enter for today's date)")

  if [[ -z "$note_name" ]]; then
    note_name=$(date +%Y-%m-%d)
  fi

  # Add .md extension if not present
  if [[ ! "$note_name" =~ \.md$ ]]; then
    note_name="${note_name}.md"
  fi

  local note_path="$NOTES_DIR/$note_name"

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
  local notes=($(ls "$NOTES_DIR"/*.md 2>/dev/null))

  if [[ ${#notes[@]} -eq 0 ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found."
    else
      echo "No notes found."
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
    ${EDITOR:-vim} "$NOTES_DIR/$selected_note"
  fi
}

# Preview notes
preview_notes() {
  local notes=($(ls "$NOTES_DIR"/*.md 2>/dev/null))

  if [[ ${#notes[@]} -eq 0 ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found."
    else
      echo "No notes found."
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
      glow -t "$NOTES_DIR/$selected_note"
    else
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 214 "glow is not installed. Showing raw content:"
      else
        echo "glow is not installed. Showing raw content:"
      fi
      cat "$NOTES_DIR/$selected_note"
    fi
  fi
}

# Delete notes
delete_notes() {
  local notes=($(ls "$NOTES_DIR"/*.md 2>/dev/null))

  if [[ ${#notes[@]} -eq 0 ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found."
    else
      echo "No notes found."
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
      rm "$NOTES_DIR/$selected_note"
      if [[ "$TUI" == "gum" ]]; then
        gum style --foreground 212 "Deleted: $selected_note"
      else
        echo "Deleted: $selected_note"
      fi
    fi
  fi
}

# Search notes
search_notes() {
  local query=$(get_input "Enter search term")

  if [[ -z "$query" ]]; then
    return
  fi

  local results=$(grep -l -i "$query" "$NOTES_DIR"/*.md 2>/dev/null)

  if [[ -z "$results" ]]; then
    if [[ "$TUI" == "gum" ]]; then
      gum style --foreground 196 "No notes found matching: $query"
    else
      echo "No notes found matching: $query"
    fi
    return
  fi

  if [[ "$TUI" == "gum" ]]; then
    gum style --foreground 212 "Notes containing '$query':"
  else
    echo "Notes containing '$query':"
  fi

  echo "$results" | while read -r note; do
    echo "  - $(basename "$note")"
  done

  # Option to preview a result
  local selected_note
  if [[ "$TUI" == "gum" ]]; then
    selected_note=$(echo "$results" | sed 's|.*/||' | gum choose)
  else
    selected_note=$(echo "$results" | sed 's|.*/||' | fzf --prompt="Select note to preview: ")
  fi

  if [[ -n "$selected_note" ]] && command -v glow &>/dev/null; then
    glow "$NOTES_DIR/$selected_note"
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

    choice=$(show_menu "Create New Note" "Open Notes" "Preview Notes" "Delete Notes" "Search Notes" "Quit")

    case "$choice" in
    "Create New Note")
      create_note
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
